global class CustomExceptionLogger {

    // -------------------------------------------------------------------------
    // Helper: Truncate strings to avoid STRING_TOO_LONG errors (Salesforce limit 32,768)
    // -------------------------------------------------------------------------
    private static String safeTruncate(String val) {
        if (String.isBlank(val)) return val;
        return val.length() > 32700 ? val.substring(0, 32700) : val;
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

    // -------------------------------------------------------------------------
    // METHOD: Log SUCCESS
    // -------------------------------------------------------------------------
    global static void logSuccess(
        String message,
        String className,
        String typeValue,
        Id leadId,
        String requestJSON,
        String responseJSON,
        String emailHeader,
        String emailBody
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c log = new EmailToLead_Ai__Custom_Exception__c();
            log.Name = 'Success - ' + Datetime.now().format();
            log.EmailToLead_Ai__Class_Name__c = className;
            log.EmailToLead_Ai__Exception_message__c = safeTruncate(message);
            log.EmailToLead_Ai__Type__c = 'Success';
            log.EmailToLead_Ai__Retry_Status__c = 'Success';
            log.EmailToLead_Ai__RequestJSON__c = safeTruncate(requestJSON);
            log.EmailToLead_Ai__ResponseJSON__c = safeTruncate(responseJSON);
            log.EmailToLead_Ai__Lead__c = leadId;
            log.EmailToLead_Ai__Email_Header__c = safeTruncate(emailHeader);
            log.EmailToLead_Ai__Email_Body__c = safeTruncate(emailBody);
            insert log;
        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE SUCCESS LOG: ' + innerEx.getMessage());
        }
    }

    // Backward-compat overload (no email header/body)
    global static void logSuccess(String message, String className, String typeValue, Id leadId, String requestJSON, String responseJSON) {
        logSuccess(message, className, typeValue, leadId, requestJSON, responseJSON, null, null);
    }

    // -------------------------------------------------------------------------
    // METHOD: Log EXCEPTION
    // -------------------------------------------------------------------------
    global static void logException(
        Exception ex,
        String className,
        String typeValue,
        Id leadId,
        String emailHeader,
        String emailBody,
        String requestJSON,
        String responseJSON
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c log = new EmailToLead_Ai__Custom_Exception__c();
            log.Name = 'Exception - ' + Datetime.now().format();
            log.EmailToLead_Ai__Class_Name__c = className;
            log.EmailToLead_Ai__Exception_message__c = safeTruncate(ex != null ? ex.getMessage() : 'Unknown Exception');
            log.EmailToLead_Ai__Type__c = 'Exception';
            log.EmailToLead_Ai__Retry_Status__c = 'Pending';
            log.EmailToLead_Ai__Retry_Count__c = 1;
            log.EmailToLead_Ai__Next_Retry_Time__c = System.now();
            log.EmailToLead_Ai__Lead__c = leadId;
            log.EmailToLead_Ai__Email_Header__c = safeTruncate(emailHeader);
            log.EmailToLead_Ai__Email_Body__c = safeTruncate(emailBody);
            log.EmailToLead_Ai__RequestJSON__c = safeTruncate(requestJSON);
            log.EmailToLead_Ai__ResponseJSON__c = safeTruncate(responseJSON);
            
            if (ex != null) {
                log.EmailToLead_Ai__Line_Number__c = extractLineNumber(ex.getStackTraceString());
            }
            insert log;
        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE EXCEPTION LOG: ' + innerEx.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // METHOD: Log SKIPPED (e.g. Daily Summary)
    // -------------------------------------------------------------------------
    global static void logSkipped(
        String reason,
        String className,
        String emailHeader,
        String emailBody,
        String requestJSON,
        String responseJSON
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c log = new EmailToLead_Ai__Custom_Exception__c();
            log.Name = 'Skipped - ' + Datetime.now().format();
            log.EmailToLead_Ai__Class_Name__c = className;
            log.EmailToLead_Ai__Exception_message__c = safeTruncate(reason);
            log.EmailToLead_Ai__Type__c = 'Skipped';
            log.EmailToLead_Ai__Retry_Status__c = 'Skipped';
            log.EmailToLead_Ai__Email_Header__c = safeTruncate(emailHeader);
            log.EmailToLead_Ai__Email_Body__c = safeTruncate(emailBody);
            log.EmailToLead_Ai__RequestJSON__c = safeTruncate(requestJSON);
            log.EmailToLead_Ai__ResponseJSON__c = safeTruncate(responseJSON);
            insert log;
        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE SKIPPED LOG: ' + innerEx.getMessage());
        }
    }

    // Deprecated / Placeholder to prevent compilation errors if called elsewhere temporarily
    global static void logDuplicate(Exception ex, String className, Id leadId, String emailHeader, String emailBody, String requestJSON, String responseJSON, String info) {
        // User requested: "No Duplicate Record should get created"
        // We will just do nothing here to honor the request while maintaining method signature for now.
        System.debug('### DUPLICATE LOG SUPPRESSED BY USER REQUEST');
    }
    // Legacy support for old calls
    global static void logException(Exception ex, String className, String typeValue, String errorId, Id leadId, String req, String res) {
        logException(ex, className, typeValue, leadId, null, null, req, res);
    }
    
    global static void logException(Exception ex, String className, String typeValue, Id leadId, String header, String body, String req, String res, String retry) {
        logException(ex, className, typeValue, leadId, header, body, req, res);
    }

    // ⚠️ BACKWARD COMPATIBILITY — Do NOT remove. Was global in v0.3 of managed package.
    // logException with (Id errorRecordId, Id leadId) — old 9-param signature
    global static void logException(Exception ex, String className, String typeValue, Id errorRecordId, Id leadId, String header, String body, String req, String res) {
        logException(ex, className, typeValue, leadId, header, body, req, res);
    }

    // ⚠️ BACKWARD COMPATIBILITY — Do NOT remove. Was global in v0.3 of managed package.
    // logSkipped with 4 params — old signature
    global static void logSkipped(String reason, String className, String requestJSON, String responseJSON) {
        logSkipped(reason, className, null, null, requestJSON, responseJSON);
    }
}
//Gitting
