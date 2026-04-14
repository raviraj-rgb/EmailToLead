global class EmailToLeadRetryBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private static final Integer MAX_RETRY_COUNT = 2;
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
              AND (EmailToLead_Ai__Retry_Count__c = null OR EmailToLead_Ai__Retry_Count__c < :MAX_RETRY_COUNT)
            ORDER BY CreatedDate ASC
            LIMIT 1
        ]);
    }

    global void execute(Database.BatchableContext bc, List<EmailToLead_Ai__Custom_Exception__c> scope) {
        
        List<EmailToLead_Ai__Custom_Exception__c> toUpdate = new List<EmailToLead_Ai__Custom_Exception__c>();

        for (EmailToLead_Ai__Custom_Exception__c logRec : scope) {
            try {
                if (String.isBlank(logRec.EmailToLead_Ai__Email_Header__c)) {
                    throw new CalloutException('Missing Email data on Custom Exception record.');
                }

                Messaging.InboundEmail inbound = new Messaging.InboundEmail();
                inbound.plainTextBody = logRec.EmailToLead_Ai__Email_Header__c;
                Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

                EmailToLeadService.isRetryContext = true;
                EmailToLeadService svc = new EmailToLeadService();
                Messaging.InboundEmailResult res;
                try {
                    res = svc.handleInboundEmail(inbound, env);
                } finally {
                    EmailToLeadService.isRetryContext = false;
                }

                Integer retryCount = (logRec.EmailToLead_Ai__Retry_Count__c == null)
                    ? 0
                    : Integer.valueOf(logRec.EmailToLead_Ai__Retry_Count__c);
 
                logRec.EmailToLead_Ai__Retry_Count__c = retryCount + 1;

                if (res != null && res.success == true) {

                    logRec.Name = logRec.Name.replace('Exception', 'Success');
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Success';
                    logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    logRec.EmailToLead_Ai__Exception_message__c = 'Lead created successfully on Retry #' + logRec.EmailToLead_Ai__Retry_Count__c;
                    
                    // Capture the created Lead ID for the lookup field
                    if (EmailToLeadService.createdLeadIds != null && !EmailToLeadService.createdLeadIds.isEmpty()) {
                        logRec.EmailToLead_Ai__Lead__c = EmailToLeadService.createdLeadIds[0];
                    }
                    
                    successCount++;

                } else {
                    String resMsg = (res != null && res.message != null) ? res.message : 'null result';

                    if (resMsg.containsIgnoreCase('duplicate')) {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Duplicate';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                        logRec.Name = logRec.Name.replace('Exception', 'Duplicate');
                    } else if (resMsg.containsIgnoreCase('No leads created') ||
                               resMsg.containsIgnoreCase('AI returned no lead data') ||
                               resMsg.containsIgnoreCase('Empty AI response') ||
                               resMsg.containsIgnoreCase('No JSON')) {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    } else {
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Pending';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(20);
                    }
                    logRec.EmailToLead_Ai__Exception_message__c = 'Retry #' + logRec.EmailToLead_Ai__Retry_Count__c + ' failed: ' + resMsg;
                    failureCount++;
                }

                if (logRec.EmailToLead_Ai__Retry_Count__c >= MAX_RETRY_COUNT
                    && logRec.EmailToLead_Ai__Retry_Status__c != 'Success'
                    && logRec.EmailToLead_Ai__Retry_Status__c != 'Duplicate') {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                }

                toUpdate.add(logRec);

            } catch (Exception ex) {

                Integer retryCount = (logRec.EmailToLead_Ai__Retry_Count__c == null)
                    ? 0
                    : Integer.valueOf(logRec.EmailToLead_Ai__Retry_Count__c);

                logRec.EmailToLead_Ai__Retry_Count__c = retryCount + 1;
                if (ex.getMessage() != null && ex.getMessage().containsIgnoreCase('duplicate')) {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Duplicate';
                    logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    logRec.Name = logRec.Name.replace('Exception', 'Duplicate');
                } else {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Pending';
                    logRec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(20);
                }
                logRec.EmailToLead_Ai__Exception_message__c = 'Retry #' + logRec.EmailToLead_Ai__Retry_Count__c + ' exception: ' + ex.getMessage();

                if (logRec.EmailToLead_Ai__Retry_Count__c >= MAX_RETRY_COUNT && logRec.EmailToLead_Ai__Retry_Status__c != 'Duplicate') {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                }

                failureCount++;
                toUpdate.add(logRec);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('EmailToLeadRetryBatch completed. Success: ' + successCount + ', Failures: ' + failureCount);
    }

}