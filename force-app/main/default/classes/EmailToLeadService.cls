global class EmailToLeadService implements Messaging.InboundEmailHandler {
 
    @TestVisible
    private static Boolean FORCE_DML_ERROR_TEST = false;

    // When true, handleInboundEmail skips creating new exception logs
    // (the retry batch manages the original record's retry state itself)
    global static Boolean isRetryContext = false;

    private static String lastRequestJSON;
    private static String lastResponseJSON;

    private static Set<String> cachedAllowedFields;
    private static Map<String, Schema.SObjectField> cachedLeadFields;
    
    private static String cachedEmailBodyField;
    private static String cachedSummaryField;

    public class EmailToLeadDmlException extends Exception {}

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope env
    ) {

        Messaging.InboundEmailResult result =
            new Messaging.InboundEmailResult();

        List<Id> createdLeadIds = new List<Id>();

        String cleanedBody = null;
        String emailHeader = null;
        String emailBody = null;
 
        try {

            if (email == null || String.isBlank(email.plainTextBody)) {
                result.success = false;
                result.message = 'Email body is empty.';
                return result;
            }

            loadFieldSettings();
            
            cachedLeadFields = Schema.SObjectType.Lead.fields.getMap();

            if (cachedAllowedFields == null)
                cachedAllowedFields = new Set<String>();

            if (cachedLeadFields == null)
                cachedLeadFields = new Map<String, Schema.SObjectField>();

            cleanedBody = email.plainTextBody;
            emailBody = cleanedBody;

            // Store full email early so it's saved to Email_Header__c even if callout fails
            emailHeader = emailBody;

            String aiText = callZApi(cleanedBody);

            Object parsed =
                extractJsonOrArrayFromAI(aiText);

            if (parsed == null) {
                throw new CalloutException('AI returned no lead data.');
            }

            // Extract AI email_header from root level (for multi-lead)
            if (parsed instanceof Map<String,Object>) {
                Map<String,Object> root = (Map<String,Object>)parsed;
                if (root.containsKey('email_header')) {
                    emailHeader = String.valueOf(root.get('email_header'));
                }
            }

            // Fallback if AI didn't provide header
            if (String.isBlank(emailHeader)) {
                emailHeader = 'From: ' + (email.fromAddress != null ? email.fromAddress : '')
                    + '\nSubject: ' + (email.subject != null ? email.subject : '');
            }

            List<Map<String,Object>> leadDataMaps = extractLeadDataMaps(parsed);

            if (leadDataMaps == null || leadDataMaps.isEmpty()) {
                throw new CalloutException('AI returned no lead data.');
            }

            // Build debug trace for multi-lead visibility in managed package
            String debugTrace = 'AI returned ' + leadDataMaps.size() + ' lead(s)\n';

            List<Lead> leads = new List<Lead>();

            for (Integer i = 0; i < leadDataMaps.size(); i++) {

                debugTrace += '\n--- Lead #' + (i+1) + ' ---\n';
                debugTrace += 'AI Keys: ' + String.join(new List<String>(leadDataMaps[i].keySet()), ', ') + '\n';

                Lead l = buildSingleLead(
                    leadDataMaps[i],
                    email,
                    cleanedBody,
                    emailHeader,
                    leadDataMaps.size()
                );

                if (l != null) {
                    leads.add(l);
                    debugTrace += 'Result: BUILT OK | LastName=' + l.LastName + ' | Company=' + l.Company + ' | Email=' + l.Email + '\n';
                } else {
                    debugTrace += 'Result: SKIPPED (meaningfulFieldCount < 2)\n';
                }
            }

            debugTrace += '\nTotal leads to insert (before dedup): ' + leads.size() + '\n';

            if (leads == null || leads.isEmpty()) {
                throw new CalloutException('No leads created. Debug: ' + debugTrace);
            }

            // ── Pre-insert Email + Company duplicate check ──────────────────────
            // Two-layer duplicate protection:
            //   Layer 1 (this block): Custom SOQL check on Email + Company.
            //              A lead is a duplicate only if BOTH email AND company
            //              match an existing Lead — same person at a new company
            //              is treated as a NEW lead.
            //   Layer 2 (Database.insert below): Salesforce Standard Duplicate
            //              Rules run as a second safety net (runAsCurrentUser=true).
            //
            // We implement Layer 1 ourselves because managed packages cannot ship
            // Matching/Duplicate Rules, so customer orgs may have none configured.
            // ─────────────────────────────────────────────────────────────────────

            // Step 1 — Collect all emails from the leads we are about to insert
            Set<String> emailsToCheck = new Set<String>();
            for (Lead lc : leads) {
                if (String.isNotBlank(lc.Email)) {
                    emailsToCheck.add(lc.Email.toLowerCase().trim());
                }
            }

            // Step 2 — Query existing Leads by email, then build a composite key
            //           map of  "email|company"  →  existing Lead Id.
            //           SOQL here runs in system mode (no WITH SHARING) so it
            //           finds records regardless of the running user's visibility.
            Map<String, Id> existingByEmailCompany = new Map<String, Id>();
            if (!emailsToCheck.isEmpty()) {
                for (Lead existLead : [
                    SELECT Id, Email, Company
                    FROM Lead
                    WHERE Email IN :emailsToCheck
                    LIMIT 2000
                ]) {
                    if (String.isBlank(existLead.Email)) continue;
                    String eKey = existLead.Email.toLowerCase().trim();
                    String cKey = String.isNotBlank(existLead.Company)
                        ? existLead.Company.toLowerCase().trim()
                        : '';
                    // Use § (U+00A7) as separator — never appears in emails or company names
                    existingByEmailCompany.put(eKey + '\u00A7' + cKey, existLead.Id);
                }
            }

            List<Lead> leadsToInsert      = new List<Lead>();
            Set<String> seenEmailCompany  = new Set<String>(); // in-batch dedup

            for (Lead lc : leads) {
                String emailKey   = String.isNotBlank(lc.Email)
                    ? lc.Email.toLowerCase().trim()
                    : null;
                String companyKey = String.isNotBlank(lc.Company)
                    ? lc.Company.toLowerCase().trim()
                    : '';
                // Use § (U+00A7) as separator — never appears in emails or company names,
                // eliminating any theoretical false-positive collision risk.
                String compositeKey = (emailKey != null) ? (emailKey + '\u00A7' + companyKey) : null;

                if (compositeKey == null) {
                    // No email available for dedup. Note: for single-lead emails where
                    // AI didn't extract an email, buildSingleLead() already falls back
                    // to email.fromAddress — so l.Email is typically already populated
                    // before reaching here. This null path is only hit when:
                    //   (a) multiple leads in one email AND AI didn't extract email for
                    //       this specific lead (fromAddress belongs to the sender, not
                    //       to each individual lead, so it can't be used here), OR
                    //   (b) single lead AND email.fromAddress was also blank.
                    // In both cases there is no reliable email to check — let it through.
                    leadsToInsert.add(lc);
                    continue;
                }

                // ── Check 1: same Email+Company appearing twice in this batch ──
                if (seenEmailCompany.contains(compositeKey)) {
                    debugTrace += 'PRE-INSERT DEDUP (batch): skipped Email+Company=' + compositeKey + '\n';
                    if (!isRetryContext) {
                        CustomExceptionLogger.logDuplicate(
                            new EmailToLeadDmlException(
                                'Duplicate Email+Company in same batch: ' + lc.Email + ' | ' + lc.Company),
                            'EmailToLeadService',
                            null,
                            lastRequestJSON,
                            lastResponseJSON,
                            emailHeader,
                            emailBody,
                            emailBody
                        );
                    }
                    continue;
                }

                // ── Check 2: Email+Company already exists in the org ───────────
                if (existingByEmailCompany.containsKey(compositeKey)) {
                    Id existId = existingByEmailCompany.get(compositeKey);
                    debugTrace += 'PRE-INSERT DEDUP (existing): skipped Email=' + lc.Email
                        + ' | Company=' + lc.Company + ' | existingId=' + existId + '\n';
                    if (!isRetryContext) {
                        CustomExceptionLogger.logDuplicate(
                            new EmailToLeadDmlException(
                                'Lead already exists with Email+Company: ' + lc.Email + ' | ' + lc.Company),
                            'EmailToLeadService',
                            existId,
                            lastRequestJSON,
                            lastResponseJSON,
                            emailHeader,
                            emailBody,
                            emailBody
                        );
                    }
                    continue;
                }

                seenEmailCompany.add(compositeKey);
                leadsToInsert.add(lc);
            }

            debugTrace += 'After dedup — leads to insert: ' + leadsToInsert.size() + '\n';

            if (leadsToInsert.isEmpty()) {
                // All leads were duplicates — not retriable
                result.success = false;
                result.message = 'Duplicate: All leads already exist in the org.';
                return result;
            }
            // ── End custom duplicate check ─────────────────────────────────────

            Database.SaveResult[] results;

            if (Test.isRunningTest()) {
                results = Database.insert(leadsToInsert, false);
            } else {
                // Layer 2: Salesforce Standard Duplicate Rules (second safety net)
                // runAsCurrentUser = false → REQUIRED because this service runs as a
                //   System Administrator, who has "Bypass Duplicate Checking" enabled
                //   by default. With true, Salesforce would silently skip all duplicate
                //   rules for admin users — making Layer 2 completely ineffective.
                //   Setting false forces rules to run in system mode regardless of
                //   the current user's bypass permissions.
                // allowSave = false        → duplicate detected = hard block (no alert)
                Database.DMLOptions opts = new Database.DMLOptions();
                opts.DuplicateRuleHeader.allowSave = false;
                opts.DuplicateRuleHeader.runAsCurrentUser = false;
                opts.optAllOrNone = false;
                results = Database.insert(leadsToInsert, opts);
            }

            debugTrace += 'Database.insert returned ' + results.size() + ' SaveResult(s)\n';

            List<String> success = new List<String>();
            List<String> errors = new List<String>();

            for (Integer i = 0; i < results.size(); i++) {

                Database.SaveResult sr = results[i];

                if (sr.isSuccess() && !FORCE_DML_ERROR_TEST) {

                    Id id = sr.getId();
                    createdLeadIds.add(id);
                    success.add(id);
                    debugTrace += 'SaveResult[' + i + ']: SUCCESS id=' + id + '\n';

                    CustomExceptionLogger.logSuccess(
                        'Lead #' + (i+1) + ' created',
                        'EmailToLeadService',
                        'Success',
                        id,
                        lastRequestJSON,
                        lastResponseJSON
                    );

                } else {

                    Database.Error e = sr.getErrors()[0];

                    if (e.getStatusCode() == StatusCode.DUPLICATES_DETECTED ||
                        e.getMessage().toLowerCase().contains('duplicate')) {

                        String msg = e.getMessage();
                        Id dupId = null;

                        try {
                            if (e instanceof Database.DuplicateError) {
                                Database.DuplicateError dupError = (Database.DuplicateError)e;
                                Datacloud.DuplicateResult dupResult = dupError.getDuplicateResult();
                                
                                if (dupResult != null) {
                                    List<Datacloud.MatchResult> matchResults = dupResult.getMatchResults();
                                    if (matchResults != null && !matchResults.isEmpty()) {
                                        List<Datacloud.MatchRecord> matchRecords = matchResults[0].getMatchRecords();
                                        if (matchRecords != null && !matchRecords.isEmpty()) {
                                            SObject matchedRecord = matchRecords[0].getRecord();
                                            if (matchedRecord != null) {
                                                dupId = matchedRecord.Id;
                                            }
                                        }
                                    }
                                }
                            }
                        } catch (Exception dupEx) {
                        }

                        if (dupId == null) {
                            String prefix = Lead.SObjectType.getDescribe().getKeyPrefix();
                            Pattern p = Pattern.compile(prefix + '[a-zA-Z0-9]{12,15}');
                            Matcher m = p.matcher(msg);
                            if (m.find()) {
                                try {
                                    dupId = (Id)m.group();
                                } catch (Exception ex) {
                                    dupId = null;
                                }
                            }
                        }

                        // Collect additional duplicate details
                        String ruleInfo = '';
                        try {
                            if (e instanceof Database.DuplicateError) {
                                Database.DuplicateError de = (Database.DuplicateError)e;
                                Datacloud.DuplicateResult dr = de.getDuplicateResult();
                                if (dr != null) {
                                    ruleInfo += ' | Rule: ' + dr.getDuplicateRule();
                                    Set<String> matchedFields = new Set<String>();
                                    for (Datacloud.MatchResult mr : dr.getMatchResults()) {
                                        ruleInfo += ' | MatchRule: ' + mr.getRule();
                                        for (Datacloud.MatchRecord mrec : mr.getMatchRecords()) {
                                            for (Datacloud.FieldDiff fd : mrec.getFieldDiffs()) {
                                                matchedFields.add(fd.getName());
                                            }
                                        }
                                    }
                                    if (!matchedFields.isEmpty()) {
                                        ruleInfo += ' | MatchedFields: ' + String.join(new List<String>(matchedFields), ', ');
                                    }
                                }
                            }
                        } catch (Exception ex) {
                            // Suppress errors during detail extraction
                        }

                        msg += ruleInfo;
                        errors.add(msg);
                        debugTrace += 'SaveResult[' + i + ']: DUPLICATE | ' + msg + (dupId != null ? ' | existingId=' + dupId : '') + '\n';

                        if (!isRetryContext) {
                            CustomExceptionLogger.logDuplicate(
                                new EmailToLeadDmlException(msg),
                                'EmailToLeadService',
                                dupId,
                                lastRequestJSON,
                                lastResponseJSON,
                                emailHeader,
                                emailBody,
                                emailBody
                            );
                        }

                        continue;
                    }

                    String err = e.getStatusCode() + ' | ' + e.getMessage();
                    errors.add(err);
                    debugTrace += 'SaveResult[' + i + ']: ERROR | ' + err + '\n';

                    if (!isRetryContext) {
                        CustomExceptionLogger.logException(
                            new EmailToLeadDmlException(err),
                            'EmailToLeadService',
                            'Insert Failed',
                            null,
                            null,
                            lastRequestJSON,
                            lastResponseJSON,
                            emailHeader,
                            emailBody
                        );
                    }
                }
            }

            if (!success.isEmpty()) {
                result.success = true;
                result.message = 'Created: ' + String.join(success, ',');
            } else {
                result.success = false;
                result.message = 'Failed: ' + String.join(errors, '; ');
            }

        } catch (Exception ex) {

            // Skip logging when called from retry batch — the batch
            // manages the original record's retry state itself.
            // Creating a new log here would duplicate the pending record
            // and cascade into unlimited retry attempts.
            if (!isRetryContext) {
                CustomExceptionLogger.logException(
                    ex,
                    'EmailToLeadService',
                    'Email Service Error',
                    null,
                    createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                    lastRequestJSON,
                    lastResponseJSON,
                    emailHeader,
                    emailBody
                );
            }

            result.success = false;
            result.message = ex.getMessage();
        }

        return result;
    }

    private static void loadFieldSettings() {

        cachedAllowedFields = new Set<String>();

        cachedEmailBodyField = null;
        cachedSummaryField = null;

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> cfg =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (cfg != null) {
            for (EmailToLead_Ai__Email_Lead_Field__c c : cfg.values()) {

                if (String.isNotBlank(c.EmailToLead_Ai__Selected_fields__c)) {
                    for (String f : c.EmailToLead_Ai__Selected_fields__c.split(',')) {
                        cachedAllowedFields.add(f.trim().toLowerCase());
                    }
                }

                if (String.isNotBlank(c.EmailToLead_Ai__Email_Body_Field__c)) {
                    cachedEmailBodyField = c.EmailToLead_Ai__Email_Body_Field__c.trim().toLowerCase();
                }

                if (String.isNotBlank(c.EmailToLead_Ai__Summary_Field__c)) {
                    cachedSummaryField = c.EmailToLead_Ai__Summary_Field__c.trim().toLowerCase();
                }
            }
        }
    }






    private static String callZApi(String body) {

        EmailToLead_Ai__AI_Configure__c uiCfg = [
            SELECT EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__Named_Credential__c,
                   EmailToLead_Ai__Response_Content_Path__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        if (uiCfg == null)
            throw new CalloutException('No AI UI Config');

        String provider =
            String.isBlank(uiCfg.EmailToLead_Ai__Model__c)
            ? 'ZAi'
            : uiCfg.EmailToLead_Ai__Model__c;

        EmailToLead_Ai__AI_Configs__c apiCfg =
            EmailToLead_Ai__AI_Configs__c.getInstance(provider);

        if (apiCfg == null)
            throw new CalloutException('No API Config');

        String allowed =
            String.join(new List<String>(cachedAllowedFields), ',');

        String systemPrompt =
            String.isBlank(uiCfg.EmailToLead_Ai__System_prompt__c)
            ? 'Return JSON only'
            : uiCfg.EmailToLead_Ai__System_prompt__c;

        String userPrompt =
            uiCfg.EmailToLead_Ai__User_Prompt__c
                .replace('{ALLOWED_FIELDS}', allowed)
                .replace('{EMAIL_BODY}', body);

        String requestBody;
        if (provider.toLowerCase().contains('gemini') || 
            (apiCfg.EmailToLead_Ai__Model_Name__c != null && apiCfg.EmailToLead_Ai__Model_Name__c.toLowerCase().contains('gemini'))) {
            
            GeminiApiWrapper geminiReq = new GeminiApiWrapper(systemPrompt, userPrompt);
            requestBody = JSON.serialize(geminiReq);
        } else {
            zApiWrapperClass reqObj = new zApiWrapperClass();
            reqObj.model = apiCfg.EmailToLead_Ai__Model_Name__c;
            reqObj.messages = new List<zApiWrapperClass.Message>{
                new zApiWrapperClass.Message('system', systemPrompt),
                new zApiWrapperClass.Message('user', userPrompt)
            };
            requestBody = JSON.serialize(reqObj);
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint('callout:' + apiCfg.EmailToLead_Ai__Named_Credential__c);
        req.setHeader('Content-Type','application/json');
        req.setTimeout(120000);
        req.setBody(requestBody);
        lastRequestJSON = req.getBody();

        HttpResponse res = new Http().send(req);
        lastResponseJSON = res.getBody();

        if (res.getStatusCode() >= 300)
            throw new CalloutException(res.getBody());

        String path = apiCfg.EmailToLead_Ai__Response_Content_Path__c;
        if (String.isBlank(path)) {
            if (provider.toLowerCase().contains('gemini')) {
                path = 'candidates[0].content.parts[0].text';
            } else {
                path = 'choices[0].message.content';
            }
        }

        return extractContentByPath(res.getBody(), path);
    }

    private static Object extractJsonOrArrayFromAI(String txt) {

        if (String.isBlank(txt))
            throw new CalloutException('Empty AI response');

        String t = txt.trim();

        Integer s1 = t.indexOf('{');
        Integer s2 = t.indexOf('[');

        Integer start =
            (s2 >= 0 && (s1 < 0 || s2 < s1))
            ? s2
            : s1;

        if (start < 0)
            throw new CalloutException('No JSON');

        Boolean isArray = (t.substring(start, start + 1) == '[');

        Integer endPos = isArray ? t.lastIndexOf(']') : t.lastIndexOf('}');

        if (endPos <= start)
            throw new CalloutException('Invalid JSON');

        t = t.substring(start, endPos + 1);

        return JSON.deserializeUntyped(t);
    }

    private static List<Map<String,Object>> extractLeadDataMaps(Object parsed) {

        List<Map<String,Object>> maps = new List<Map<String,Object>>();

        if (parsed instanceof List<Object>) {
            for (Object o : (List<Object>)parsed) {
                if (o instanceof Map<String,Object>) {
                    maps.add((Map<String,Object>)o);
                }
            }
        } else if (parsed instanceof Map<String,Object>) {
            Map<String,Object> root = (Map<String,Object>)parsed;

            if (root.containsKey('leads') && root.get('leads') instanceof List<Object>) {
                for (Object o : (List<Object>)root.get('leads')) {
                    if (o instanceof Map<String,Object>) {
                        maps.add((Map<String,Object>)o);
                    }
                }
            } else {
                maps.add(root);
            }
        }

        return maps;
    }

    private static Lead buildSingleLead(
        Map<String,Object> data,
        Messaging.InboundEmail email,
        String body,
        String emailHeader,
        Integer leadCount
    ) {

        if (data == null || data.isEmpty())
            return null;

        Lead l = new Lead();

        Integer meaningfulFieldCount = 0;
        String aiSummary = null;
        String aiEmailBody = null;
        String leadEmailHeader = null;

        for (String key : data.keySet()) {

            String keyLower = key.toLowerCase();

            if (keyLower == 'summary') {
                aiSummary = String.valueOf(data.get(key));
                continue;
            }

            if (keyLower == 'email_body') {
                aiEmailBody = String.valueOf(data.get(key));
                continue;
            }

            if (keyLower == 'email_header') {
                leadEmailHeader = String.valueOf(data.get(key));
                continue;
            }

            if (keyLower == 'email_footer') {
                continue;
            }

            if (!cachedAllowedFields.contains(keyLower))
                continue;

            // Skip any field containing 'summary' in its name - summary fields should ONLY be populated 
            // through the Summary Field Selector picklist, not through general AI mapping
            if (keyLower.contains('summary')) {
                continue;
            }
            
            // Skip any field containing 'emailbody' or 'email_body' in its name - email body fields should ONLY 
            // be populated through the Email Body Field Selector picklist, not through general AI mapping
            if (keyLower.contains('emailbody') || keyLower.contains('email_body')) {
                continue;
            }

            if (!cachedLeadFields.containsKey(keyLower))
                continue;

            Object rawValue = data.get(key);
            
            if (rawValue == null)
                continue;

            String value = String.valueOf(rawValue);

            if (String.isBlank(value) || value == 'true' || value == 'false')
                continue;

            Schema.SObjectField fieldToken = cachedLeadFields.get(keyLower);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            Schema.DisplayType fieldType = fieldDescribe.getType();

            if (fieldType == Schema.DisplayType.PICKLIST ||
                fieldType == Schema.DisplayType.MULTIPICKLIST) {

                // Skip dependent picklists - valid values depend on controlling field
                if (fieldDescribe.isDependentPicklist()) {
                    continue;
                }

                String validValue = getValidPicklistValue(fieldDescribe, value);

                if (String.isBlank(validValue)) {
                    continue;
                }

                value = validValue;
            }

            // Convert value to correct type for numeric/date fields
            if (fieldType == Schema.DisplayType.CURRENCY ||
                fieldType == Schema.DisplayType.DOUBLE ||
                fieldType == Schema.DisplayType.PERCENT) {
                try {
                    String cleaned = value.replaceAll('[^0-9.\\-]', '');
                    l.put(keyLower, Decimal.valueOf(cleaned));
                } catch (Exception e) {
                    continue;
                }
            } else if (fieldType == Schema.DisplayType.INTEGER) {
                try {
                    String cleaned = value.replaceAll('[^0-9\\-]', '');
                    l.put(keyLower, Integer.valueOf(cleaned));
                } catch (Exception e) {
                    continue;
                }
            } else if (fieldType == Schema.DisplayType.DATE) {
                try {
                    l.put(keyLower, Date.valueOf(value));
                } catch (Exception e) {
                    continue;
                }
            } else if (fieldType == Schema.DisplayType.DATETIME) {
                try {
                    l.put(keyLower, Datetime.valueOf(value));
                } catch (Exception e) {
                    continue;
                }
            } else {
                l.put(keyLower, value);
            }
            meaningfulFieldCount++;
        }
        // If Title is blank but Salutation has value, move it
if (String.isBlank(l.Title) && String.isNotBlank(l.Salutation)) {
    l.Title = l.Salutation;
}


        if (meaningfulFieldCount < 2) {
            return null;
        }

        // Salesforce requires LastName. If AI put everything in FirstName (common for single names), 
        // move it to LastName. Otherwise default to 'Unknown'.
        if (String.isBlank(l.LastName)) {
            if (String.isNotBlank(l.FirstName)) {
                l.LastName = l.FirstName;
                l.FirstName = null;
            } else {
                l.LastName = 'Unknown';
            }
        }
       if (String.isBlank(l.Email) && leadCount == 1 && String.isNotBlank(email.fromAddress)) {
            l.Email = email.fromAddress.toLowerCase();
        }




         // This prevents AI from guessing/inferring Company names
        if (String.isNotBlank(l.Company)) {
            // Check if AI-provided Company actually appears in the email body
            String aiCompany = (String) l.get('company');
            if (String.isNotBlank(aiCompany) && String.isNotBlank(body)) {
                // If Company doesn't appear in body, it's likely an AI guess - clear it
                if (!body.toLowerCase().contains(aiCompany.toLowerCase())) {
                    l.Company = null;
                }
            }
        }
        if (String.isBlank(l.Company)) {
            // Extract domain from emailHeader (real sender like playlsi.com)
            String fromEmail = null;
            if (String.isNotBlank(emailHeader)) {
                Pattern p = Pattern.compile('(?i)From:.*?([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})');
                Matcher m = p.matcher(emailHeader);
                if (m.find()) {
                    fromEmail = m.group(1).toLowerCase();
                }
            }
            if (String.isNotBlank(fromEmail) && fromEmail.contains('@')) {
                String domain = fromEmail.substringAfter('@').toLowerCase();
                l.Company = (domain == 'gmail.com') ? 'Company' : domain;
            } else {
                l.Company = 'Company';
            }
        }

        if (String.isNotBlank(cachedEmailBodyField) &&
            cachedLeadFields.containsKey(cachedEmailBodyField)) {

            if (String.isNotBlank(aiEmailBody)) {
                l.put(cachedEmailBodyField, aiEmailBody.replace('*', ''));
            }
        }

        if (String.isNotBlank(cachedSummaryField) && 
            String.isNotBlank(aiSummary) &&
            cachedLeadFields.containsKey(cachedSummaryField)) {
            
            l.put(cachedSummaryField, aiSummary);
        }
      // Assign Nick owner based on keyword matching
        Map<String, EmailToLead_Ai__Email_Lead_Field__c> fieldCfg = EmailToLead_Ai__Email_Lead_Field__c.getAll();
        if (fieldCfg != null && !fieldCfg.isEmpty()) {
            for (EmailToLead_Ai__Email_Lead_Field__c cfg : fieldCfg.values()) {
                assignNickOwner(cfg, body, l);
            }
        }

        l.put('EmailToLead_Ai__Is_Lead_Created_From_Email__c', true);

        return l;
    }

    private static String getValidPicklistValue(Schema.DescribeFieldResult fieldDescribe, String aiValue) {

        List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();

        String otherValue = null;
        String aiValueLower = aiValue.toLowerCase().trim();

        for (Schema.PicklistEntry entry : picklistEntries) {

            if (!entry.isActive())
                continue;

            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();

            // Exact match on value or label
            if (entryValue.toLowerCase() == aiValueLower ||
                entryLabel.toLowerCase() == aiValueLower) {
                return entryValue;
            }

            // Track "Other" as fallback
            if (entryValue.toLowerCase() == 'other' ||
                entryLabel.toLowerCase() == 'other') {
                otherValue = entryValue;
            }
        }

        // No exact match found → return "Other" if exists, otherwise null (blank)
        return otherValue;
    }




    
     private static void assignNickOwner(
    EmailToLead_Ai__Email_Lead_Field__c cfg,
    String body,
    Lead l
) {

    if (cfg == null
        || l == null
        || String.isBlank(body)
        || String.isBlank(cfg.EmailToLead_Ai__Nick_Keyword__c)
        || String.isBlank(cfg.EmailToLead_Ai__Nick_User__c)) {
        return;
    }

    if (body.toLowerCase().contains(
            cfg.EmailToLead_Ai__Nick_Keyword__c.toLowerCase())) {

        List<User> users = Test.isRunningTest()
            ? [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]
            : [SELECT Id FROM User WHERE Alias = :cfg.EmailToLead_Ai__Nick_User__c LIMIT 1];

        if (!users.isEmpty()) {
            l.OwnerId = users[0].Id;
        }
    }
}

    private static String extractContentByPath(
        String json,
        String path
    ) {

        Object cur = System.JSON.deserializeUntyped(json);

        for (String t : path.split('\\.')) {

            if (t.contains('[')) {

                String k = t.substringBefore('[');

                Integer i = Integer.valueOf(t.substringBetween('[',']'));

                cur = ((List<Object>)((Map<String,Object>)cur).get(k))[i];

            } else {

                cur = ((Map<String,Object>)cur).get(t);
            }

            if (cur == null)
                throw new CalloutException('Bad response path');
        }

        return String.valueOf(cur);
    }

}