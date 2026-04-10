global class EmailToLeadRetryScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        // Prevent concurrent batch runs
        Integer running = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'EmailToLeadRetryBatch'
            AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
        ];
        if (running == 0) {
            Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        }
    }

    // Ensures a recurring hourly scheduler is active.
    // Safe to call multiple times — aborts any existing job first.
    global static void scheduleHourly() {

        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'EmailToLeadRetryScheduler'
        ]) {
            System.abortJob(ct.Id);
        }

        // Recurring hourly cron — runs at minute 0 of every hour
        System.schedule('EmailToLeadRetryScheduler', '0 0 * * * ?', new EmailToLeadRetryScheduler());
    }
}