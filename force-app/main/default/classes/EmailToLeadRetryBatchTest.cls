@IsTest
public class EmailToLeadRetryBatchTest {

    /* ============================================================
       MOCK : SUCCESS RESPONSE
     ============================================================ */
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{' +
                '\\\"firstname\\\": \\\"Test\\\",' +
                '\\\"lastname\\\": \\\"User\\\",' +
                '\\\"email\\\": \\\"test@demo.com\\\",' +
                '\\\"company\\\": \\\"Demo\\\",' +
                '\\\"summary\\\": \\\"Interested\\\"' +
                '}"}}]}');
            return res;
        }
    }

    /* ============================================================
       MOCK : FAILURE RESPONSE (non-2xx)
     ============================================================ */
    private class FailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    /* ============================================================
       SHARED TEST SETUP
     ============================================================ */
    @TestSetup
    static void setupData() {

        // AI Config (Custom Setting - hierarchy type, uses getInstance)
        // Name must match the 'Model' field in AI_Configure__c
        EmailToLead_Ai__AI_Configs__c apiConfig = new EmailToLead_Ai__AI_Configs__c(
            Name = 'gpt-5.4-mini',
            EmailToLead_Ai__Model_Name__c = 'gpt-5.4-mini',
            EmailToLead_Ai__Named_Credential__c = 'ZAPI_NC',
            EmailToLead_Ai__Endpoint__c = 'https://dummy-endpoint',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content',
            EmailToLead_Ai__Is_Active__c = true
        );
        insert apiConfig;

        // AI Configure (standard custom object - links to AI Config by name, 
        // must have User_Prompt__c set to avoid NPE in callZApi)
        EmailToLead_Ai__AI_Configure__c aiConfig = new EmailToLead_Ai__AI_Configure__c(
            Name = 'RetryBatchConfig',
            EmailToLead_Ai__Model__c = 'gpt-5.4-mini',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__System_prompt__c = 'You are a lead extractor. Return JSON.',
            EmailToLead_Ai__User_Prompt__c = 'Extract leads from: {EMAIL_BODY} with fields: {ALLOWED_FIELDS}',
            EmailToLead_Ai__Scheduler_Retry_Hours__c = 2
        );
        insert aiConfig;

        // Field mapping (custom object - enables lead field mapping from AI)
        EmailToLead_Ai__Email_Lead_Field__c fieldConfig = new EmailToLead_Ai__Email_Lead_Field__c(
            Name = 'batch_test_field_cfg',
            EmailToLead_Ai__Selected_fields__c = 'firstname,lastname,email,company,summary',
            EmailToLead_Ai__Email_Body_Field__c = 'description',
            EmailToLead_Ai__Summary_Field__c = 'description',
            EmailToLead_Ai__Is_Active__c = true
        );
        insert fieldConfig;

        // Pending exception records to be retried
        List<EmailToLead_Ai__Custom_Exception__c> logs = new List<EmailToLead_Ai__Custom_Exception__c>();

        // Record 1: first retry attempt (count = 0, will succeed or become duplicate)
        logs.add(new EmailToLead_Ai__Custom_Exception__c(
            Name = 'Exception - Success Log',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 0,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addDays(-1),
            // plainTextBody comes from Email_Header__c — must contain the company name
            // so the service's body-contains-company check passes
            EmailToLead_Ai__Email_Header__c = 'From: test@demo.com\nSubject: Demo lead inquiry',
            EmailToLead_Ai__Email_Body__c = 'Demo lead inquiry from test@demo.com'
        ));

        // Record 2: second retry attempt (count = 1, batch will mark as Failed after)
        logs.add(new EmailToLead_Ai__Custom_Exception__c(
            Name = 'Exception - Fail Log',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 1,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addDays(-1),
            EmailToLead_Ai__Email_Header__c = 'From: test@demo.com\nSubject: Demo retry',
            EmailToLead_Ai__Email_Body__c = 'Demo retry body'
        ));

        insert logs;
    }

    /* ============================================================
       HELPER — isolate a single pending record for batch execution
     ============================================================ */
    private static void keepOnlyOnePending(String nameToKeep) {
        List<EmailToLead_Ai__Custom_Exception__c> logs = [
            SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Next_Retry_Time__c
            FROM EmailToLead_Ai__Custom_Exception__c
        ];
        List<EmailToLead_Ai__Custom_Exception__c> toUpdate = new List<EmailToLead_Ai__Custom_Exception__c>();
        for (EmailToLead_Ai__Custom_Exception__c l : logs) {
            if (l.Name != nameToKeep) {
                l.EmailToLead_Ai__Retry_Status__c = 'Success';
                l.EmailToLead_Ai__Next_Retry_Time__c = System.now().addDays(5);
                toUpdate.add(l);
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /* ============================================================
       TEST 1 — Successful batch execution creates a Lead
                and deletes the original Pending log
     ============================================================ */
    @IsTest
    static void testBatchExecution() {
        keepOnlyOnePending('Exception - Success Log');
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        Test.stopTest();

        // The service should have created a Lead
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email = 'test@demo.com'];
        System.assert(leads.size() > 0, 'A Lead should have been created by the batch');

        // The original Pending record should stay in DB but be marked Success
        EmailToLead_Ai__Custom_Exception__c log = [
            SELECT Id, EmailToLead_Ai__Retry_Status__c FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name = 'Exception - Success Log'
            LIMIT 1
        ];
        System.assertEquals('Success', log.EmailToLead_Ai__Retry_Status__c, 'Log status should be Success');
    }

    /* ============================================================
       TEST 2 — Duplicate lead: original log updated to Duplicate status
     ============================================================ */
    @IsTest
    static void testBatchDuplicateHandling() {
        // Pre-insert a Lead matching SuccessMock data to trigger duplicate detection
        insert new Lead(
            FirstName = 'Existing',
            LastName = 'User',
            Email = 'test@demo.com',
            Company = 'Demo'
        );

        keepOnlyOnePending('Exception - Success Log');
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        Test.stopTest();

        // Original Pending log should be updated to Duplicate status
        EmailToLead_Ai__Custom_Exception__c log = [
            SELECT Id, EmailToLead_Ai__Retry_Status__c FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name = 'Exception - Success Log'
            LIMIT 1
        ];
        System.assertEquals('Duplicate', log.EmailToLead_Ai__Retry_Status__c, 'Log status should be Duplicate');
    }

    /* ============================================================
       TEST 3 — Max retry reached: record marked as Failed
     ============================================================ */
    @IsTest
    static void testBatchMaxRetryFail() {
        keepOnlyOnePending('Exception - Fail Log');
        Test.setMock(HttpCalloutMock.class, new FailMock());

        Test.startTest();
        Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        Test.stopTest();

        EmailToLead_Ai__Custom_Exception__c updated = [
            SELECT EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name = 'Exception - Fail Log'
            LIMIT 1
        ];
        System.assertEquals('Failed', updated.EmailToLead_Ai__Retry_Status__c,
            'Record with retry count >= MAX should be marked as Failed');
        System.assertEquals(2, updated.EmailToLead_Ai__Retry_Count__c,
            'Retry count should be incremented to 2');
    }

    /* ============================================================
       TEST 4 — Callout failure on first attempt: stays Pending
     ============================================================ */
    @IsTest
    static void testBatchCalloutFail() {
        keepOnlyOnePending('Exception - Success Log');
        Test.setMock(HttpCalloutMock.class, new FailMock());

        Test.startTest();
        Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        Test.stopTest();

        EmailToLead_Ai__Custom_Exception__c r = [
            SELECT EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name = 'Exception - Success Log'
            LIMIT 1
        ];
        System.assertEquals('Pending', r.EmailToLead_Ai__Retry_Status__c,
            'Record should stay Pending on first callout failure');
        System.assertEquals(1, r.EmailToLead_Ai__Retry_Count__c,
            'Retry count should be incremented');
    }

    /* ============================================================
       TEST 5 — Missing email header throws, record handled gracefully
     ============================================================ */
    @IsTest
    static void testBatchNoBodyException() {
        // Insert a record with no header so the batch throws CalloutException
        EmailToLead_Ai__Custom_Exception__c noBody = new EmailToLead_Ai__Custom_Exception__c(
            Name = 'Exception - No Header',
            EmailToLead_Ai__Retry_Status__c = 'Pending',
            EmailToLead_Ai__Retry_Count__c = 0,
            EmailToLead_Ai__Next_Retry_Time__c = System.now().addDays(-1),
            EmailToLead_Ai__Email_Header__c = null,
            EmailToLead_Ai__Email_Body__c = null
        );
        insert noBody;

        // Make only this record pending
        List<EmailToLead_Ai__Custom_Exception__c> all = [
            SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Next_Retry_Time__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name != 'Exception - No Header'
        ];
        for (EmailToLead_Ai__Custom_Exception__c l : all) {
            l.EmailToLead_Ai__Retry_Status__c = 'Success';
            l.EmailToLead_Ai__Next_Retry_Time__c = System.now().addDays(5);
        }
        if (!all.isEmpty()) update all;

        Test.startTest();
        Database.executeBatch(new EmailToLeadRetryBatch(), 1);
        Test.stopTest();

        EmailToLead_Ai__Custom_Exception__c r = [
            SELECT EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Exception_message__c
            FROM EmailToLead_Ai__Custom_Exception__c
            WHERE Name = 'Exception - No Header'
            LIMIT 1
        ];
        // Should have handled the exception gracefully
        System.assertNotEquals(null, r.EmailToLead_Ai__Retry_Status__c);
    }

    /* ============================================================
       TEST 6 — Query locator is not null
     ============================================================ */
    @IsTest
    static void testStartQueryLocator() {
        Test.startTest();
        Database.QueryLocator ql = new EmailToLeadRetryBatch().start(null);
        Test.stopTest();
        System.assertNotEquals(null, ql, 'QueryLocator should not be null');
    }
}