@isTest
private class EmailToLeadRetrySchedulerTest {

    @isTest
    static void testExecute() {
        Test.startTest();

        EmailToLeadRetryScheduler scheduler = new EmailToLeadRetryScheduler();

        // Schedule the job
        String jobId = System.schedule(
            'Test EmailToLeadRetryScheduler',
            '0 0 0 1 1 ? 2099',
            scheduler
        );

        Test.stopTest();

        // Verify job was scheduled
        List<CronTrigger> jobs = [
            SELECT Id, CronExpression, State
            FROM CronTrigger
            WHERE Id = :jobId
        ];

        System.assertEquals(1, jobs.size(), 'Job should be scheduled');
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
            WHERE CronJobDetail.Name = 'EmailToLeadRetryScheduler'
        ];

        System.assertEquals(1, jobs.size(), 'Scheduled job should exist');
        System.assertEquals('0 0 * * * ?', jobs[0].CronExpression, 'Should be hourly cron');
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
            WHERE CronJobDetail.Name = 'EmailToLeadRetryScheduler'
        ];

        System.assertEquals(1, jobs.size(), 'Should only have one scheduled job');
    }
}
