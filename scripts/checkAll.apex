List<EmailToLead_Ai__Custom_Exception__c> all = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c, EmailToLead_Ai__Type__c
    FROM EmailToLead_Ai__Custom_Exception__c
    ORDER BY CreatedDate DESC
    LIMIT 50
];

System.debug('Total records: ' + all.size());
for (EmailToLead_Ai__Custom_Exception__c r : all) {
    System.debug(r.Name + ' | Status=' + r.EmailToLead_Ai__Retry_Status__c + ' | RetryCount=' + r.EmailToLead_Ai__Retry_Count__c + ' | NextRetry=' + r.EmailToLead_Ai__Next_Retry_Time__c + ' | Type=' + r.EmailToLead_Ai__Type__c);
}
