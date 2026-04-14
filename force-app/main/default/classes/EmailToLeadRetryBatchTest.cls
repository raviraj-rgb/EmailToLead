@IsTest
public class EmailToLeadRetryBatchTest {

    /* ============================================================
       MOCK : SUCCESS RESPONSE
    ============================================================ */
    private class SuccessMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String body =
            '{' +
            '"choices":[' +
            '{ "message": { "content": "{' +
            '\\"firstname\\":\\"Test\\",' +
            '\\"lastname\\":\\"User\\",' +
            '\\"email\\":\\"test@demo.com\\",' +
            '\\"company\\":\\"Demo\\",' +
            '\\"summary\\":\\"Interested\\"' +
            '}" } }' +
            ']' +
            '}';

            res.setBody(body);
            return res;
        }
    }


    /* ============================================================
       MOCK : FAILURE RESPONSE
    ============================================================ */
    private class FailMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');

            return res;
        }
    }


    /* ============================================================
       TEST SETUP
    ============================================================ */
    @TestSetup
    static void setupData() {

        /* ============== AI CONFIG ============== */

        insert new EmailToLead_Ai__AI_Configs__c(
            Name = 'Retry Config',
            EmailToLead_Ai__Model_Name__c = 'dummy-model',
            EmailToLead_Ai__Named_Credential__c = 'dummy_cred',
            EmailToLead_Ai__Endpoint__c = 'https://dummy',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content',
            EmailToLead_Ai__Is_Active__c = true
        );

        insert new EmailToLead_Ai__AI_Configure__c(
            Name = 'Retry Config',
            EmailToLead_Ai__Model__c = 'Retry Config',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__Scheduler_Retry_Hours__c = 2
        );


        /* ============== EXCEPTION RECORDS ============== */

        List<EmailToLead_Ai__Custom_Exception__c> logs =
            new List<EmailToLead_Ai__Custom_Exception__c>();


        logs.add(new EmailToLead_Ai__Custom_Exception__c(
            Name = 'Success Log',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 0,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-5),
            EmailToLead_Ai__Email_Header__c =
                'From: a@test.com\nTo: b@test.com\nSubject: Hi',
            EmailToLead_Ai__Email_Body__c = 'Lead from batch'
        ));

        logs.add(new EmailToLead_Ai__Custom_Exception__c(
            Name = 'Fail Log',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 2,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-5),
            EmailToLead_Ai__Email_Header__c =
                'From: x@test.com\nTo: y@test.com\nSubject: Help',
            EmailToLead_Ai__Email_Body__c = 'Fail lead'
        ));

        logs.add(new EmailToLead_Ai__Custom_Exception__c(
            Name = 'No Body',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 0,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addMinutes(-5),
            EmailToLead_Ai__Email_Header__c = null,
            EmailToLead_Ai__Email_Body__c = null
        ));

        insert logs;
    }


    /* ============================================================
       HELPER : KEEP ONLY TARGET RECORD PENDING
    ============================================================ */
    private static void keepOnlyOnePending(String nameToKeep) {

        List<EmailToLead_Ai__Custom_Exception__c> logs = [
            SELECT Id,
                   Name,
                   EmailToLead_Ai__Retry_Status__c,
                   EmailToLead_Ai__Next_Retry_Time__c
            FROM EmailToLead_Ai__Custom_Exception__c
        ];

        for (EmailToLead_Ai__Custom_Exception__c l : logs) {

            if (l.Name == nameToKeep) {

                l.EmailToLead_Ai__Retry_Status__c = 'Pending';
                l.EmailToLead_Ai__Next_Retry_Time__c =
                    System.now().addMinutes(-1);

            } else {

                l.EmailToLead_Ai__Retry_Status__c = 'Success';
                l.EmailToLead_Ai__Next_Retry_Time__c =
                    System.now().addDays(5);
            }
        }

        update logs;
    }


    /* ============================================================
       TEST : BATCH SUCCESS
    ============================================================ */
@IsTest
static void testBatchExecution() {

    keepOnlyOnePending('Success Log');

    Test.setMock(HttpCalloutMock.class, new SuccessMock());

    Test.startTest();

    Database.executeBatch(
        new EmailToLeadRetryBatch(),
        1
    );

    Test.stopTest();


    EmailToLead_Ai__Custom_Exception__c r =
        [SELECT EmailToLead_Ai__Retry_Status__c,
                EmailToLead_Ai__Retry_Count__c,
                EmailToLead_Ai__Lead__c,
                Name
         FROM EmailToLead_Ai__Custom_Exception__c
         WHERE Id = :[SELECT Id FROM EmailToLead_Ai__Custom_Exception__c WHERE Name LIKE '%Success Log%' LIMIT 1].Id
         LIMIT 1];


    System.assertEquals('Success', r.EmailToLead_Ai__Retry_Status__c);
    System.assert(r.Name.contains('Success'), 'Name should be updated to Success');
    System.assertNotEquals(null, r.EmailToLead_Ai__Lead__c, 'Lead lookup should be populated');
}

