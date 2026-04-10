// Delete old Custom Exception records (keep only last 50)
List<EmailToLead_Ai__Custom_Exception__c> oldRecords = [
    SELECT Id FROM EmailToLead_Ai__Custom_Exception__c
    ORDER BY CreatedDate DESC
    LIMIT 10000 OFFSET 50
];
if (!oldRecords.isEmpty()) {
    delete oldRecords;
    System.debug('Deleted ' + oldRecords.size() + ' old records');
}

Integer remaining = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c];
System.debug('Remaining records after cleanup: ' + remaining);
