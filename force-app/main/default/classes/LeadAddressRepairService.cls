public with sharing class LeadAddressRepairService {

    public static void repair(List<Id> leadIds) {
        if (leadIds.isEmpty()) return;
        System.enqueueJob(new AddressRepairQueueable(leadIds));
    }

    public class AddressRepairQueueable implements Queueable, Database.AllowsCallouts {

        private List<Id> leadIds;

        public AddressRepairQueueable(List<Id> leadIds) {
            this.leadIds = leadIds;
        }

        public void execute(QueueableContext ctx) {
            List<Lead> leads = [
                SELECT Id, EmailToLead_Ai__emailBody__c
                FROM Lead
                WHERE Id IN :leadIds
                  AND EmailToLead_Ai__Is_Lead_Created_From_Email__c = true
                  AND LeadSource = 'LSI'
                  AND Project_City__c = null
            ];

            EmailToLead_Ai__AI_Configure__c uiCfg = getActiveConfig();
            if (uiCfg == null) return;

            List<Lead> toUpdate = new List<Lead>();
            Map<String, Schema.SObjectField> lf = Schema.SObjectType.Lead.fields.getMap();

            for (Lead l : leads) {
                if (String.isBlank(l.EmailToLead_Ai__emailBody__c)) continue;

                Map<String, String> parsed = callAIForAddress(l.EmailToLead_Ai__emailBody__c, uiCfg);
                if (parsed == null || String.isBlank(parsed.get('City'))) continue;

                Lead upd = new Lead(Id = l.Id);
                upd.Street     = parsed.get('Street');
                upd.City       = parsed.get('City');
                upd.State      = parsed.get('State');
                upd.PostalCode = parsed.get('PostalCode');
                upd.Country    = parsed.get('Country');

                putProjectField(upd, lf, 'project_address__c',  'emailtolead_ai__project_address__c',  parsed.get('Street'));
                putProjectField(upd, lf, 'project_city__c',     'emailtolead_ai__project_city__c',     parsed.get('City'));
                putProjectField(upd, lf, 'project_state__c',    'emailtolead_ai__project_state__c',    parsed.get('State'));
                putProjectField(upd, lf, 'project_zip_code__c', 'emailtolead_ai__project_zip_code__c', parsed.get('PostalCode'));
                putProjectField(upd, lf, 'project_country__c',  'emailtolead_ai__project_country__c',  parsed.get('Country'));

                toUpdate.add(upd);
            }

            if (!toUpdate.isEmpty()) {
                Database.DMLOptions dml = new Database.DMLOptions();
                dml.assignmentRuleHeader.useDefaultRule = true;
                Database.update(toUpdate, dml);
            }
        }
    }

    private static void putProjectField(Lead upd, Map<String, Schema.SObjectField> lf, String orgKey, String pkgKey, String val) {
        if (String.isBlank(val)) return;
        if (lf.containsKey(orgKey)) {
            upd.put(lf.get(orgKey), val);
        } else if (lf.containsKey(pkgKey)) {
            upd.put(lf.get(pkgKey), val);
        }
    }

    private static EmailToLead_Ai__AI_Configure__c getActiveConfig() {
        List<EmailToLead_Ai__AI_Configure__c> cfgs = [
            SELECT EmailToLead_Ai__Model__c, EmailToLead_Ai__Named_Credential__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
            LIMIT 1
        ];
        return cfgs.isEmpty() ? null : cfgs[0];
    }

    @TestVisible
    private static Map<String, String> callAIForAddress(String emailBody, EmailToLead_Ai__AI_Configure__c uiCfg) {
        String systemPrompt =
            'You are an address parser. From the email body provided, find the "Address:" field ' +
            'and parse it into components. Return a JSON object with ONLY these keys: ' +
            'Street, City, State, PostalCode, Country. ' +
            'State must be a 2-letter US state abbreviation (e.g. CA, TX, NY). ' +
            'Return {} if no address is found. Return PURE JSON only — no markdown, no explanation.';

        String userPrompt = 'Parse the address from this email body:\n' + emailBody;

        String model = String.isBlank(uiCfg.EmailToLead_Ai__Model__c) ? 'gpt-5.4-mini' : uiCfg.EmailToLead_Ai__Model__c;
        String reqBody;

        if (model.toLowerCase().contains('gpt')) {
            ChatGPTWrapperClass chatReq = new ChatGPTWrapperClass();
            chatReq.model  = model;
            chatReq.input  = systemPrompt + '\n\n' + userPrompt;
            chatReq.store  = false;
            reqBody = JSON.serialize(chatReq);
        } else if (model.toLowerCase().contains('gemini')) {
            GeminiWrapperClass gemReq = new GeminiWrapperClass();
            gemReq.setSystemInstruction(systemPrompt);
            gemReq.addUserMessage(userPrompt);
            reqBody = JSON.serialize(gemReq);
        } else {
            zApiWrapperClass reqObj = new zApiWrapperClass();
            reqObj.model    = model;
            reqObj.messages = new List<zApiWrapperClass.Message>{
                new zApiWrapperClass.Message('system', systemPrompt),
                new zApiWrapperClass.Message('user',   userPrompt)
            };
            reqBody = JSON.serialize(reqObj);
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        req.setEndpoint('callout:' + uiCfg.EmailToLead_Ai__Named_Credential__c);
        req.setBody(reqBody);

        HttpResponse res = new Http().send(req);
        System.debug('### AddressRepair HTTP status: ' + res.getStatusCode());
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            System.debug('### AddressRepair callout failed. Response body: ' + res.getBody());
            return null;
        }

        EmailToLead_Ai__Ai_Configs__c cs = EmailToLead_Ai__Ai_Configs__c.getValues(model);
        String responsePath = (cs != null && !String.isBlank(cs.EmailToLead_Ai__Response_Content_Path__c))
            ? cs.EmailToLead_Ai__Response_Content_Path__c
            : (model.toLowerCase().contains('gpt') ? 'output[0].content[0].text' : 'choices[0].message.content');

        System.debug('### AddressRepair responsePath: ' + responsePath);

        String aiText;
        try {
            aiText = extractContentByPath(res.getBody(), responsePath);
        } catch (Exception e) {
            System.debug('### AddressRepair extractContentByPath failed: ' + e.getMessage() + ' | Raw body: ' + res.getBody());
            return null;
        }

        System.debug('### AddressRepair aiText: ' + aiText);
        if (String.isBlank(aiText)) {
            System.debug('### AddressRepair aiText is blank — skipping.');
            return null;
        }

        try {
            String trimmed = aiText.trim();
            Integer start   = trimmed.indexOf('{');
            Integer lastIdx = trimmed.lastIndexOf('}');
            if (start < 0 || lastIdx <= start) {
                System.debug('### AddressRepair no JSON object found in aiText: ' + aiText);
                return null;
            }

            Map<String, Object> rawMap = (Map<String, Object>) JSON.deserializeUntyped(trimmed.substring(start, lastIdx + 1));
            if (rawMap.isEmpty()) {
                System.debug('### AddressRepair AI returned empty JSON {}');
                return null;
            }

            Map<String, String> keyNorm = new Map<String, String>{
                'street' => 'Street', 'city' => 'City', 'state' => 'State',
                'postalcode' => 'PostalCode', 'country' => 'Country'
            };
            Map<String, String> result = new Map<String, String>();
            for (String key : rawMap.keySet()) {
                String canonical = keyNorm.containsKey(key.toLowerCase()) ? keyNorm.get(key.toLowerCase()) : key;
                result.put(canonical, rawMap.get(key) != null ? String.valueOf(rawMap.get(key)) : '');
            }
            System.debug('### AddressRepair parsed result: ' + result);
            return result;
        } catch (Exception e) {
            System.debug('### AddressRepair JSON parse failed: ' + e.getMessage() + ' | aiText: ' + aiText);
            return null;
        }
    }

    private static String extractContentByPath(String jsonStr, String path) {
        Object current = JSON.deserializeUntyped(jsonStr);
        for (String token : path.split('\\.')) {
            if (token.contains('[')) {
                String key = token.substringBefore('[');
                Integer idx = Integer.valueOf(token.substringBetween('[', ']'));
                Object child = ((Map<String, Object>) current).get(key);
                if (child == null) throw new CalloutException('Path not found: ' + path);
                current = ((List<Object>) child)[idx];
            } else {
                current = ((Map<String, Object>) current).get(token);
            }
            if (current == null) throw new CalloutException('Path not found: ' + path);
        }
        return String.valueOf(current);
    }
}
