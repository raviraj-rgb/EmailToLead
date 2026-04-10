List<EmailToLead_Ai__Custom_Exception__c> pending = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c, EmailToLead_Ai__Type__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    ORDER BY CreatedDate ASC
];

System.debug('Total Pending records: ' + pending.size());
for (EmailToLead_Ai__Custom_Exception__c r : pending) {
    System.debug('  ' + r.Name + ' | RetryCount=' + r.EmailToLead_Ai__Retry_Count__c + ' | NextRetry=' + r.EmailToLead_Ai__Next_Retry_Time__c + ' | Type=' + r.EmailToLead_Ai__Type__c);
}
