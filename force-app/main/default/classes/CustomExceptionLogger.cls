global class CustomExceptionLogger {

    // -------------------------------------------------------------------------
    // METHOD 1: Use this inside catch(Exception ex)
    // -------------------------------------------------------------------------
    global static void logException(
        Exception ex,
        String className,
        String typeValue,
        String errorRecordId,
        Id leadId,
        String requestJSON,
        String responseJSON
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c log =
                new EmailToLead_Ai__Custom_Exception__c();

            log.Name = 'Exception - ' + Datetime.now().format();
            log.EmailToLead_Ai__Class_Name__c = className;
            log.EmailToLead_Ai__Exception_message__c = ex.getMessage();
            log.EmailToLead_Ai__Type__c = typeValue;
            log.EmailToLead_Ai__Error_RecordId__c = errorRecordId;
            log.EmailToLead_Ai__RequestJSON__c = requestJSON;
            log.EmailToLead_Ai__ResponseJSON__c = responseJSON;

            if (leadId != null) {
                log.EmailToLead_Ai__Lead__c = leadId;
            }

            // Extract line number from Apex stack trace
            String stack = ex.getStackTraceString();
            Integer lineNum = extractLineNumber(stack);
            log.EmailToLead_Ai__Line_Number__c = lineNum;

            insert log;

        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE ERROR LOG: ' + innerEx.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // METHOD 2: Use this for SUCCESS LOGGING (No Exception)
    // -------------------------------------------------------------------------
    global static void logSuccess(
        String message,
        String className,
        String typeValue,
        Id leadId,
        String requestJSON,
        String responseJSON
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c log =
                new EmailToLead_Ai__Custom_Exception__c();

            log.Name = 'Success - ' + Datetime.now().format();
            log.EmailToLead_Ai__Class_Name__c = className;
            log.EmailToLead_Ai__Exception_message__c = message;
            log.EmailToLead_Ai__Type__c = typeValue;
            log.EmailToLead_Ai__RequestJSON__c = requestJSON;
            log.EmailToLead_Ai__ResponseJSON__c = responseJSON;

            // In success logs → no line number, no error record
            log.EmailToLead_Ai__Line_Number__c = null;
            log.EmailToLead_Ai__Error_RecordId__c = null;

            if (leadId != null) {
                log.EmailToLead_Ai__Lead__c = leadId;
            }

            insert log;

        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE SUCCESS LOG: ' + innerEx.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // Helper: Extract first line number from stack trace
    // -------------------------------------------------------------------------
    private static Integer extractLineNumber(String stackTrace) {
        try {
            Pattern p = Pattern.compile('line (\\d+)');
            Matcher m = p.matcher(stackTrace);

            if (m.find()) {
                return Integer.valueOf(m.group(1));
            }

        } catch (Exception e) {
            System.debug('### ERROR extracting line number: ' + e.getMessage());
        }
        return null;
    }
}