// Check all exception records with details
List<EmailToLead_Ai__Custom_Exception__c> recs = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Next_Retry_Time__c, EmailToLead_Ai__Class_Name__c,
           EmailToLead_Ai__Exception_message__c, CreatedDate
    FROM EmailToLead_Ai__Custom_Exception__c
    ORDER BY CreatedDate DESC
    LIMIT 20
];
for (EmailToLead_Ai__Custom_Exception__c r : recs) {
    String msg = r.EmailToLead_Ai__Exception_message__c;
    if (msg != null && msg.length() > 100) msg = msg.substring(0, 100) + '...';
    System.debug('Name=' + r.Name
        + ' | Status=' + r.EmailToLead_Ai__Retry_Status__c
        + ' | Count=' + r.EmailToLead_Ai__Retry_Count__c
        + ' | NextRetry=' + r.EmailToLead_Ai__Next_Retry_Time__c
        + ' | Created=' + r.CreatedDate
        + ' | Msg=' + msg);
}

// Check scheduler
List<CronTrigger> cts = [
    SELECT Id, State, NextFireTime, CronExpression
    FROM CronTrigger
    WHERE CronJobDetail.Name = 'EmailToLeadRetryScheduler'
];
for (CronTrigger ct : cts) {
    System.debug('Scheduler State=' + ct.State + ' | NextFire=' + ct.NextFireTime + ' | Cron=' + ct.CronExpression);
}
if (cts.isEmpty()) {
    System.debug('NO SCHEDULER FOUND');
}
