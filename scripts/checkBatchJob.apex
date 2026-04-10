// Check recent batch jobs
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
           CompletedDate, ExtendedStatus, CreatedDate
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'EmailToLeadRetryBatch'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
for (AsyncApexJob j : jobs) {
    System.debug('Job: Status=' + j.Status
        + ' | Processed=' + j.JobItemsProcessed + '/' + j.TotalJobItems
        + ' | Errors=' + j.NumberOfErrors
        + ' | ExtStatus=' + j.ExtendedStatus
        + ' | Created=' + j.CreatedDate
        + ' | Completed=' + j.CompletedDate);
}
