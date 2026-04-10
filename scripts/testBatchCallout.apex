// Simulate exactly what the batch does
EmailToLead_Ai__Custom_Exception__c logRec = [
    SELECT Id, EmailToLead_Ai__Email_Header__c, EmailToLead_Ai__Email_Body__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    LIMIT 1
];

System.debug('Email_Header__c length: ' + (logRec.EmailToLead_Ai__Email_Header__c != null ? logRec.EmailToLead_Ai__Email_Header__c.length() : 0));
System.debug('Email_Header__c (first 300): ' + (logRec.EmailToLead_Ai__Email_Header__c != null ? logRec.EmailToLead_Ai__Email_Header__c.substring(0, Math.min(300, logRec.EmailToLead_Ai__Email_Header__c.length())) : 'NULL'));

// Simulate the batch: create InboundEmail from header, call handleInboundEmail
Messaging.InboundEmail inbound = new Messaging.InboundEmail();
inbound.plainTextBody = logRec.EmailToLead_Ai__Email_Header__c;

Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

EmailToLeadService.isRetryContext = true;
try {
    EmailToLeadService svc = new EmailToLeadService();
    Messaging.InboundEmailResult res = svc.handleInboundEmail(inbound, env);
    System.debug('Result success: ' + res.success);
    System.debug('Result message: ' + res.message);
} catch (Exception ex) {
    System.debug('EXCEPTION: ' + ex.getMessage());
    System.debug('TYPE: ' + ex.getTypeName());
    System.debug('STACK: ' + ex.getStackTraceString());
} finally {
    EmailToLeadService.isRetryContext = false;
}
