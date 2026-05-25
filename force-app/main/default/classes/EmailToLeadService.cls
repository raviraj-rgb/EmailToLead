global class EmailToLeadService implements Messaging.InboundEmailHandler {

    @TestVisible public static Boolean isRetryContext = false;
    @TestVisible private static Boolean FORCE_DML_ERROR_TEST = false;
    @TestVisible public static List<Id> createdLeadIds = new List<Id>();
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

        try {
            if (email == null || String.isBlank(email.plainTextBody)) {
                result.success = false;
                result.message = 'Email body is empty.';
                return result;
            }

            // ✅ Use the outermost (direct) sender as the fallback email/company.
            // email.fromAddress is what Salesforce captured from the envelope —
            // i.e. raviraj@untangleit.in — the person who actually forwarded to Salesforce.
            // Only fall back to body-scanning when fromAddress is blank or a system/no-reply address.
            String originalSenderEmail;
            if (String.isNotBlank(email.fromAddress) && !isSystemEmail(email.fromAddress)) {
                originalSenderEmail = email.fromAddress;
            } else {
                originalSenderEmail = extractOriginalSender(email.plainTextBody);
            }
            
            // ✅ Clean body BEFORE calling AI
            cleanedBody = stripSignatureAndFooterSmart(email.plainTextBody);

            // ✅ Proactive check for Daily Summary Template
            if (cleanedBody.contains('Your daily summary of Leads')) {
                if (!isRetryContext) {
                    CustomExceptionLogger.logSkipped(
                        'Skipped: Daily summary email — not processed.',
                        'EmailToLeadService',
                        email.subject,
                        formatCompleteEmailBody(email),
                        'Pre-AI Check: Daily Summary Detected',
                        'N/A'
                    );
                }
                result.success = false;
                result.message = 'Skipped: Daily summary email — not processed.';
                return result;
            }

            System.debug('### Step-1: Calling AI API...');
            String aiText = callZApi(cleanedBody);

            System.debug('### Step-2: Extract JSON from AI output...');
            Object parsedJson = extractJsonOrArrayFromAI(aiText);

            System.debug('### Step-3: Building Lead record(s) from JSON...');
            List<Lead> leadsList = buildLeadsFromJson(parsedJson, email, cleanedBody, originalSenderEmail);

            if (leadsList.isEmpty()) {
                String logHeader = '';
                if (parsedJson instanceof Map<String, Object>) {
                    Map<String, Object> jsonMap = (Map<String, Object>)parsedJson;
                    if (jsonMap.containsKey('email_header')) {
                        logHeader = String.valueOf(jsonMap.get('email_header'));
                    }
                }

                if (!isRetryContext) {
                    CustomExceptionLogger.logSkipped(
                        'No valid lead data extracted from AI response (Daily Summary or Non-Lead content).',
                        'EmailToLeadService',
                        String.isBlank(logHeader) ? email.subject : logHeader,
                        email.plainTextBody,
                        lastRequestJSON,
                        lastResponseJSON
                    );
                }

                result.success = false;
                result.message = 'Skipped: No lead data found.';
                return result;
            }

            System.debug('### Step-4: Inserting Lead(s)...');
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.allowSave = true;
            dml.DuplicateRuleHeader.runAsCurrentUser = true;
            dml.optAllOrNone = false;

            Database.SaveResult[] saveResults = Database.insert(leadsList, dml);

            List<String> successIds = new List<String>();
            List<String> errorMsgs = new List<String>();

            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                if (sr.isSuccess() && !FORCE_DML_ERROR_TEST) {
                    createdLeadIds.add(sr.getId());
                    successIds.add(sr.getId());
                } else {
                    errorMsgs.add('Lead ' + (i+1) + ': ' + sr.getErrors()[0].getMessage());
                }
            }

            // Log results (Success is ALWAYS logged, even in retry, to provide a clean audit trail)
            if (!successIds.isEmpty()) {
                CustomExceptionLogger.logSuccess(
                    'Lead(s) created successfully: ' + successIds.size(),
                    'EmailToLeadService',
                    'Success',
                    createdLeadIds[0],
                    lastRequestJSON,
                    lastResponseJSON,
                    email != null ? formatEmailHeader(email) : null,
                    email != null ? formatCompleteEmailBody(email) : null
                );
            }

            if (!errorMsgs.isEmpty() && !isRetryContext) {
                String finalMsg = String.join(errorMsgs, ' | ') + ' | Email Body: ' + cleanedBody;
                EmailToLeadDmlException logEx = new EmailToLeadDmlException(finalMsg);

                CustomExceptionLogger.logException(
                    logEx,
                    'EmailToLeadService',
                    'DML Error',
                    createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                    formatEmailHeader(email),
                    formatCompleteEmailBody(email),
                    lastRequestJSON,
                    lastResponseJSON
                );
            }

            if (!successIds.isEmpty()) {
                result.success = true;
                result.message = 'Lead(s) created: ' + String.join(successIds, ', ');
            } else {
                result.success = false;
                result.message = 'All lead inserts failed: ' + String.join(errorMsgs, '; ');
            }

        } catch (Exception ex) {
            if (!isRetryContext) {
                CustomExceptionLogger.logException(
                    ex,
                    'EmailToLeadService',
                    'System Error',
                    createdLeadIds.isEmpty() ? null : createdLeadIds[0],
                    email != null ? formatEmailHeader(email) : 'N/A',
                    formatCompleteEmailBody(email),
                    lastRequestJSON,
                    lastResponseJSON
                );
            }

            result.success = false;
            result.message = ex.getMessage();
        }

        return result;
    }

    /* ===================================================================
       ✅ Extract Original Sender from Forwarded Email
       Finds the From address that precedes the LEAD DATA content
    =================================================================== */
    public static String extractOriginalSender(String body) {
        if (String.isBlank(body)) return null;

        // Pattern 1: Look for "From: Name <email@domain.com>" or "From: email@domain.com"
        Pattern fromPattern = Pattern.compile('(?i)From:\\s*[^\\n<]*<?([\\w.-]+@[\\w.-]+\\.[\\w]{2,})>?');
        Matcher fromMatcher = fromPattern.matcher(body);
        
        String extractedEmail = null;
        while (fromMatcher.find()) {
            String temp = fromMatcher.group(1).trim();
            if (!isSystemEmail(temp)) {
                extractedEmail = temp;
            }
        }
        
        if (extractedEmail != null) return extractedEmail;

        // Pattern 2: Fallback - look for any Email appearing after a "Forwarded" marker
        if (body.contains('Forwarded') || body.contains('From:')) {
            Pattern emailPattern = Pattern.compile('[\\w.-]+@[\\w.-]+\\.[\\w]{2,}');
            Matcher emailMatcher = emailPattern.matcher(body);
            while (emailMatcher.find()) {
                String temp = emailMatcher.group().trim();
                if (!isSystemEmail(temp)) {
                    return temp;
                }
            }
        }

        return null;
    }

    public static Boolean isSystemEmail(String emailStr) {
        if (String.isBlank(emailStr)) return false;
        String e = emailStr.toLowerCase();
        return e.contains('noreply') || 
               e.contains('no-reply') || 
               e.contains('donotreply') || 
               e.contains('do-not-reply') || 
               e.contains('mailer-daemon');
    }

    private static Set<String> getAllowedFields() {
        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs = EmailToLead_Ai__Email_Lead_Field__c.getAll();
        if (allConfigs == null || allConfigs.isEmpty()) throw new CalloutException('Email Lead Fields configuration missing.');
        Set<String> allowed = new Set<String>();
        for (String key : allConfigs.keySet()) {
            EmailToLead_Ai__Email_Lead_Field__c cfg = allConfigs.get(key);
            if (cfg != null && !String.isBlank(cfg.EmailToLead_Ai__Selected_fields__c)) {
                for (String f : cfg.EmailToLead_Ai__Selected_fields__c.split(',')) if (!String.isBlank(f)) allowed.add(f.trim());
            }
        }
        return allowed;
    }

    private static String stripSignatureAndFooterSmart(String body) {
        if (String.isBlank(body)) return body;
        String b = extractInnermostEmailBody(body.replace('\r\n', '\n'));
        String lower = b.toLowerCase();
        List<String> markers = new List<String>{'\nbest regards', '\nregards,', '\nthanks,', '\nthank you,', '\nsincerely,', '\n-- \n', '\n___'};
        Integer cutIndex = -1;
        for (String m : markers) {
            Integer idx = lower.indexOf(m);
            if (idx > 0) cutIndex = (cutIndex == -1) ? idx : Math.min(cutIndex, idx);
        }
        if (cutIndex > 0) b = b.substring(0, cutIndex).trim();
        return b;
    }

    private static String extractInnermostEmailBody(String body) {
        if (String.isBlank(body)) return '';
        String result = body.trim();
        Boolean foundHeader = true;
        while (foundHeader && result.length() > 0) {
            foundHeader = false;
            Integer gmailIdx = result.indexOf('---------- Forwarded message ---------');
            if (gmailIdx >= 0) {
                Integer afterHeader = result.indexOf('\n\n', gmailIdx);
                if (afterHeader > gmailIdx) { result = result.substring(afterHeader).trim(); foundHeader = true; continue; }
            }
            Integer outlookIdx = result.indexOf('------------------------------');
            if (outlookIdx < 0) outlookIdx = result.indexOf('________________________________');
            if (outlookIdx >= 0) {
                String afterLine = result.substring(outlookIdx);
                if (afterLine.contains('*From:*') || afterLine.contains('From:')) {
                    Integer subjectIdx = afterLine.toLowerCase().indexOf('subject:');
                    if (subjectIdx > 0) {
                        Integer contentStart = afterLine.indexOf('\n', subjectIdx);
                        if (contentStart > 0) { result = afterLine.substring(contentStart).trim(); foundHeader = true; continue; }
                    }
                }
            }
            if (result.startsWith('*From:*') || result.startsWith('From:')) {
                Integer subjectIdx = result.toLowerCase().indexOf('subject:');
                if (subjectIdx > 0) {
                    Integer contentStart = result.indexOf('\n', subjectIdx);
                    if (contentStart > 0) { result = result.substring(contentStart).trim(); foundHeader = true; continue; }
                }
            }
        }
        return stripTrailingSignature(result);
    }

    private static String stripTrailingSignature(String body) {
        if (String.isBlank(body)) return '';
        String result = body;
        String lower = result.toLowerCase();
        List<String> sigMarkers = new List<String>{'\nview the detailed information available', '\nbest regards', '\nregards,', '\nthanks,', '\nsincerely,', '\n-- \n'};
        Integer cutIdx = -1;
        for (String marker : sigMarkers) {
            Integer idx = lower.indexOf(marker);
            if (idx > 0) cutIdx = (cutIdx == -1) ? idx : Math.min(cutIdx, idx);
        }
        if (cutIdx > 0) result = result.substring(0, cutIdx).trim();
        return result;
    }

    private static String normalizeEmail(String e) {
        if (String.isBlank(e)) return null;
        String s = e.trim();
        s = s.replace('mailto:', '').replace('<', '').replace('>', '').replace('[', '').replace(']', '').replace('(', '').replace(')', '').replace('"', '').replace('\'', '');
        return s.trim();
    }

    private static String normalizePhone(String p) {
        if (String.isBlank(p)) return null;
        String s = p.trim();
        s = s.replace('[', '').replace(']', '').replace('(', '').replace(')', '').replace('"', '').replace('\'', '');
        return s.trim();
    }

    private static String normalizeWebsite(String w) {
        if (String.isBlank(w)) return null;
        String s = w.trim();
        s = s.replace('http://', '').replace('https://', '').replace('[', '').replace(']', '').replace('(', '').replace(')', '').replace('"', '').replace('\'', '');
        return s.trim();
    }

    private static String validatePicklistValue(String fieldName, String aiValue) {
        if (String.isBlank(aiValue)) return null;
        Schema.SObjectField field = Schema.SObjectType.Lead.fields.getMap().get(fieldName);
        if (field == null) return null;
        Schema.DescribeFieldResult fieldDesc = field.getDescribe();
        if (fieldDesc.getType() != Schema.DisplayType.Picklist && fieldDesc.getType() != Schema.DisplayType.MultiPicklist) return aiValue;
        List<Schema.PicklistEntry> entries = fieldDesc.getPicklistValues();
        Set<String> validValues = new Set<String>();
        Boolean hasOther = false;
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                validValues.add(entry.getValue());
                if (entry.getValue().equalsIgnoreCase('Other')) hasOther = true;
            }
        }
        for (String validVal : validValues) if (validVal.equalsIgnoreCase(aiValue)) return validVal;
        if (hasOther) return 'Other';
        return null;
    }

    private static String callZApi(String emailBody) {
        EmailToLead_Ai__AI_Configure__c uiCfg = [SELECT EmailToLead_Ai__isActive__c, EmailToLead_Ai__Model__c, EmailToLead_Ai__System_prompt__c, EmailToLead_Ai__User_Prompt__c, EmailToLead_Ai__Named_Credential__c FROM EmailToLead_Ai__AI_Configure__c WHERE EmailToLead_Ai__isActive__c = true LIMIT 1];
        String model = String.isBlank(uiCfg.EmailToLead_Ai__Model__c) ? 'glm-4.5-air' : uiCfg.EmailToLead_Ai__Model__c;
        Set<String> allowedFields = getAllowedFields();
        String allowedCsv = String.join(new List<String>(allowedFields), ',');
        String systemPrompt = String.isBlank(uiCfg.EmailToLead_Ai__System_prompt__c) ? '... default ...' : uiCfg.EmailToLead_Ai__System_prompt__c;
        String userTemplate = String.isBlank(uiCfg.EmailToLead_Ai__User_Prompt__c) ? '... default ...' : uiCfg.EmailToLead_Ai__User_Prompt__c;
        String userPrompt = userTemplate.replace('{ALLOWED_FIELDS}', allowedCsv).replace('{EMAIL_BODY}', emailBody);
        String reqBody;
        if (model.toLowerCase().contains('gpt')) {
            ChatGPTWrapperClass chatReq = new ChatGPTWrapperClass(); chatReq.model = model; chatReq.input = systemPrompt + '\n\n' + userPrompt; chatReq.store = true; reqBody = JSON.serialize(chatReq);
        } else if (model.toLowerCase().contains('gemini')) {
            GeminiWrapperClass gemReq = new GeminiWrapperClass(); gemReq.setSystemInstruction(systemPrompt); gemReq.addUserMessage(userPrompt); reqBody = JSON.serialize(gemReq);
        } else {
            zApiWrapperClass reqObj = new zApiWrapperClass(); reqObj.model = model; reqObj.messages = new List<zApiWrapperClass.Message>{new zApiWrapperClass.Message('system', systemPrompt), new zApiWrapperClass.Message('user', userPrompt)}; reqBody = JSON.serialize(reqObj);
        }
        HttpRequest req = new HttpRequest(); req.setMethod('POST'); req.setHeader('Content-Type', 'application/json'); req.setTimeout(120000); req.setEndpoint('callout:' + uiCfg.EmailToLead_Ai__Named_Credential__c); req.setBody(reqBody); lastRequestJSON = reqBody;
        HttpResponse res = new Http().send(req); lastResponseJSON = (res != null ? res.getBody() : null);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) throw new CalloutException(res.getBody());
        EmailToLead_Ai__Ai_Configs__c cs = EmailToLead_Ai__Ai_Configs__c.getValues(uiCfg.EmailToLead_Ai__Model__c);
        String responsePath = (cs != null && !String.isBlank(cs.EmailToLead_Ai__Response_Content_Path__c)) ? cs.EmailToLead_Ai__Response_Content_Path__c : (model.toLowerCase().contains('gpt') ? 'output[0].content[0].text' : 'choices[0].message.content');
        return extractContentByPath(res.getBody(), responsePath);
    }

    private static Object extractJsonOrArrayFromAI(String aiText) {
        if (String.isBlank(aiText)) throw new CalloutException('AI response empty.');
        String trimmed = aiText.trim();
        Integer arrayStart = trimmed.indexOf('['); Integer objStart = trimmed.indexOf('{'); Integer jsonStart = (arrayStart >= 0 && (objStart < 0 || arrayStart < objStart)) ? arrayStart : objStart;
        if (jsonStart < 0) throw new CalloutException('AI response does not contain valid JSON.');
        Integer jsonEnd = (trimmed.substring(jsonStart, jsonStart + 1) == '[') ? trimmed.lastIndexOf(']') : trimmed.lastIndexOf('}');
        if (jsonEnd <= jsonStart) throw new CalloutException('AI response does not contain valid JSON.');
        return JSON.deserializeUntyped(trimmed.substring(jsonStart, jsonEnd + 1));
    }

    private static List<Lead> buildLeadsFromJson(Object parsedJson, Messaging.InboundEmail email, String cleanedBody, String originalSenderEmail) {
        List<Map<String, Object>> leadMaps = new List<Map<String, Object>>();
        if (parsedJson instanceof List<Object>) {
            for (Object item : (List<Object>)parsedJson) if (item instanceof Map<String, Object> && !((Map<String, Object>)item).isEmpty()) leadMaps.add((Map<String, Object>)item);
        } else if (parsedJson instanceof Map<String, Object>) {
            Map<String, Object> jsonMap = (Map<String, Object>)parsedJson;
            if (jsonMap.containsKey('leads') && jsonMap.get('leads') instanceof List<Object>) {
                for (Object item : (List<Object>)jsonMap.get('leads')) if (item instanceof Map<String, Object> && !((Map<String, Object>)item).isEmpty()) leadMaps.add((Map<String, Object>)item);
            } else if (!jsonMap.isEmpty()) leadMaps.add(jsonMap);
        }
        List<Lead> leads = new List<Lead>();
        for (Map<String, Object> leadMap : leadMaps) {
            Lead l = buildSingleLead(leadMap, email, cleanedBody, originalSenderEmail);
            if (l != null) leads.add(l);
        }
        return leads;
    }

    private static Lead buildSingleLead(Map<String, Object> jsonMap, Messaging.InboundEmail email, String cleanedBody, String originalSenderEmail) {
        EmailToLead_Ai__Email_Lead_Field__c cfg = null;
        for (EmailToLead_Ai__Email_Lead_Field__c c : EmailToLead_Ai__Email_Lead_Field__c.getAll().values()) if (c.EmailToLead_Ai__Is_Active__c) { cfg = c; break; }
        if (cfg == null) throw new CalloutException('Email Lead Fields configuration missing or inactive.');
        Lead leadObj = new Lead();
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        Set<String> allowedFields = getAllowedFields();
        for (String key : jsonMap.keySet()) {
            if (allowedFields.contains(key) && leadFields.containsKey(key)) {
                Schema.DescribeFieldResult fieldDesc = leadFields.get(key).getDescribe();
                if (!fieldDesc.isCreateable()) continue;
                Object val = jsonMap.get(key);
                if (val == null) continue;
                try {
                    if (key == 'Email') val = normalizeEmail(String.valueOf(val));
                    else if (key == 'Phone' || key == 'MobilePhone') val = normalizePhone(String.valueOf(val));
                    else if (key == 'Website') val = normalizeWebsite(String.valueOf(val));
                    if (val == null) continue;
                    Schema.DisplayType dt = fieldDesc.getType();
                    if (dt == Schema.DisplayType.Currency || dt == Schema.DisplayType.Double || dt == Schema.DisplayType.Percent) {
                        String s = String.valueOf(val).replace(',', '').trim(); if (!String.isBlank(s)) leadObj.put(key, Decimal.valueOf(s));
                    } else if (dt == Schema.DisplayType.Integer) {
                        String s = String.valueOf(val).replace(',', '').trim(); if (!String.isBlank(s)) leadObj.put(key, Integer.valueOf(s));
                    } else if (dt == Schema.DisplayType.Boolean) {
                        String s = String.valueOf(val).trim().toLowerCase(); leadObj.put(key, (s == 'true' || s == '1' || s == 'yes'));
                    } else if (dt == Schema.DisplayType.Picklist || dt == Schema.DisplayType.MultiPicklist) {
                        String validatedValue = validatePicklistValue(key, String.valueOf(val)); if (validatedValue != null) leadObj.put(key, validatedValue);
                    } else leadObj.put(key, String.valueOf(val));
                } catch (Exception ex) { System.debug('⚠️ Field conversion skipped for ' + key + ': ' + ex.getMessage()); }
            }
        }
        if (String.isBlank(leadObj.LeadSource)) leadObj.LeadSource = validatePicklistValue('LeadSource', 'Other');

        // ✅ Use AI's clean email_body for the Description/body field.
        // The AI already strips forwarded headers, signatures, and boilerplate —
        // returning only the actual lead form content.
        // Fall back to cleanedBody if AI didn't return an email_body.
        if (!String.isBlank(cfg.EmailToLead_Ai__Email_Body_Field__c) && leadFields.containsKey(cfg.EmailToLead_Ai__Email_Body_Field__c)) {
            String aiEmailBody = jsonMap.containsKey('email_body') ? String.valueOf(jsonMap.get('email_body')) : '';
            leadObj.put(cfg.EmailToLead_Ai__Email_Body_Field__c, String.isNotBlank(aiEmailBody) ? aiEmailBody : cleanedBody);
        }
        if (!String.isBlank(cfg.EmailToLead_Ai__Summary_Field__c) && jsonMap.containsKey('summary') && leadFields.containsKey(cfg.EmailToLead_Ai__Summary_Field__c)) leadObj.put(cfg.EmailToLead_Ai__Summary_Field__c, jsonMap.get('summary'));
        leadObj.EmailToLead_Ai__Is_Lead_Created_From_Email__c = true;

        // ✅ Name fallback: if AI didn't split the name into FirstName/LastName,
        // parse it from the email_body field that AI returned.
        if (String.isBlank(leadObj.FirstName) && String.isBlank(leadObj.LastName)) {
            String aiBody = jsonMap.containsKey('email_body') ? String.valueOf(jsonMap.get('email_body')) : '';
            if (String.isBlank(aiBody)) aiBody = cleanedBody;
            Pattern nameP = Pattern.compile('(?im)^(?:Name|Full Name|Contact Name):\\s*(.+)$');
            Matcher nameM = nameP.matcher(aiBody);
            if (nameM.find()) {
                String fullName = nameM.group(1).trim();
                Integer spaceIdx = fullName.indexOf(' ');
                if (spaceIdx > 0) {
                    leadObj.FirstName = fullName.substring(0, spaceIdx).trim();
                    leadObj.LastName  = fullName.substring(spaceIdx + 1).trim();
                } else {
                    leadObj.LastName = fullName;
                }
            }
        }
        if (String.isBlank(leadObj.LastName)) leadObj.LastName = 'Unknown';
        
        // Email priority: AI extracted > Original sender > email.fromAddress
        if (String.isBlank(leadObj.Email)) {
            leadObj.Email = !String.isBlank(originalSenderEmail) ? originalSenderEmail : email.fromAddress;
        }

        // Derive company ONLY if Company field is blank after AI processing
        if (String.isBlank(leadObj.Company)) {
            String emailForCompany = !String.isBlank(originalSenderEmail) ? originalSenderEmail : email.fromAddress;
            if (emailForCompany != null && emailForCompany.contains('@')) {
                String domain = emailForCompany.substringAfter('@').toLowerCase();
                leadObj.Company = domain.contains('gmail.com') ? 'Company' : domain;
            }
        }

        assignNickOwner(cfg, cleanedBody, leadObj);
        return leadObj;
    }

    private static void assignNickOwner(EmailToLead_Ai__Email_Lead_Field__c cfg, String body, Lead leadObj) {
        if (String.isBlank(body) || String.isBlank(cfg.EmailToLead_Ai__Nick_Keyword__c) || String.isBlank(cfg.EmailToLead_Ai__Nick_User__c)) return;
        if (body.toLowerCase().contains(cfg.EmailToLead_Ai__Nick_Keyword__c.toLowerCase())) {
            List<User> users = Test.isRunningTest() ? [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1] : [SELECT Id FROM User WHERE Alias = :cfg.EmailToLead_Ai__Nick_User__c LIMIT 1];
            if (!users.isEmpty()) leadObj.OwnerId = users[0].Id;
        }
    }

    private static String extractContentByPath(String json, String path) {
        Object current = System.JSON.deserializeUntyped(json);
        for (String token : path.split('\\.')) {
            if (token.contains('[')) {
                String key = token.substringBefore('['); Integer idx = Integer.valueOf(token.substringBetween('[', ']'));
                Object child = ((Map<String, Object>) current).get(key); if (child == null) throw new CalloutException('Invalid response path: ' + path);
                current = ((List<Object>) child)[idx];
            } else current = ((Map<String, Object>) current).get(token);
            if (current == null) throw new CalloutException('Invalid response path: ' + path);
        }
        return String.valueOf(current);
    }

    public static String formatEmailHeader(Messaging.InboundEmail email) {
        if (email == null) return 'N/A';
        String fromAddr = String.isNotBlank(email.fromAddress) ? email.fromAddress : '';
        String subj = String.isNotBlank(email.subject) ? email.subject : '';
        return 'From: ' + fromAddr + ' | Subject: ' + subj;
    }

    public static String formatCompleteEmailBody(Messaging.InboundEmail email) {
        if (email == null) return '';
        String fromAddr = String.isNotBlank(email.fromAddress) ? email.fromAddress : '';
        String subj = String.isNotBlank(email.subject) ? email.subject : '';
        String body = String.isNotBlank(email.plainTextBody) ? email.plainTextBody : '';
        return 'From: ' + fromAddr + '\nSubject: ' + subj + '\n\n' + body;
    }
}
//Gitting
