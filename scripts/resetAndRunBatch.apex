// Reset the pending record's retry time so batch picks it up
List<EmailToLead_Ai__Custom_Exception__c> recs = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    LIMIT 1
];
if (!recs.isEmpty()) {
    recs[0].EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-1);
    recs[0].EmailToLead_Ai__Retry_Count__c = 0;
    update recs[0];
    System.debug('Reset record: ' + recs[0].Name + ' | Count=' + recs[0].EmailToLead_Ai__Retry_Count__c);
}

// Run batch
Database.executeBatch(new EmailToLeadRetryBatch(), 1);
System.debug('Batch launched');
