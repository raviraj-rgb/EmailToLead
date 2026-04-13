global class CustomExceptionLogger {

    // ---------------------------
    // Existing method (unchanged)
    // --------------------------- 
    global static void logException(
        Exception ex,
        String className,
        String typeValue,
        Id errorRecordId,
        Id leadId,
        String requestJSON,
        String responseJSON,
        String emailHeader,
        String emailBody
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c logRec =
                new EmailToLead_Ai__Custom_Exception__c();

            logRec.Name = 'Exception - ' + Datetime.now().format();
            logRec.EmailToLead_Ai__Class_Name__c = className;
            String msg = (ex != null ? ex.getMessage() : 'Unknown Exception');
            if (ex != null) {
                msg += '\nType: ' + ex.getTypeName()
                     + '\nLine: ' + ex.getLineNumber();

                String stack = ex.getStackTraceString();
                if (String.isNotBlank(stack)) {
                    msg += '\n\n--- Stack Trace ---\n' + stack;
                }

                Exception cause = ex.getCause();
                while (cause != null) {
                    msg += '\n\n--- Caused By ---\n'
                         + cause.getTypeName() + ': ' + cause.getMessage()
                         + '\nLine: ' + cause.getLineNumber();
                    String causeStack = cause.getStackTraceString();
                    if (String.isNotBlank(causeStack)) {
                        msg += '\n' + causeStack;
                    }
                    cause = cause.getCause();
                }
            }
            logRec.EmailToLead_Ai__Exception_message__c = truncate(msg, 32768);
            logRec.EmailToLead_Ai__Type__c = typeValue;

            logRec.EmailToLead_Ai__Error_RecordId__c =
                (errorRecordId == null ? null : String.valueOf(errorRecordId));

            logRec.EmailToLead_Ai__RequestJSON__c  = truncate(requestJSON,  32768);
            logRec.EmailToLead_Ai__ResponseJSON__c = truncate(stripThoughtSignature(responseJSON), 32768);

            if (leadId != null) {
                logRec.EmailToLead_Ai__Lead__c = leadId;
            }

            // Email_Header__c is used by the Retry Batch to re-process the email.
            // It must NEVER be truncated — a partial email body produces wrong leads on retry.
            if (String.isNotBlank(emailHeader)) {
                logRec.EmailToLead_Ai__Email_Header__c = emailHeader;
            }

            // Email_Body__c is for display/reference only — kept intact.
            if (String.isNotBlank(emailBody)) {
                logRec.EmailToLead_Ai__Email_Body__c = emailBody;
            }

            // Retry fields for scheduler (only for failed/error logs)
            logRec.EmailToLead_Ai__Retry_Status__c = 'Pending';
            logRec.EmailToLead_Ai__Retry_Count__c = 0;

            Integer retryHours = getRetryHours();
            logRec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addHours(retryHours);

            String stack = (ex != null ? ex.getStackTraceString() : null);
            Integer lineNum = extractLineNumber(stack);
            logRec.EmailToLead_Ai__Line_Number__c = lineNum;

            insert logRec;

        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE ERROR LOG: ' + innerEx.getMessage());
        }
    }

    global static void logSuccess(
        String message,
        String className,
        String typeValue,
        Id leadId,
        String requestJSON,
        String responseJSON
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c logRec =
                new EmailToLead_Ai__Custom_Exception__c();

            logRec.Name = 'Success - ' + Datetime.now().format();
            logRec.EmailToLead_Ai__Class_Name__c = className;
            logRec.EmailToLead_Ai__Exception_message__c = truncate(message, 32768);
            logRec.EmailToLead_Ai__Type__c = typeValue;

            logRec.EmailToLead_Ai__RequestJSON__c  = truncate(requestJSON,  32768);
            logRec.EmailToLead_Ai__ResponseJSON__c = truncate(stripThoughtSignature(responseJSON), 32768);

            logRec.EmailToLead_Ai__Line_Number__c = null;
            logRec.EmailToLead_Ai__Error_RecordId__c = null;

            if (leadId != null) {
                logRec.EmailToLead_Ai__Lead__c = leadId;
            }

            logRec.EmailToLead_Ai__Retry_Status__c = 'Success';
            logRec.EmailToLead_Ai__Retry_Count__c = null;
            logRec.EmailToLead_Ai__Next_Retry_Time__c = null;

            insert logRec;

        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE SUCCESS LOG: ' + innerEx.getMessage());
        }
    }

    // ============================================================
    //  NEW METHOD: Log Duplicate (Retry_Status = Duplicate)
    // ============================================================
    global static void logDuplicate(
        Exception ex,
        String className,
        Id existingLeadId,
        String requestJSON,
        String responseJSON,
        String emailHeader,
        String emailBody,
        String cleanedBody
    ) {
        try {
            EmailToLead_Ai__Custom_Exception__c logRec =
                new EmailToLead_Ai__Custom_Exception__c();

            logRec.Name = 'Duplicate - ' + Datetime.now().format();
            logRec.EmailToLead_Ai__Class_Name__c = className;

            String msg = (ex != null ? ex.getMessage() : 'Duplicate detected.');
            if (existingLeadId != null) {
                msg += ' | Existing LeadId: ' + existingLeadId;
                logRec.EmailToLead_Ai__Lead__c = existingLeadId;
            }

            if (ex != null) {
                String stack = ex.getStackTraceString();
                if (String.isNotBlank(stack)) {
                    msg += '\n\n--- Stack Trace ---\n' + stack;
                }
            }

            logRec.EmailToLead_Ai__Exception_message__c = truncate(msg, 32768);
            logRec.EmailToLead_Ai__Type__c = 'Duplicate';

            logRec.EmailToLead_Ai__RequestJSON__c  = truncate(requestJSON,  32768);
            logRec.EmailToLead_Ai__ResponseJSON__c = truncate(stripThoughtSignature(responseJSON), 32768);

            // Email_Header__c — kept intact (Retry Batch reads it to re-process email)
            if (String.isNotBlank(emailHeader)) {
                logRec.EmailToLead_Ai__Email_Header__c = emailHeader;
            }

            // Email_Body__c — kept intact (reference/display only)
            if (String.isNotBlank(emailBody)) {
                logRec.EmailToLead_Ai__Email_Body__c = emailBody;
            }

            // IMPORTANT: duplicate records should NOT be retried
            logRec.EmailToLead_Ai__Retry_Status__c = 'Duplicate';
            logRec.EmailToLead_Ai__Retry_Count__c = null;
            logRec.EmailToLead_Ai__Next_Retry_Time__c = null;
            logRec.EmailToLead_Ai__Line_Number__c = null;
            logRec.EmailToLead_Ai__Error_RecordId__c = null;

            insert logRec;

        } catch (Exception innerEx) {
            System.debug('### FAILED TO SAVE DUPLICATE LOG: ' + innerEx.getMessage());
        }
    }

    // ---------------------------
    // Helper methods
    // ---------------------------

    /**
     * Truncates a string to maxLen characters to prevent DML failures on Long Text Area fields.
     * Only used on DIAGNOSTIC fields (RequestJSON, ResponseJSON, Exception_message).
     * Never used on Email_Header__c which the Retry Batch needs to be complete.
     */
    private static String truncate(String val, Integer maxLen) {
        if (String.isBlank(val) || val.length() <= maxLen) return val;
        return val.substring(0, maxLen - 20) + '... [TRUNCATED]';
    }

    /**
     * Strips the 'thoughtSignature' field from a Gemini API response JSON.
     * This field is a large base64-encoded blob that is included in Gemini responses
     * when the model uses extended thinking. It is completely useless for debugging
     * and typically inflates the ResponseJSON by 90%+ (tens of thousands of characters).
     * Removing it makes the remaining JSON fit easily within field limits.
     */
    private static String stripThoughtSignature(String responseJson) {
        if (String.isBlank(responseJson)) return responseJson;
        // Regex: remove "thoughtSignature": "<base64_value>" including the comma if present
        return responseJson
            .replaceAll(',?\\s*"thoughtSignature"\\s*:\\s*"[^"]*"', '')
            .replaceAll('"thoughtSignature"\\s*:\\s*"[^"]*",?\\s*', '');
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

    private static Integer extractLineNumber(String stackTrace) {
        try {
            if (String.isBlank(stackTrace)) return null;

            Pattern p = Pattern.compile('line (\\d+)');
            Matcher m = p.matcher(stackTrace);
            if (m.find()) return Integer.valueOf(m.group(1));
        } catch (Exception e) {
            System.debug('### ERROR extracting line number: ' + e.getMessage());
        }
        return null;
    }
}