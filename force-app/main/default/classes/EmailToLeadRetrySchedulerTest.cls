@isTest
private class EmailToLeadRetrySchedulerTest {

    @isTest
    static void testExecute() {
        EmailToLeadRetryScheduler scheduler = new EmailToLeadRetryScheduler();

        Test.startTest();
        // Schedule the job
        String jobId = System.schedule(
            'Test EmailToLeadRetryScheduler',
            '0 0 0 1 1 ? 2099',
            scheduler
        );
        
        // Verify job exists before Test.stopTest runs it
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId], 'Job should be scheduled');
        Test.stopTest();
        
        // After stopTest, the job executes and aborts itself, but schedules a new one.
        // We verify that the sequence continues.
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'EmailToLeadRetryScheduler%'], 'A new job should have been scheduled after execution');
    }

    @isTest
    static void testScheduleHourly() {
        Test.startTest();
        EmailToLeadRetryScheduler.scheduleHourly();
        Test.stopTest();

        // Verify recurring hourly job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'EmailToLeadRetryScheduler%'
        ];

        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
    }

    @isTest
    static void testScheduleHourlyReplacesExistingJob() {
        // First schedule
        EmailToLeadRetryScheduler.scheduleHourly();

        Test.startTest();
        // Schedule again - should abort existing and create new
        EmailToLeadRetryScheduler.scheduleHourly();
        Test.stopTest();

        // Should only have one job
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'EmailToLeadRetryScheduler%'
        ];

        System.assertEquals(1, jobs.size(), 'Should only have one scheduled job');
    }
}
