global class EmailToLeadRetryScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        // 1. Core Logic: Check for running batch and start if not active
        Integer running = [
            SELECT COUNT() FROM AsyncApexJob
            WHERE ApexClass.Name = 'EmailToLeadRetryBatch'
            AND Status IN ('Holding', 'Queued', 'Preparing', 'Processing')
        ];
        if (running == 0) {
            Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        }

        // 2. Self-Scheduling: Schedule the next run for 20 minutes from now
        DateTime nextRun = DateTime.now().addMinutes(20);
        String cron = nextRun.second() + ' ' + 
                      nextRun.minute() + ' ' + 
                      nextRun.hour() + ' ' + 
                      nextRun.day() + ' ' + 
                      nextRun.month() + ' ? ' + 
                      nextRun.year();

        // Use a unique name for the next run to avoid collisions
        System.schedule('EmailToLeadRetryScheduler_NextRun_' + nextRun.getTime(), cron, new EmailToLeadRetryScheduler());

        // 3. Cleanup: Abort the current job so only the next scheduled run appears in the list
        if (sc != null) {
            System.abortJob(sc.getTriggerId());
        }
    }

    // Ensures a recurring 20-minute cycle is started.
    // Safe to call multiple times — aborts any existing jobs from old or new naming patterns.
    global static void scheduleHourly() {
        
        // Cleanup any existing jobs with old or new naming patterns
        // We use a wildcard search in SOQL for jobs related to this class
        for (CronTrigger ct : [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'EmailToLeadRetryScheduler%'
        ]) {
            System.abortJob(ct.Id);
        }

        // Start the first job in the sequence: scheduled for 1 minute from now
        DateTime firstRun = DateTime.now().addMinutes(1);
        String cron = firstRun.second() + ' ' + 
                      firstRun.minute() + ' ' + 
                      firstRun.hour() + ' ' + 
                      firstRun.day() + ' ' + 
                      firstRun.month() + ' ? ' + 
                      firstRun.year();
                      
        System.schedule('EmailToLeadRetryScheduler_NextRun_' + firstRun.getTime(), cron, new EmailToLeadRetryScheduler());
    }
}