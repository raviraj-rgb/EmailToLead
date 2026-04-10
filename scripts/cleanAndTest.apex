// Step 1: Delete the 3 duplicate pending records (created by old bug)
List<EmailToLead_Ai__Custom_Exception__c> duplicates = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
      AND EmailToLead_Ai__Retry_Count__c = 0
];
System.debug('Deleting ' + duplicates.size() + ' duplicate pending records from old bug');
delete duplicates;

// Step 2: Reset the Failed record back to Pending for fresh test
List<EmailToLead_Ai__Custom_Exception__c> failed = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Failed'
    LIMIT 1
];
if (!failed.isEmpty()) {
    EmailToLead_Ai__Custom_Exception__c rec = failed[0];
    rec.EmailToLead_Ai__Retry_Status__c = 'Pending';
    rec.EmailToLead_Ai__Retry_Count__c = 0;
    rec.EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-1);
    update rec;
    System.debug('Reset record: ' + rec.Name + ' to Pending with past retry time');
} else {
    System.debug('No failed record to reset');
}

// Step 3: Verify counts
Integer pending = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'];
Integer success = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Success'];
Integer failedCount = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Failed'];
Integer total = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c];
System.debug('After cleanup => Pending=' + pending + ' | Success=' + success + ' | Failed=' + failedCount + ' | Total=' + total);
