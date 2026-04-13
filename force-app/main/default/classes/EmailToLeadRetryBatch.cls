global class EmailToLeadRetryBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private static final Integer MAX_RETRY_COUNT = 3;
    private Integer retryHours = 1;
    private Integer successCount = 0;
    private Integer failureCount = 0;

    global EmailToLeadRetryBatch() {
        this.retryHours = getRetryHours();
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   EmailToLead_Ai__Retry_Status__c,
                   EmailToLead_Ai__Retry_Count__c,
                   EmailToLead_Ai__Next_Retry_Time__c,
                   EmailToLead_Ai__Email_Header__c,
                   EmailToLead_Ai__Email_Body__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
              AND EmailToLead_Ai__Next_Retry_Time__c <= :System.now()
              AND (EmailToLead_Ai__Retry_Count__c = null OR EmailToLead_Ai__Retry_Count__c < :MAX_RETRY_COUNT)
            ORDER BY CreatedDate ASC
            LIMIT 1
        ]);
    }

    global void execute(Database.BatchableContext bc, List<EmailToLead_Ai__Custom_Exception__c> scope) {
        
        // Batch size = 1, so scope has only 1 record
        // This allows callouts per batch execution (separate transaction)
        
        List<EmailToLead_Ai__Custom_Exception__c> toUpdate = new List<EmailToLead_Ai__Custom_Exception__c>();
        List<EmailToLead_Ai__Custom_Exception__c> successAuditLogs = new List<EmailToLead_Ai__Custom_Exception__c>();

        for (EmailToLead_Ai__Custom_Exception__c logRec : scope) {
            try {
                if (String.isBlank(logRec.EmailToLead_Ai__Email_Header__c)) {
                    throw new CalloutException('Missing Email data on Custom Exception record.');
                }

                Messaging.InboundEmail inbound = new Messaging.InboundEmail();
                inbound.plainTextBody = logRec.EmailToLead_Ai__Email_Header__c;

                Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

                // Make callout - each batch execution is separate transaction
                // Suppress duplicate exception logging — this batch manages retry state
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

                    logRec.EmailToLead_Ai__Retry_Status__c = 'Success';
                    logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    successCount++;

                    // Create success audit log
                    EmailToLead_Ai__Custom_Exception__c successLog = new EmailToLead_Ai__Custom_Exception__c();
                    successLog.Name = 'Success - Retry - ' + Datetime.now().format();
                    successLog.EmailToLead_Ai__Class_Name__c = 'EmailToLeadRetryBatch';
                    successLog.EmailToLead_Ai__Exception_message__c = 'Lead created successfully from batch retry.';
                    successLog.EmailToLead_Ai__Type__c = 'Success';
                    successLog.EmailToLead_Ai__Email_Header__c = logRec.EmailToLead_Ai__Email_Header__c;
                    successLog.EmailToLead_Ai__Email_Body__c = logRec.EmailToLead_Ai__Email_Body__c;
                    successLog.EmailToLead_Ai__Retry_Status__c = 'Success';
                    successLog.EmailToLead_Ai__Retry_Count__c = logRec.EmailToLead_Ai__Retry_Count__c;
                    successLog.EmailToLead_Ai__Next_Retry_Time__c = null;

                    successAuditLogs.add(successLog);

                } else {
                    String resMsg = (res != null && res.message != null) ? res.message : 'null result';

                    if (resMsg.containsIgnoreCase('duplicate')) {
                        // Existing lead — retrying will always produce same result
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Duplicate';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    } else if (resMsg.containsIgnoreCase('No leads created') ||
                               resMsg.containsIgnoreCase('AI returned no lead data') ||
                               resMsg.containsIgnoreCase('Empty AI response') ||
                               resMsg.containsIgnoreCase('No JSON')) {
                        // AI could not extract any usable lead data — permanent failure,
                        // retrying the same email body will never produce a different result
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
                    } else {
                        // Transient error (API timeout, callout failure, etc.) — retry later
                        logRec.EmailToLead_Ai__Retry_Status__c = 'Pending';
                        logRec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addHours(retryHours);
                    }
                    logRec.EmailToLead_Ai__Exception_message__c = 'Retry #' + logRec.EmailToLead_Ai__Retry_Count__c + ' failed: ' + resMsg;
                    failureCount++;
                }

                // Mark as Failed after max retries
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
                } else {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Pending';
                    logRec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addHours(retryHours);
                }
                logRec.EmailToLead_Ai__Exception_message__c = 'Retry #' + logRec.EmailToLead_Ai__Retry_Count__c + ' exception: ' + ex.getMessage();

                if (logRec.EmailToLead_Ai__Retry_Count__c >= MAX_RETRY_COUNT && logRec.EmailToLead_Ai__Retry_Status__c != 'Duplicate') {
                    logRec.EmailToLead_Ai__Retry_Status__c = 'Failed';
                }

                failureCount++;
                toUpdate.add(logRec);
            }
        }

        // DML after callouts
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }

        if (!successAuditLogs.isEmpty()) {
            insert successAuditLogs;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('EmailToLeadRetryBatch completed. Success: ' + successCount + ', Failures: ' + failureCount);
    }

    private static Integer getRetryHours() {
        try {
            EmailToLead_Ai__AI_Configure__c cfg = [
                SELECT EmailToLead_Ai__Scheduler_Retry_Hours__c
                FROM EmailToLead_Ai__AI_Configure__c
                WHERE EmailToLead_Ai__isActive__c = true
                LIMIT 1
            ];

            if (cfg != null && cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c != null) {
                Integer h = Integer.valueOf(cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c);
                return (h <= 0 ? 1 : h);
            }
        } catch (Exception ex) { }
        return 1;
    }

}