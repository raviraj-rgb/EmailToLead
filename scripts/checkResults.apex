// Check batch job status
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CompletedDate
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'EmailToLeadRetryBatch'
    ORDER BY CreatedDate DESC
    LIMIT 1
];
for (AsyncApexJob j : jobs) {
    System.debug('Batch Status=' + j.Status + ' | Processed=' + j.JobItemsProcessed + '/' + j.TotalJobItems + ' | Errors=' + j.NumberOfErrors);
}

// Check record statuses
Integer pending = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'];
Integer success = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Success'];
Integer failed = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Failed'];
System.debug('Pending=' + pending + ' | Success=' + success + ' | Failed=' + failed);

// Check leads created
Integer leads = [SELECT COUNT() FROM Lead];
System.debug('Total Leads: ' + leads);
