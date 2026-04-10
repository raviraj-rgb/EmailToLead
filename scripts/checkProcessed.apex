// Check records that were retried (RetryCount > 0)
List<EmailToLead_Ai__Custom_Exception__c> retried = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c, EmailToLead_Ai__Exception_message__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Count__c > 0
    ORDER BY EmailToLead_Ai__Retry_Count__c DESC
    LIMIT 10
];

System.debug('Records with RetryCount > 0: ' + retried.size());
for (EmailToLead_Ai__Custom_Exception__c r : retried) {
    System.debug(r.Name + ' | Status=' + r.EmailToLead_Ai__Retry_Status__c + ' | RetryCount=' + r.EmailToLead_Ai__Retry_Count__c + ' | NextRetry=' + r.EmailToLead_Ai__Next_Retry_Time__c);
    String msg = r.EmailToLead_Ai__Exception_message__c;
    if (msg != null && msg.length() > 200) msg = msg.substring(0, 200);
    System.debug('  Error: ' + msg);
}

// Also check for any new exception/success records created by the batch
List<EmailToLead_Ai__Custom_Exception__c> recent = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Type__c, CreatedDate
    FROM EmailToLead_Ai__Custom_Exception__c
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Most recent 5 records:');
for (EmailToLead_Ai__Custom_Exception__c r : recent) {
    System.debug('  ' + r.Name + ' | Status=' + r.EmailToLead_Ai__Retry_Status__c + ' | Type=' + r.EmailToLead_Ai__Type__c + ' | Created=' + r.CreatedDate);
}
