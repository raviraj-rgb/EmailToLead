@IsTest
private class CustomExceptionLoggerTest {

    @IsTest
    static void testLogException_withLead() {
        Lead l = new Lead(LastName = 'Test', Company = 'Test Co');
        insert l;

        Exception ex = null;
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
            String.valueOf(l.Id),
            l.Id,
            '{"req":"value"}',
            '{"res":"value"}'
        );
        Test.stopTest();

        EmailToLead_Ai__Custom_Exception__c log = [
            SELECT Name,
                   EmailToLead_Ai__Class_Name__c,
                   EmailToLead_Ai__Exception_message__c,
                   EmailToLead_Ai__Type__c,
                   EmailToLead_Ai__Error_RecordId__c,
                   EmailToLead_Ai__Lead__c,
                   EmailToLead_Ai__RequestJSON__c,
                   EmailToLead_Ai__ResponseJSON__c,
                   EmailToLead_Ai__Line_Number__c
            FROM EmailToLead_Ai__Custom_Exception__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('CustomExceptionLoggerTest', log.EmailToLead_Ai__Class_Name__c);
        System.assertEquals('ErrorType', log.EmailToLead_Ai__Type__c);
        System.assertEquals(String.valueOf(l.Id), log.EmailToLead_Ai__Error_RecordId__c);
        System.assertEquals(l.Id, log.EmailToLead_Ai__Lead__c);
        System.assertEquals('{"req":"value"}', log.EmailToLead_Ai__RequestJSON__c);
        System.assertEquals('{"res":"value"}', log.EmailToLead_Ai__ResponseJSON__c);
        System.assertNotEquals(null, log.EmailToLead_Ai__Line_Number__c,
                               'Line number should be populated for exception logs');
        System.assert(log.Name.startsWith('Exception - '),
                      'Name should start with \"Exception - \" for exception logs');
        System.assertNotEquals(null, log.EmailToLead_Ai__Exception_message__c,
                               'Exception message should be stored');
    }

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

        EmailToLead_Ai__Custom_Exception__c log = [
            SELECT Name,
                   EmailToLead_Ai__Class_Name__c,
                   EmailToLead_Ai__Exception_message__c,
                   EmailToLead_Ai__Type__c,
                   EmailToLead_Ai__Error_RecordId__c,
                   EmailToLead_Ai__Lead__c,
                   EmailToLead_Ai__RequestJSON__c,
                   EmailToLead_Ai__ResponseJSON__c,
                   EmailToLead_Ai__Line_Number__c
            FROM EmailToLead_Ai__Custom_Exception__c
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        System.assertEquals('CustomExceptionLoggerTest', log.EmailToLead_Ai__Class_Name__c);
        System.assertEquals('SuccessType', log.EmailToLead_Ai__Type__c);
        System.assertEquals('Success message', log.EmailToLead_Ai__Exception_message__c);
        System.assertEquals(null, log.EmailToLead_Ai__Lead__c,
                            'Lead should be null for success without lead');
        System.assertEquals(null, log.EmailToLead_Ai__Error_RecordId__c,
                            'Error record should be null for success logs');
        System.assertEquals(null, log.EmailToLead_Ai__Line_Number__c,
                            'Line number should be null for success logs');
        System.assertEquals('{"req":"ok"}', log.EmailToLead_Ai__RequestJSON__c);
        System.assertEquals('{"res":"ok"}', log.EmailToLead_Ai__ResponseJSON__c);
        System.assert(log.Name.startsWith('Success - '),
                      'Name should start with \"Success - \" for success logs');
    }

    @IsTest
static void testExtractLineNumberGracefulOnBadStack() {
    Exception ex = null;
    try {
        insert new Account(); // or any failing op
    } catch (Exception e) {
        ex = e;
    }
    System.assertNotEquals(null, ex, 'Exception should be captured');

    Test.startTest();
    CustomExceptionLogger.logException(
        ex,
        'CustomExceptionLoggerTest',
        'ErrorTypeNoLine',
        null,
        null,
        null,
        null
    );
    Test.stopTest();

    EmailToLead_Ai__Custom_Exception__c log = [
        SELECT EmailToLead_Ai__Line_Number__c
        FROM EmailToLead_Ai__Custom_Exception__c
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    // Just verify it doesn't blow up and line number is a positive integer
    System.assert(log.EmailToLead_Ai__Line_Number__c != null,
                  'Line number should be set for real exceptions');
}

}