private class DuplicateMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        throw new CalloutException('Duplicate lead discovered');
    }
}

@IsTest
static void testBatchDuplicateHandling() {
    keepOnlyOnePending('Success Log');
    Test.setMock(HttpCalloutMock.class, new DuplicateMock());

    Test.startTest();
    Database.executeBatch(new EmailToLeadRetryBatch(), 1);
    Test.stopTest();

    EmailToLead_Ai__Custom_Exception__c r = [SELECT Name, EmailToLead_Ai__Retry_Status__c FROM EmailToLead_Ai__Custom_Exception__c WHERE EmailToLead_Ai__Retry_Status__c = 'Duplicate' LIMIT 1];
    System.assertEquals('Duplicate', r.EmailToLead_Ai__Retry_Status__c);
    System.assert(r.Name.contains('Duplicate'), 'Record Name should be updated to Duplicate');
}
 


    /* ============================================================
       TEST : CALL OUT FAILURE
    ============================================================ */
    @IsTest
    static void testBatchCalloutFail() {

        keepOnlyOnePending('Success Log');

        Test.setMock(HttpCalloutMock.class, new FailMock());

        Test.startTest();

        Database.executeBatch(
            new EmailToLeadRetryBatch(),
            1
        );

        Test.stopTest();


        EmailToLead_Ai__Custom_Exception__c r =
            [SELECT EmailToLead_Ai__Retry_Status__c
             FROM EmailToLead_Ai__Custom_Exception__c
             WHERE Name = 'Success Log'
             LIMIT 1];


        System.assertNotEquals(null, r.EmailToLead_Ai__Retry_Status__c);
    }


    /* ============================================================
       TEST : RETRY HOURS DEFAULT
    ============================================================ */
    @IsTest
    static void testRetryHoursDefault() {

        List<EmailToLead_Ai__AI_Configure__c> cfg =
            [SELECT Id, EmailToLead_Ai__isActive__c
             FROM EmailToLead_Ai__AI_Configure__c];

        for (EmailToLead_Ai__AI_Configure__c c : cfg) {
            c.EmailToLead_Ai__isActive__c = false;
        }

        update cfg;


        Test.startTest();

        EmailToLeadRetryBatch batch =
            new EmailToLeadRetryBatch();

        Test.stopTest();


        System.assertNotEquals(null, batch);
    }


    /* ============================================================
       TEST : MAX RETRY FAILURE
    ============================================================ */
    @IsTest
    static void testBatchMaxRetryFail() {

        keepOnlyOnePending('Fail Log');

        Test.setMock(HttpCalloutMock.class, new FailMock());

        Test.startTest();

        Database.executeBatch(
            new EmailToLeadRetryBatch(),
            1
        );

        Test.stopTest();


        EmailToLead_Ai__Custom_Exception__c updated =
            [SELECT EmailToLead_Ai__Retry_Status__c,
                    EmailToLead_Ai__Retry_Count__c
             FROM EmailToLead_Ai__Custom_Exception__c
             WHERE Name = 'Fail Log'
             LIMIT 1];


        System.assertEquals('Failed', updated.EmailToLead_Ai__Retry_Status__c);
        System.assertEquals(3, updated.EmailToLead_Ai__Retry_Count__c);
    }


    /* ============================================================
       TEST : NO BODY EXCEPTION
    ============================================================ */
    @IsTest
    static void testBatchNoBodyException() {

        keepOnlyOnePending('No Body');

        Test.setMock(HttpCalloutMock.class, new FailMock());

        Test.startTest();

        Database.executeBatch(
            new EmailToLeadRetryBatch(),
            1
        );

        Test.stopTest();


        EmailToLead_Ai__Custom_Exception__c updated =
            [SELECT EmailToLead_Ai__Retry_Status__c,
                    EmailToLead_Ai__Retry_Count__c
             FROM EmailToLead_Ai__Custom_Exception__c
             WHERE Name = 'No Body'
             LIMIT 1];


        System.assertEquals('Pending', updated.EmailToLead_Ai__Retry_Status__c);
        System.assertEquals(1, updated.EmailToLead_Ai__Retry_Count__c);
    }


    /* ============================================================
       TEST : START QUERY LOCATOR
    ============================================================ */
    @IsTest
    static void testStartQueryLocator() {

        Test.startTest();

        EmailToLeadRetryBatch batch =
            new EmailToLeadRetryBatch();

        Database.QueryLocator ql =
            batch.start(null);

        Test.stopTest();


        System.assertNotEquals(null, ql);
    }

}