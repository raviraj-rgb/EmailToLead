// Test calling handleInboundEmail directly from anonymous Apex
// This runs OUTSIDE the managed package namespace
EmailToLead_Ai__Custom_Exception__c logRec = [
    SELECT Id, EmailToLead_Ai__Email_Header__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    LIMIT 1
];

Messaging.InboundEmail inbound = new Messaging.InboundEmail();
inbound.plainTextBody = logRec.EmailToLead_Ai__Email_Header__c;
Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

EmailToLeadService svc = new EmailToLeadService();
EmailToLeadService.isRetryContext = true;
try {
    Messaging.InboundEmailResult res = svc.handleInboundEmail(inbound, env);
    System.debug('SUCCESS=' + res.success + ' | MSG=' + res.message);
} catch (Exception ex) {
    System.debug('ERROR: ' + ex.getMessage());
} finally {
    EmailToLeadService.isRetryContext = false;
}
