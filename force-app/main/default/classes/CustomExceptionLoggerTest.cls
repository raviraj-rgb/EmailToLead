@IsTest
private class CustomExceptionLoggerTest {

    /* ============================================================
       TEST : logException – full 9-arg signature
    ============================================================ */
    @IsTest
    static void testLogException_withAllArgs() {
        Lead l = new Lead(LastName = 'Test', Company = 'Test Co');
        insert l;

        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }
        System.assertNotEquals(null, ex, 'Exception should be captured');

        Test.startTest();
        CustomExceptionLogger.logException(
            ex,
            'CustomExceptionLoggerTest',
            'ErrorType',
            l.Id,
            l.Id,
            '{"req":"value"}',
            '{"res":"value"}',
            'From: a@test.com\nTo: b@test.com\nSubject: Test',
            'Email body content'
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Name, Class_Name__c, Exception_message__c, Type__c,
                   Error_RecordId__c, Lead__c, RequestJSON__c, ResponseJSON__c,
                   Line_Number__c, Retry_Status__c, Retry_Count__c,
                   Email_Header__c, Email_Body__c
            FROM Custom_Exception__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('CustomExceptionLoggerTest', log.Class_Name__c);
        System.assertEquals('ErrorType', log.Type__c);
        System.assertEquals(String.valueOf(l.Id), log.Error_RecordId__c);
        System.assertEquals(l.Id, log.Lead__c);
        System.assertEquals('{"req":"value"}', log.RequestJSON__c);
        System.assertEquals('{"res":"value"}', log.ResponseJSON__c);
        System.assertEquals('Pending', log.Retry_Status__c);
        System.assertEquals(0, log.Retry_Count__c);
        System.assertNotEquals(null, log.Email_Header__c);
        System.assertNotEquals(null, log.Email_Body__c);
        System.assertNotEquals(null, log.Line_Number__c);
        System.assert(log.Name.startsWith('Exception - '));
    }

    /* ============================================================
       TEST : logException – null / blank optional args
    ============================================================ */
    @IsTest
    static void testLogException_withNulls() {
        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }

        Test.startTest();
        CustomExceptionLogger.logException(
            ex,
            'TestClass',
            'ErrorType',
            null,   // errorRecordId
            null,   // leadId
            null,   // requestJSON
            null,   // responseJSON
            null,   // emailHeader
            null    // emailBody
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Name, Lead__c, Error_RecordId__c,
                   Email_Header__c, Email_Body__c, Retry_Status__c
            FROM Custom_Exception__c
            LIMIT 1
        ];

        System.assertEquals(null, log.Lead__c);
        System.assertEquals(null, log.Error_RecordId__c);
        System.assertEquals('Pending', log.Retry_Status__c);
    }

    /* ============================================================
       TEST : logSuccess
    ============================================================ */
    @IsTest
    static void testLogSuccess_withoutLead() {
        Test.startTest();
        CustomExceptionLogger.logSuccess(
            'Success message',
            'CustomExceptionLoggerTest',
            'SuccessType',
            null,
            '{"req":"ok"}',
            '{"res":"ok"}'
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Name, Class_Name__c, Exception_message__c, Type__c,
                   Lead__c, Retry_Status__c, Retry_Count__c
            FROM Custom_Exception__c
            LIMIT 1
        ];

        System.assertEquals('CustomExceptionLoggerTest', log.Class_Name__c);
        System.assertEquals('SuccessType', log.Type__c);
        System.assertEquals('Success message', log.Exception_message__c);
        System.assertEquals(null, log.Lead__c);
        System.assertEquals('Success', log.Retry_Status__c);
        System.assertEquals(null, log.Retry_Count__c);
        System.assert(log.Name.startsWith('Success - '));
    }

    @IsTest
    static void testLogSuccess_withLead() {
        Lead l = new Lead(LastName = 'SuccessLead', Company = 'Success Co');
        insert l;

        Test.startTest();
        CustomExceptionLogger.logSuccess(
            'Lead created',
            'TestClass',
            'Success',
            l.Id,
            '{"req":"ok"}',
            '{"res":"ok"}'
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Lead__c, Retry_Status__c
            FROM Custom_Exception__c
            LIMIT 1
        ];

        System.assertEquals(l.Id, log.Lead__c);
        System.assertEquals('Success', log.Retry_Status__c);
    }

    /* ============================================================
       TEST : logDuplicate
    ============================================================ */
    @IsTest
    static void testLogDuplicate_withExistingLead() {
        Lead l = new Lead(LastName = 'DupLead', Company = 'Dup Co');
        insert l;

        Exception ex;
        try {
            throw new System.DmlException('DUPLICATES_DETECTED');
        } catch (Exception e) {
            ex = e;
        }

        Test.startTest();
        CustomExceptionLogger.logDuplicate(
            ex,
            'EmailToLeadService',
            l.Id,
            '{"req":"dup"}',
            '{"res":"dup"}',
            'From: dup@test.com\nSubject: Dup',
            'Duplicate email body',
            'Cleaned body content'
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Name, Class_Name__c, Type__c, Lead__c,
                   Retry_Status__c, Retry_Count__c, Next_Retry_Time__c,
                   Email_Header__c, Email_Body__c, Exception_message__c
            FROM Custom_Exception__c
            LIMIT 1
        ];

        System.assert(log.Name.startsWith('Duplicate - '));
        System.assertEquals('Duplicate', log.Type__c);
        System.assertEquals('Duplicate', log.Retry_Status__c);
        System.assertEquals(null, log.Retry_Count__c);
        System.assertEquals(null, log.Next_Retry_Time__c);
        System.assertEquals(l.Id, log.Lead__c);
        System.assertNotEquals(null, log.Email_Header__c);
        System.assertNotEquals(null, log.Email_Body__c);
        System.assert(log.Exception_message__c.contains('CleanedBody:'));
    }

    @IsTest
    static void testLogDuplicate_withNullLead() {
        Test.startTest();
        CustomExceptionLogger.logDuplicate(
            null,        // null exception
            'TestClass',
            null,        // null leadId
            null,
            null,
            null,
            null,
            null
        );
        Test.stopTest();

        Custom_Exception__c log = [
            SELECT Name, Type__c, Retry_Status__c, Lead__c,
                   Exception_message__c
            FROM Custom_Exception__c
            LIMIT 1
        ];

        System.assertEquals('Duplicate', log.Type__c);
        System.assertEquals('Duplicate', log.Retry_Status__c);
        System.assertEquals(null, log.Lead__c);
        System.assertEquals('Duplicate detected.', log.Exception_message__c);
    }
}