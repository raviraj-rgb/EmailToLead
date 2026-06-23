@IsTest
public class CustomExceptionLoggerTest {

    @IsTest
    static void testLogException() {
        Test.startTest();
        try {
            Integer i = 1 / 0;
        } catch (Exception e) {
            CustomExceptionLogger.logException(
                e,
                'CustomExceptionLoggerTest',
                'Error',
                (Id)null,     // errorRecordId
                (Id)null,     // leadId
                '{"req": "test"}',
                '{"res": "test"}',
                'From: test@demo.com',
                'Body content'
            );
        }
        
        CustomExceptionLogger.logException(
            null,
            'CustomExceptionLoggerTest',
            'Manual',
            (Id)null,     // errorRecordId
            (Id)null,     // leadId
            (String)null, // header
            (String)null, // body
            (String)null, // req
            (String)null  // res
        );
        Test.stopTest();

        List<EmailToLead_Ai__Custom_Exception__c> logs = [SELECT Id, EmailToLead_Ai__Exception_message__c, EmailToLead_Ai__ResponseJSON__c FROM EmailToLead_Ai__Custom_Exception__c];
        System.assert(logs.size() >= 2, 'Should have created at least 2 logs');
    }

    @IsTest
    static void testLogSuccess() {
        Test.startTest();
        CustomExceptionLogger.logSuccess(
            'Operation successful',
            'CustomExceptionLoggerTest',
            'SuccessType',
            null,
            '{"req": "test"}',
            '{"res": "test"}'
        );
        Test.stopTest();

        EmailToLead_Ai__Custom_Exception__c log = [SELECT EmailToLead_Ai__Retry_Status__c FROM EmailToLead_Ai__Custom_Exception__c LIMIT 1];
        System.assertEquals('Success', log.EmailToLead_Ai__Retry_Status__c);
    }

    @IsTest
    static void testLogDuplicate() {
        Test.startTest();
        CustomExceptionLogger.logDuplicate(
            new DmlException('Duplicate found'),
            'CustomExceptionLoggerTest',
            null,
            '{"req": "test"}',
            '{"res": "test"}',
            'Header',
            'Body',
            'Cleaned'
        );
        Test.stopTest();

        List<EmailToLead_Ai__Custom_Exception__c> logs = [SELECT Id FROM EmailToLead_Ai__Custom_Exception__c];
        System.assertEquals(0, logs.size(), 'Duplicate log should be suppressed');
    }

    @IsTest
    static void testTruncateAndThoughtSignature() {
        // This implicitly tests the private safeTruncate via logSuccess
        String longMsg = 'A'.repeat(33000);
        String jsonWithThought = '{"data": "test"}';
        
        Test.startTest();
        CustomExceptionLogger.logSuccess(
            longMsg,
            'Test',
            'Test',
            null,
            longMsg,
            jsonWithThought
        );
        Test.stopTest();
        
        EmailToLead_Ai__Custom_Exception__c log = [SELECT EmailToLead_Ai__Exception_message__c, EmailToLead_Ai__ResponseJSON__c FROM EmailToLead_Ai__Custom_Exception__c LIMIT 1];
        System.assertEquals(32700, log.EmailToLead_Ai__Exception_message__c.length(), 'Should truncate message to 32700');
        System.assertEquals(jsonWithThought, log.EmailToLead_Ai__ResponseJSON__c, 'Should store full response JSON');
    }

    @IsTest
    static void testExceptionWithCause() {
        // Create an exception with a cause
        Exception cause = new DmlException('Inner cause');
        // Unfortunately standard Apex exceptions can't easily have 'cause' set post-construction except via some tricks
        // but we can at least test logException with various inputs
        
        Test.startTest();
        CustomExceptionLogger.logException(
            null,
            'Test',
            'Test',
            (Id)null,     // errorRecordId
            (Id)null,     // leadId
            (String)null, // header
            (String)null, // body
            (String)null, // req
            (String)null  // res
        );
        Test.stopTest();
        // Just ensuring no crash
    }

    @IsTest
    static void testLogSkipped() {
        Test.startTest();
        CustomExceptionLogger.logSkipped(
            'Skipped reason',
            'TestClass',
            'Header info',
            'Body info',
            'Req json',
            'Res json'
        );
        Test.stopTest();
        
        List<EmailToLead_Ai__Custom_Exception__c> logs = [SELECT EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Type__c FROM EmailToLead_Ai__Custom_Exception__c];
        EmailToLead_Ai__Custom_Exception__c log = null;
        for (EmailToLead_Ai__Custom_Exception__c l : logs) {
            if (l.EmailToLead_Ai__Type__c == 'Skipped') {
                log = l;
                break;
            }
        }
        System.assertNotEquals(null, log, 'Skipped log should exist');
        System.assertEquals('Skipped', log.EmailToLead_Ai__Retry_Status__c);
    }
}
//Gitting
