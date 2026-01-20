global class EmailToLeadService implements Messaging.InboundEmailHandler {

    @TestVisible private static Boolean FORCE_DML_ERROR_TEST = false;
    private static String lastRequestJSON;
    private static String lastResponseJSON;

    @TestVisible
    private static String test_extractContentByPath(String jsonString, String path) {
        return extractContentByPath(jsonString, path);
    }

    public class EmailToLeadDmlException extends Exception {}

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope env
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        List<Id> createdLeadIds = new List<Id>();
        String cleanedBody = null;

        System.debug('==================== EmailToLeadService START ====================');
        System.debug('### ENV FromAddress: ' + (env != null ? env.fromAddress : 'NULL'));
        System.debug('### ENV ToAddress: ' + (env != null ? env.toAddress : 'NULL'));

        try {
            System.debug('### EMAIL object null? ' + (email == null));

            if (email == null || String.isBlank(email.plainTextBody)) {
                System.debug(LoggingLevel.WARN, '### Email body is empty OR email is null.');
                result.success = false;
                result.message = 'Email body is empty.';
                return result;
            }

            System.debug('### From Address: ' + email.fromAddress);
            System.debug('### Subject: ' + email.subject);
            System.debug('### PlainTextBody: ' + email.plainTextBody);
            System.debug('### HTMLBody present? ' + (!String.isBlank(email.htmlBody)));

            // ✅ Check if this is a forwarded email and extract original sender
            String originalSenderEmail = extractOriginalSender(email.plainTextBody);
            System.debug('### Original Sender Email (from forwarded): ' + originalSenderEmail);

            // ✅ Clean body BEFORE calling AI - smarter for forwarded emails
            cleanedBody = stripSignatureAndFooterSmart(email.plainTextBody);
            System.debug('### CleanedBody: ' + cleanedBody);

            System.debug('### Step-1: Calling AI API...');
            String aiText = callZApi(cleanedBody);
            System.debug('### Step-1 Done: AI Raw Text: ' + aiText);

            System.debug('### Step-2: Extract JSON from AI output...');
            Object parsedJson = extractJsonOrArrayFromAI(aiText);
            System.debug('### Step-2 Done: Parsed JSON: ' + parsedJson);

            System.debug('### Step-3: Building Lead record(s) from JSON...');
            List<Lead> leadsList = buildLeadsFromJson(parsedJson, email, cleanedBody, originalSenderEmail);
            System.debug('### Step-3 Done: Leads ready for insert: ' + leadsList.size());

            if (leadsList.isEmpty()) {
                throw new CalloutException('No valid lead data extracted from AI response.');
            }

            System.debug('### Step-4: Inserting ' + leadsList.size() + ' Lead(s)...');
            Database.SaveResult[] saveResults = Database.insert(leadsList, false);

            // Process results
            List<String> successIds = new List<String>();
            List<String> errorMsgs = new List<String>();

            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                
                if (sr.isSuccess() && !FORCE_DML_ERROR_TEST) {
                    createdLeadIds.add(sr.getId());
                    successIds.add(sr.getId());
                    System.debug('✅ Lead ' + (i+1) + ' Inserted Successfully. LeadId: ' + sr.getId());
                } else {
                    Database.Error err = sr.getErrors()[0];
                    String errMsg = 'Lead ' + (i+1) + ': ' + err.getMessage();
                    errorMsgs.add(errMsg);
                    System.debug(LoggingLevel.ERROR, '❌ ' + errMsg);

                    // Handle duplicate detection
                    if (err instanceof Database.DuplicateError) {
                        Database.DuplicateError dupErr = (Database.DuplicateError)err;
                        Datacloud.DuplicateResult dupRes = dupErr.getDuplicateResult();
                        if (dupRes != null) {
                            System.debug('### DUP RULE: ' + dupRes.getDuplicateRule());
                        }
                    }
                }
            }

            // Log results
            if (!successIds.isEmpty()) {
                CustomExceptionLogger.logSuccess(
                    'Lead(s) created successfully: ' + successIds.size(),
                    'EmailToLeadService',
                    'Success',
                    createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                    lastRequestJSON,
                    lastResponseJSON
                );
            }

            if (!errorMsgs.isEmpty()) {
                String finalMsg = String.join(errorMsgs, ' | ') + ' | Email Body: ' + cleanedBody;
                EmailToLeadDmlException logEx = new EmailToLeadDmlException(finalMsg);

                CustomExceptionLogger.logException(
                    logEx,
                    'EmailToLeadService',
                    finalMsg,
                    null,
                    createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                    lastRequestJSON,
                    lastResponseJSON
                );
            }

            // Set result
            if (!successIds.isEmpty()) {
                result.success = true;
                result.message = 'Lead(s) created: ' + String.join(successIds, ', ');
            } else {
                result.success = false;
                result.message = 'All lead inserts failed: ' + String.join(errorMsgs, '; ');
            }

        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '❌ EmailToLeadService ERROR: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, '❌ STACK TRACE: ' + ex.getStackTraceString());
            System.debug(LoggingLevel.ERROR, '❌ Last Request JSON: ' + lastRequestJSON);
            System.debug(LoggingLevel.ERROR, '❌ Last Response JSON: ' + lastResponseJSON);

            CustomExceptionLogger.logException(
                ex,
                'EmailToLeadService',
                'Email Service Error | Email Body: ' + (cleanedBody != null ? cleanedBody : (email != null ? email.plainTextBody : 'N/A')),
                null,
                createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                lastRequestJSON,
                lastResponseJSON
            );

            result.success = false;
            result.message = ex.getMessage();
        }

        System.debug('==================== EmailToLeadService END ====================');
        return result;
    }

    /* ===================================================================
       ✅ Extract Original Sender from Forwarded Email
       Finds the From address that precedes the LEAD DATA content
    =================================================================== */
    private static String extractOriginalSender(String body) {
        if (String.isBlank(body)) return null;

        // Check if this is a forwarded email
        if (!body.contains('---------- Forwarded message ---------') && 
            !body.contains('-------- Original Message --------') &&
            !body.contains('*From:*')) {
            return null;
        }

        // Keywords that indicate lead data content
        List<String> leadKeywords = new List<String>{
            'Lead Inquiry', 'Contact Email', 'Company Name', 'Contact Name',
            'LSI Lead', 'assigned to your', 'Rep Org ID', 'INQ-'
        };

        String extractedEmail = null;
        Integer leadDataPosition = -1;
        
        // Find where lead data starts
        String lowerBody = body.toLowerCase();
        for (String keyword : leadKeywords) {
            Integer pos = lowerBody.indexOf(keyword.toLowerCase());
            if (pos > 0) {
                if (leadDataPosition == -1 || pos < leadDataPosition) {
                    leadDataPosition = pos;
                }
            }
        }
        
        // Pattern for "From: Name <email@domain.com>" format
        Pattern fromPattern = Pattern.compile('From:\\s*[^<]*<([^>]+@[^>]+)>');
        Matcher fromMatcher = fromPattern.matcher(body);
        
        // Find the LAST From address that appears BEFORE the lead data
        while (fromMatcher.find()) {
            Integer matchPos = fromMatcher.start();
            // If this From is before lead data, keep it (find the closest one to lead data)
            if (leadDataPosition > 0 && matchPos < leadDataPosition) {
                extractedEmail = fromMatcher.group(1).trim();
            }
        }
        
        if (extractedEmail != null) {
            System.debug('✅ Extracted sender before lead data: ' + extractedEmail);
            return extractedEmail;
        }

        // Fallback: Try simpler pattern
        Pattern simplePattern = Pattern.compile('From:\\s*([\\w.-]+@[\\w.-]+)');
        Matcher simpleMatcher = simplePattern.matcher(body);
        
        while (simpleMatcher.find()) {
            Integer matchPos = simpleMatcher.start();
            if (leadDataPosition > 0 && matchPos < leadDataPosition) {
                extractedEmail = simpleMatcher.group(1).trim();
            }
        }
        
        if (extractedEmail != null) {
            System.debug('✅ Extracted sender before lead data (simple): ' + extractedEmail);
        }

        return extractedEmail;
    }

    /* ===================================================================
       ✅ Check if email is forwarded
    =================================================================== */
    private static Boolean isForwardedEmail(String body) {
        if (String.isBlank(body)) return false;
        return body.contains('---------- Forwarded message ---------') ||
               body.contains('-------- Original Message --------') ||
               body.contains('Begin forwarded message:');
    }

    /* ===================================================================
       getAllowedFields
    =================================================================== */
    private static Set<String> getAllowedFields() {
        System.debug('### getAllowedFields() START');

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (allConfigs == null || allConfigs.isEmpty()) {
            System.debug(LoggingLevel.ERROR, '❌ No records found in Email Lead Fields custom setting.');
            throw new CalloutException('Email Lead Fields configuration missing.');
        }

        Set<String> allowed = new Set<String>();

        for (String key : allConfigs.keySet()) {
            EmailToLead_Ai__Email_Lead_Field__c cfg = allConfigs.get(key);

            if (cfg != null && !String.isBlank(cfg.EmailToLead_Ai__Selected_fields__c)) {
                for (String f : cfg.EmailToLead_Ai__Selected_fields__c.split(',')) {
                    if (!String.isBlank(f)) {
                        allowed.add(f.trim());
                    }
                }
            }
        }

        if (allowed.isEmpty()) {
            throw new CalloutException('No Lead fields configured.');
        }

        System.debug('### Combined Allowed Fields: ' + allowed);
        return allowed;
    }

    /* ===================================================================
       ✅ Smarter Signature Stripper for Forwarded Emails
    =================================================================== */
    private static String stripSignatureAndFooterSmart(String body) {
        if (String.isBlank(body)) return body;

        String b = body.replace('\r\n', '\n');

        /* OLD LOGIC - Preserved full content for forwarded emails
        // For forwarded emails, preserve full content for AI
        if (isForwardedEmail(b)) {
            System.debug('### Forwarded email detected - preserving full content');
            return b.trim();
        }

        // For non-forwarded emails, apply signature stripping
        Integer dashIdx = b.indexOf('\n---\n');
        if (dashIdx > 0 && !b.substring(dashIdx).contains('Forwarded')) {
            b = b.substring(0, dashIdx).trim();
        }
        */

        // NEW LOGIC - Extract innermost email body (strip all forwarding headers)
        b = extractInnermostEmailBody(b);

        String lower = b.toLowerCase();
        Integer brIdx = lower.indexOf('\nbest regards');
        if (brIdx > 0) {
            b = b.substring(0, brIdx).trim();
        }

        List<String> markers = new List<String>{
            '\nregards,', '\nthanks,', '\nthank you,', '\nsincerely,', '\n-- \n', '\n___'
        };

        lower = b.toLowerCase();
        Integer cutIndex = -1;

        for (String m : markers) {
            Integer idx = lower.indexOf(m);
            if (idx > 0) {
                cutIndex = (cutIndex == -1) ? idx : Math.min(cutIndex, idx);
            }
        }

        if (cutIndex > 0) {
            b = b.substring(0, cutIndex).trim();
        }

        return b;
    }

    /* ===================================================================
       ✅ Extract Innermost Email Body (strips all forwarding headers)
       Returns the content after the LAST forwarding header block
    =================================================================== */
    private static String extractInnermostEmailBody(String body) {
        if (String.isBlank(body)) return '';
        
        String result = body.trim();
        Boolean foundHeader = true;
        
        // Keep stripping until no more headers found
        while (foundHeader && result.length() > 0) {
            foundHeader = false;
            
            // Pattern 1: Gmail style "---------- Forwarded message ---------"
            Integer gmailIdx = result.indexOf('---------- Forwarded message ---------');
            if (gmailIdx >= 0) {
                // Find the double newline after the header block
                Integer afterHeader = result.indexOf('\n\n', gmailIdx);
                if (afterHeader > gmailIdx) {
                    result = result.substring(afterHeader).trim();
                    foundHeader = true;
                    continue;
                }
            }
            
            // Pattern 2: Outlook style horizontal line with From/Sent/To/Subject
            Integer outlookIdx = result.indexOf('------------------------------');
            if (outlookIdx < 0) {
                outlookIdx = result.indexOf('________________________________');
            }
            if (outlookIdx >= 0) {
                // Check if followed by From/Sent pattern
                String afterLine = result.substring(outlookIdx);
                if (afterLine.contains('*From:*') || afterLine.contains('From:')) {
                    // Find the Subject: line and skip past it
                    Integer subjectIdx = afterLine.toLowerCase().indexOf('subject:');
                    if (subjectIdx > 0) {
                        Integer contentStart = afterLine.indexOf('\n', subjectIdx);
                        if (contentStart > 0) {
                            result = afterLine.substring(contentStart).trim();
                            foundHeader = true;
                            continue;
                        }
                    }
                }
            }
            
            // Pattern 3: Direct "*From:*" or "From:" at the start (Outlook forwarded)
            if (result.startsWith('*From:*') || result.startsWith('From:')) {
                Integer subjectIdx = result.toLowerCase().indexOf('subject:');
                if (subjectIdx > 0) {
                    Integer contentStart = result.indexOf('\n', subjectIdx);
                    if (contentStart > 0) {
                        result = result.substring(contentStart).trim();
                        foundHeader = true;
                        continue;
                    }
                }
            }
        }
        
        // Clean up any remaining signature blocks at the end
        result = stripTrailingSignature(result);
        
        return result.trim();
    }

    /* ===================================================================
       ✅ Strip trailing signature from content
    =================================================================== */
    private static String stripTrailingSignature(String body) {
        if (String.isBlank(body)) return '';
        
        String result = body;
        String lower = result.toLowerCase();
        
        // Find signature markers and cut at the first one
        List<String> sigMarkers = new List<String>{
            '\nview the detailed information available',
            '\nbest regards',
            '\nregards,',
            '\nthanks,',
            '\nsincerely,',
            '\n-- \n'
        };
        
        Integer cutIdx = -1;
        for (String marker : sigMarkers) {
            Integer idx = lower.indexOf(marker);
            if (idx > 0) {
                cutIdx = (cutIdx == -1) ? idx : Math.min(cutIdx, idx);
            }
        }
        
        if (cutIdx > 0) {
            result = result.substring(0, cutIdx).trim();
        }
        
        return result;
    }

    /* ===================================================================
       Normalizers
    =================================================================== */
    private static String normalizeEmail(String e) {
        if (String.isBlank(e)) return null;
        String s = e.trim();
        s = s.replace('mailto:', '');
        s = s.replace('<', '').replace('>', '');
        s = s.replace('[', '').replace(']', '');
        s = s.replace('(', '').replace(')', '');
        s = s.replace('"', '').replace('\'', '');
        return s.trim();
    }

    private static String normalizePhone(String p) {
        if (String.isBlank(p)) return null;
        String s = p.trim();
        s = s.replace('[', '').replace(']', '');
        s = s.replace('(', '').replace(')', '');
        s = s.replace('"', '').replace('\'', '');
        return s.trim();
    }

    private static String normalizeWebsite(String w) {
        if (String.isBlank(w)) return null;
        String s = w.trim();
        s = s.replace('http://', '').replace('https://', '');
        s = s.replace('[', '').replace(']', '');
        s = s.replace('(', '').replace(')', '');
        s = s.replace('"', '').replace('\'', '');
        return s.trim();
    }

    /* ===================================================================
       ✅ Validate Picklist Value
    =================================================================== */
    private static String validatePicklistValue(String fieldName, String aiValue) {
        if (String.isBlank(aiValue)) return null;

        Schema.SObjectField field = Schema.SObjectType.Lead.fields.getMap().get(fieldName);
        if (field == null) return null;

        Schema.DescribeFieldResult fieldDesc = field.getDescribe();
        if (fieldDesc.getType() != Schema.DisplayType.Picklist && 
            fieldDesc.getType() != Schema.DisplayType.MultiPicklist) {
            return aiValue;
        }

        List<Schema.PicklistEntry> entries = fieldDesc.getPicklistValues();
        Set<String> validValues = new Set<String>();
        Boolean hasOther = false;

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                validValues.add(entry.getValue());
                if (entry.getValue().equalsIgnoreCase('Other')) {
                    hasOther = true;
                }
            }
        }

        for (String validVal : validValues) {
            if (validVal.equalsIgnoreCase(aiValue)) {
                return validVal;
            }
        }

        if (hasOther) {
            System.debug('⚠️ AI picklist value "' + aiValue + '" not found for ' + fieldName + ' → fallback to "Other"');
            return 'Other';
        }

        return null;
    }

    /* ===================================================================
       Call AI API
    =================================================================== */
    private static String callZApi(String emailBody) {
        System.debug('### callZApi() START');

        EmailToLead_Ai__AI_Configure__c uiCfg = [
            SELECT EmailToLead_Ai__isActive__c, EmailToLead_Ai__Model__c,
                   EmailToLead_Ai__System_prompt__c, EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__Named_Credential__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];

        if (uiCfg == null) {
            throw new CalloutException('Active AI configuration not found.');
        }

        String model = String.isBlank(uiCfg.EmailToLead_Ai__Model__c) ? 'glm-4.5-air' : uiCfg.EmailToLead_Ai__Model__c;

        if (String.isBlank(uiCfg.EmailToLead_Ai__Named_Credential__c)) {
            throw new CalloutException('Named Credential not configured.');
        }

        Set<String> allowedFields = getAllowedFields();
        String allowedCsv = String.join(new List<String>(allowedFields), ',');

        String systemPrompt = String.isBlank(uiCfg.EmailToLead_Ai__System_prompt__c)
            ? 'You are a Salesforce Lead Extractor. If multiple leads are present, return {"leads": [...]}. If only one lead, return a single JSON object.'
            : uiCfg.EmailToLead_Ai__System_prompt__c;

        String userTemplate = String.isBlank(uiCfg.EmailToLead_Ai__User_Prompt__c)
            ? 'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}. If multiple leads found, return {"leads": [...]}.\n\n{EMAIL_BODY}'
            : uiCfg.EmailToLead_Ai__User_Prompt__c;

        String userPrompt = userTemplate
            .replace('{ALLOWED_FIELDS}', allowedCsv)
            .replace('{EMAIL_BODY}', emailBody);

        zApiWrapperClass reqObj = new zApiWrapperClass();
        reqObj.model = model;
        reqObj.messages = new List<zApiWrapperClass.Message>{
            new zApiWrapperClass.Message('system', systemPrompt),
            new zApiWrapperClass.Message('user', userPrompt)
        };

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setEndpoint('callout:' + uiCfg.EmailToLead_Ai__Named_Credential__c);
        req.setBody(JSON.serialize(reqObj));
        lastRequestJSON = req.getBody();

        HttpResponse res = new Http().send(req);
        lastResponseJSON = (res != null ? res.getBody() : null);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException(res.getBody());
        }

        String extracted = extractContentByPath(res.getBody(), 'choices[0].message.content');
        System.debug('### callZApi() END');
        return extracted;
    }

    /* ===================================================================
       ✅ Extract JSON or Array from AI response
    =================================================================== */
    private static Object extractJsonOrArrayFromAI(String aiText) {
        if (String.isBlank(aiText)) {
            throw new CalloutException('AI response empty.');
        }

        String trimmed = aiText.trim();
        Integer arrayStart = trimmed.indexOf('[');
        Integer objStart = trimmed.indexOf('{');
        Integer jsonStart = -1;

        if (arrayStart >= 0 && (objStart < 0 || arrayStart < objStart)) {
            jsonStart = arrayStart;
        } else if (objStart >= 0) {
            jsonStart = objStart;
        }

        if (jsonStart < 0) {
            throw new CalloutException('AI response does not contain valid JSON.');
        }

        Integer jsonEnd = (trimmed.substring(jsonStart, jsonStart + 1) == '[') 
            ? trimmed.lastIndexOf(']') 
            : trimmed.lastIndexOf('}');

        if (jsonEnd <= jsonStart) {
            throw new CalloutException('AI response does not contain valid JSON.');
        }

        trimmed = trimmed.substring(jsonStart, jsonEnd + 1);
        return JSON.deserializeUntyped(trimmed);
    }

    /* ===================================================================
       ✅ Build Lead(s) - handles multiple leads
    =================================================================== */
    private static List<Lead> buildLeadsFromJson(
        Object parsedJson,
        Messaging.InboundEmail email,
        String cleanedBody,
        String originalSenderEmail
    ) {
        System.debug('### buildLeadsFromJson() START');

        List<Map<String, Object>> leadMaps = new List<Map<String, Object>>();

        if (parsedJson instanceof List<Object>) {
            for (Object item : (List<Object>)parsedJson) {
                if (item instanceof Map<String, Object>) {
                    leadMaps.add((Map<String, Object>)item);
                }
            }
        } else if (parsedJson instanceof Map<String, Object>) {
            Map<String, Object> jsonMap = (Map<String, Object>)parsedJson;
            
            if (jsonMap.containsKey('leads') && jsonMap.get('leads') instanceof List<Object>) {
                for (Object item : (List<Object>)jsonMap.get('leads')) {
                    if (item instanceof Map<String, Object>) {
                        leadMaps.add((Map<String, Object>)item);
                    }
                }
            } else {
                leadMaps.add(jsonMap);
            }
        }

        System.debug('### Found ' + leadMaps.size() + ' lead(s) to create');

        List<Lead> leads = new List<Lead>();
        for (Map<String, Object> leadMap : leadMaps) {
            Lead l = buildSingleLead(leadMap, email, cleanedBody, originalSenderEmail);
            if (l != null) {
                leads.add(l);
            }
        }

        return leads;
    }

    /* ===================================================================
       ✅ Build single Lead from JSON map
    =================================================================== */
    private static Lead buildSingleLead(
        Map<String, Object> jsonMap,
        Messaging.InboundEmail email,
        String cleanedBody,
        String originalSenderEmail
    ) {
        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        EmailToLead_Ai__Email_Lead_Field__c cfg = null;

        if (allConfigs != null && !allConfigs.isEmpty()) {
            for (String key : allConfigs.keySet()) {
                EmailToLead_Ai__Email_Lead_Field__c tempCfg = allConfigs.get(key);
                if (tempCfg != null && tempCfg.EmailToLead_Ai__Is_Active__c) {
                    cfg = tempCfg;
                    break;
                }
            }
        }

        if (cfg == null) {
            throw new CalloutException('Email Lead Fields configuration missing or inactive.');
        }

        Lead leadObj = new Lead();
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Set<String> allowedFields = getAllowedFields();


        for (String key : jsonMap.keySet()) {
            if (allowedFields.contains(key) && leadFields.containsKey(key)) {
                Schema.DescribeFieldResult d = leadFields.get(key).getDescribe();
                if (!d.isCreateable()) continue;

                Object val = jsonMap.get(key);
                if (val == null) continue;

                try {
                    if (key == 'Email') {
                        val = normalizeEmail(String.valueOf(val));
                    } else if (key == 'Phone' || key == 'MobilePhone') {
                        val = normalizePhone(String.valueOf(val));
                    } else if (key == 'Website') {
                        val = normalizeWebsite(String.valueOf(val));
                    }

                    if (val == null) continue;

                    Schema.DisplayType dt = d.getType();

                    if (dt == Schema.DisplayType.Currency || dt == Schema.DisplayType.Double || dt == Schema.DisplayType.Percent) {
                        String s = String.valueOf(val).replace(',', '').trim();
                        if (!String.isBlank(s)) leadObj.put(key, Decimal.valueOf(s));
                    } else if (dt == Schema.DisplayType.Integer) {
                        String s = String.valueOf(val).replace(',', '').trim();
                        if (!String.isBlank(s)) leadObj.put(key, Integer.valueOf(s));
                    } else if (dt == Schema.DisplayType.Boolean) {
                        String s = String.valueOf(val).trim().toLowerCase();
                        leadObj.put(key, (s == 'true' || s == '1' || s == 'yes'));
                    } else if (dt == Schema.DisplayType.Picklist || dt == Schema.DisplayType.MultiPicklist) {
                        String validatedValue = validatePicklistValue(key, String.valueOf(val));
                        if (validatedValue != null) leadObj.put(key, validatedValue);
                    } else {
                        leadObj.put(key, String.valueOf(val));
                    }

                } catch (Exception ex) {
                    System.debug('⚠️ Field conversion skipped for ' + key + ': ' + ex.getMessage());
                }
            }
        }

        // LeadSource fallback
        if (String.isBlank(leadObj.LeadSource)) {
            String defaultLeadSource = validatePicklistValue('LeadSource', 'Other');
            if (defaultLeadSource != null) leadObj.LeadSource = defaultLeadSource;
        }

        // Store email body
        if (!String.isBlank(cfg.EmailToLead_Ai__Email_Body_Field__c)
            && leadFields.containsKey(cfg.EmailToLead_Ai__Email_Body_Field__c)) {
            leadObj.put(cfg.EmailToLead_Ai__Email_Body_Field__c, cleanedBody);
        }

        // Summary storage
        if (!String.isBlank(cfg.EmailToLead_Ai__Summary_Field__c)
            && jsonMap.containsKey('summary')
            && leadFields.containsKey(cfg.EmailToLead_Ai__Summary_Field__c)) {
            leadObj.put(cfg.EmailToLead_Ai__Summary_Field__c, jsonMap.get('summary'));
        }

        // Defaults
        leadObj.EmailToLead_Ai__Is_Lead_Created_From_Email__c = true;
        if (String.isBlank(leadObj.LastName)) leadObj.LastName = 'Unknown';
        // Happy Birthday Yesudas
        
        // Email priority: AI extracted > Original sender > email.fromAddress
        if (String.isBlank(leadObj.Email)) {
            leadObj.Email = !String.isBlank(originalSenderEmail) ? originalSenderEmail : email.fromAddress;
        }

        // Derive company ONLY if Company field is blank after AI processing
        // If AI provided a non-empty Company, keep it. If blank/empty, derive from originalSenderEmail domain.
        if (String.isBlank(leadObj.Company)) {
            // Priority: originalSenderEmail (From with lead data) > email.fromAddress
            String emailForCompany = !String.isBlank(originalSenderEmail) ? originalSenderEmail : email.fromAddress;
            if (emailForCompany != null && emailForCompany.contains('@')) {
                String domain = emailForCompany.substringAfter('@');
                // Gmail = 'Company', other domains = the domain itself
                leadObj.Company = domain.toLowerCase().contains('gmail.com') ? 'Company' : domain;
                System.debug('✅ Company derived from email domain: ' + leadObj.Company);
            }
        }

        assignNickOwner(cfg, cleanedBody, leadObj);
        return leadObj;
    }

    private static void assignNickOwner(
        EmailToLead_Ai__Email_Lead_Field__c cfg,
        String body,
        Lead leadObj
    ) {
        if (String.isBlank(body)
            || String.isBlank(cfg.EmailToLead_Ai__Nick_Keyword__c) //
            || String.isBlank(cfg.EmailToLead_Ai__Nick_User__c)) {
            return;
        }

        if (body.toLowerCase().contains(cfg.EmailToLead_Ai__Nick_Keyword__c.toLowerCase())) {
            List<User> users = Test.isRunningTest()
                ? [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1]
                : [SELECT Id FROM User WHERE Alias = :cfg.EmailToLead_Ai__Nick_User__c LIMIT 1];

            if (!users.isEmpty()) {
                leadObj.OwnerId = users[0].Id;
            }
        }
    }

    private static String extractContentByPath(String json, String path) {
        Object current = System.JSON.deserializeUntyped(json);

        for (String token : path.split('\\.')) {
            if (token.contains('[')) {
                String key = token.substringBefore('[');
                Integer idx = Integer.valueOf(token.substringBetween('[', ']'));
                Object child = ((Map<String, Object>) current).get(key);
                if (child == null) throw new CalloutException('Invalid response path: ' + path);
                current = ((List<Object>) child)[idx];
            } else {
                current = ((Map<String, Object>) current).get(token);
            }
            if (current == null) throw new CalloutException('Invalid response path: ' + path);
        }

        return String.valueOf(current);
    }
}
