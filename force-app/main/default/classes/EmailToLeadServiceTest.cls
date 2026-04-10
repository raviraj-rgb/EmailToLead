@IsTest
private class EmailToLeadServiceTest {

    // Simple HttpCalloutMock to fake AI response
    private class AiHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            // Response shape matches extractContentByPath "choices[0].message.content"
            String body = '{"choices":[{"message":{"content":"{' +
                '\\\"FirstName\\\": \\\"John\\\",' +
                '\\\"LastName\\\": \\\"Doe\\\",' +
                '\\\"Email\\\": \\\"john.doe@example.com\\\",' +
                '\\\"Company\\\": \\\"Acme Inc\\\",' +
                '\\\"summary\\\": \\\"Test summary\\\"' +
                '}"}}]}';

            res.setBody(body);
            return res;
        }
    }

    // Helper to create minimal active config (regular sObject only)
    private static void setupConfigOnly() {
        // Active AI config (custom object) – DML is allowed
        EmailToLead_Ai__AI_Configs__c apiConfig = new EmailToLead_Ai__AI_Configs__c(
            Name = 'Default AI Config',
            EmailToLead_Ai__Model_Name__c = 'glm-4.5-air',
            EmailToLead_Ai__Named_Credential__c = 'ZAPI_NC',
            EmailToLead_Ai__Endpoint__c = 'https://dummy-endpoint',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content',
            EmailToLead_Ai__Is_Active__c = true
        );
        insert apiConfig;

        EmailToLead_Ai__AI_Configure__c aiConfig = new EmailToLead_Ai__AI_Configure__c(
            Name = 'Test Config',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__Model__c = 'Default AI Config',
            EmailToLead_Ai__System_prompt__c = 'System prompt',
            EmailToLead_Ai__User_Prompt__c = 'User prompt with {ALLOWED_FIELDS} and {EMAIL_BODY}',
            EmailToLead_Ai__Scheduler_Retry_Hours__c = 1
        );
        insert aiConfig;

        // Insert lead field config for mapping
        EmailToLead_Ai__Email_Lead_Field__c fieldConfig = new EmailToLead_Ai__Email_Lead_Field__c(
            Name = 'fields_part_1',
            EmailToLead_Ai__Selected_fields__c = 'firstname,lastname,email,company,summary',
            EmailToLead_Ai__Email_Body_Field__c = 'description',
            EmailToLead_Ai__Summary_Field__c = 'description',
            EmailToLead_Ai__Is_Active__c = true
        );
        insert fieldConfig;

        // NOTE: Email_Lead_Field__c must already exist in the org (deployed CMT); tests cannot insert them.
    }

    @IsTest
static void testHandleInboundEmail_success_createsLead() {
    setupConfigOnly();
    Test.setMock(HttpCalloutMock.class, new AiHttpMock());

    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.fromAddress   = 'john.doe@example.com';
    email.plainTextBody = 'This is an urgent test email body for AI.';

    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

    Test.startTest();
    Messaging.InboundEmailResult result =
        new EmailToLeadService().handleInboundEmail(email, env);
    Test.stopTest();

    System.assertEquals(true, result.success, 'Lead should be created successfully');

    Lead created = [
        SELECT Id, FirstName, LastName, Email, Company, Title, Description,
               EmailToLead_Ai__Is_Lead_Created_From_Email__c
        FROM Lead
        WHERE Email = :email.fromAddress
        LIMIT 1
    ];

    // Core guarantees from buildLeadFromJson
    System.assertNotEquals(null, created.Id, 'Lead record must be created');
    System.assertEquals(
        true,
        created.EmailToLead_Ai__Is_Lead_Created_From_Email__c,
        'Flag should be set to true'
    );

    System.assertEquals(
        email.fromAddress,
        created.Email,
        'Email should be taken from inbound email when not set by AI'
    );

    // Do not assume which field stores email body or summary.
    // Just assert they are populated somewhere according to CMT.
    System.assertNotEquals(
        null,
        created.Description,
        'Configured summary field (e.g., Description) should be populated'
    );
    System.assertEquals(
        'Test summary',
        created.Description,
        'Summary from AI should be stored in configured Summary_Field__c'
    );

    // If you want to verify body storage exactly, query the real email body field:
    // (uncomment and adjust if you know the mapped API name, e.g. Email_Body__c)
    /*
    Lead createdFull = [
        SELECT Email_Body__c
        FROM Lead
        WHERE Id = :created.Id
        LIMIT 1
    ];
    System.assertEquals(
        email.plainTextBody,
        createdFull.Email_Body__c,
        'Email body should be stored in Email_Body__c as per CMT'
    );
    */
}
 

    @IsTest
    static void testHandleInboundEmail_emptyBody() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress   = 'no.body@example.com';
        email.plainTextBody = '';  // blank

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result =
            new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when email body is empty');
        System.assertEquals('Email body is empty.', result.message);
    }

    @IsTest
    static void testHandleInboundEmail_missingConfig_throwsError() {
        // No Ai_Configs__c inserted; CMT might still exist but active AI config not found
        Test.setMock(HttpCalloutMock.class, new AiHttpMock());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress   = 'no.config@example.com';
        email.plainTextBody = 'Body text';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult result =
            new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail when AI config is missing');
        System.assertNotEquals(null, result.message, 'Message should not be null');
    }

    @IsTest
    static void testHandleInboundEmail_GeminiModel() {
        setupConfigOnly();
        EmailToLead_Ai__AI_Configs__c config = [SELECT Id FROM EmailToLead_Ai__AI_Configs__c LIMIT 1];
        config.EmailToLead_Ai__Model_Name__c = 'gemini-1.5-flash';
        update config;
        Test.setMock(HttpCalloutMock.class, new AiHttpMock());
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'gemini.test@example.com';
        email.plainTextBody = 'Test Gemini Content';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        Test.startTest();
        Messaging.InboundEmailResult result = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();
        System.assertEquals(true, result.success, 'Gemini request should succeed');
    }
}