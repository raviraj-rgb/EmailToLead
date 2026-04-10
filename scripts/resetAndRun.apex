// Reset Next_Retry_Time to past so batch picks it up now
List<EmailToLead_Ai__Custom_Exception__c> pending = [
    SELECT Id, EmailToLead_Ai__Next_Retry_Time__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    LIMIT 1
];

if (!pending.isEmpty()) {
    pending[0].EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-5);
    update pending;
    System.debug('Reset Next_Retry_Time to past for record: ' + pending[0].Id);
}

Database.executeBatch(new EmailToLeadRetryBatch(), 1);
System.debug('Batch launched');
