global class EmailToLeadRetryBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private static final Integer MAX_RETRY_COUNT = 1;
    private Integer successCount = 0;
    private Integer failureCount = 0;

    global EmailToLeadRetryBatch() {
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   EmailToLead_Ai__Retry_Status__c,
                   EmailToLead_Ai__Retry_Count__c,
                   EmailToLead_Ai__Next_Retry_Time__c,
                   EmailToLead_Ai__Email_Header__c,
                   EmailToLead_Ai__Email_Body__c,
                   EmailToLead_Ai__Lead__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
              AND EmailToLead_Ai__Next_Retry_Time__c <= :System.now()
              AND (EmailToLead_Ai__Retry_Count__c = null OR EmailToLead_Ai__Retry_Count__c <= :MAX_RETRY_COUNT)
            ORDER BY CreatedDate ASC
        ]);
    }

    global void execute(Database.BatchableContext bc, List<EmailToLead_Ai__Custom_Exception__c> scope) {
        
        List<EmailToLead_Ai__Custom_Exception__c> toUpdate = new List<EmailToLead_Ai__Custom_Exception__c>();

        for (EmailToLead_Ai__Custom_Exception__c logRec : scope) {
            
            // Increment retry count
            Integer currentCount = (logRec.EmailToLead_Ai__Retry_Count__c == null)
                ? 0
                : Integer.valueOf(logRec.EmailToLead_Ai__Retry_Count__c);
            
            Integer newCount = currentCount + 1;
            logRec.EmailToLead_Ai__Retry_Count__c = newCount;

            try {
                if (String.isBlank(logRec.EmailToLead_Ai__Email_Body__c)) {
                    throw new CalloutException('Missing Email Body data on Custom Exception record.');
                }

                Messaging.InboundEmail inbound = new Messaging.InboundEmail();
                inbound.plainTextBody = logRec.EmailToLead_Ai__Email_Body__c;

                // Recover the real envelope sender and subject from Email_Header__c.
                // New format: 'From: raviraj@untangleit.in | Subject: ...'
                // Old format (backward compat): just the subject string
                String hdr = logRec.EmailToLead_Ai__Email_Header__c;
                if (String.isNotBlank(hdr) && hdr.startsWith('From: ')) {
                    inbound.fromAddress = hdr.substringAfter('From: ').substringBefore(' | Subject: ').trim();
                    inbound.subject = hdr.substringAfter(' | Subject: ').trim();
                } else {
                    // Old logs: header only had the subject. Try to extract sender from the body's first From: line.
                    inbound.subject = String.isNotBlank(hdr) ? hdr : 'Retry Email';
                    if (String.isNotBlank(inbound.plainTextBody)) {
                        Pattern p = Pattern.compile('(?im)^From:\\s*[^\\n<]*<?([\\w.-]+@[\\w.-]+\\.[\\w]{2,})>?');
                        Matcher m = p.matcher(inbound.plainTextBody);
                        if (m.find()) inbound.fromAddress = m.group(1).trim();
                    }
                }
                
                Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

                EmailToLeadService.isRetryContext = true;
                EmailToLeadService svc = new EmailToLeadService();
                Messaging.InboundEmailResult res;
                try {
                    res = svc.handleInboundEmail(inbound, env);
                } finally {
                    EmailToLeadService.isRetryContext = false;
                }

                if (res != null) {
                    String resMsg = (res.message != null) ? res.message : '';
                    
                    if (res.success == true) {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Success';
                        
                        String plainMsg = 'Lead(s) created successfully.';
                        if (resMsg.contains(':')) {
                            String idsStr = resMsg.substringAfter(':').trim();
                            
                            // Link the Lead ID to the Exception (Salesforce UI shows this as a Name link)
                            if (String.isNotBlank(idsStr)) {
                                List<String> idList = idsStr.split(',');
                                String firstId = idList[0].trim();
                                if (firstId.length() >= 15) {
                                    logRec.EmailToLead_Ai__Lead__c = (Id)firstId;
                                    try {
                                        Lead newLead = [SELECT Name FROM Lead WHERE Id = :firstId LIMIT 1];
                                        plainMsg = 'Success! Created Lead: ' + newLead.Name;
                                    } catch (Exception e) {
                                        plainMsg = 'Success! Created Lead ID: ' + firstId;
                                    }
                                }
                            }
                        }

                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                        logRec.EmailToLead_Ai__Exception_message__c = plainMsg;
                        successCount++;

                    } else if (resMsg != null && resMsg.startsWith('Skipped')) {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Skipped';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                        logRec.EmailToLead_Ai__Exception_message__c = resMsg;
                        successCount++;

                    } else {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                        logRec.EmailToLead_Ai__Exception_message__c = 'Retry Attempt failed: ' + resMsg;
                        failureCount++;
                    }
                }

            } catch (Exception ex) {
                logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                logRec.EmailToLead_Ai__Exception_message__c = 'Retry Exception: ' + ex.getMessage();
                failureCount++;
            }
            toUpdate.add(logRec);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    private String generateLeadLinks(String leadIdsStr) {
        if (String.isBlank(leadIdsStr)) return '';
        List<String> ids = leadIdsStr.split(',');
        List<String> cleanIds = new List<String>();
        for (String s : ids) if (String.isNotBlank(s)) cleanIds.add(s.trim());
        if (cleanIds.isEmpty()) return '';
        Map<Id, Lead> leadMap = new Map<Id, Lead>([SELECT Id, Name FROM Lead WHERE Id IN :cleanIds]);
        List<String> links = new List<String>();
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        for (String idStr : cleanIds) {
            String nameLabel = leadMap.containsKey(idStr) ? leadMap.get(idStr).Name : 'View Lead';
            links.add('<a href="' + baseUrl + '/' + idStr + '" style="color: #0070d2; font-weight: bold;">' + nameLabel + '</a>');
        }
        return String.join(links, ' | ');
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('EmailToLeadRetryBatch completed. Success: ' + successCount + ', Failures: ' + failureCount);
    }

}