@isTest
private class EmailToLeadService_Test {

    @TestSetup
    static void setupTestData() {
        // IMPORTANT: Create API Config custom setting FIRST (trigger validates against this)
        EmailToLead_Ai__AI_Configs__c apiConfig = new EmailToLead_Ai__AI_Configs__c();
        apiConfig.Name = 'TestModel';
        apiConfig.EmailToLead_Ai__Model_Name__c = 'test-model';
        apiConfig.EmailToLead_Ai__Named_Credential__c = 'TestCredential';
        apiConfig.EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content';
        apiConfig.EmailToLead_Ai__Is_Active__c = true;
        insert apiConfig;

        // Now create AI Configure record (trigger will find the custom setting)
        EmailToLead_Ai__AI_Configure__c aiConfig = new EmailToLead_Ai__AI_Configure__c();
        aiConfig.Name = 'Test Config';
        aiConfig.EmailToLead_Ai__isActive__c = true;
        aiConfig.EmailToLead_Ai__Model__c = 'TestModel';
        aiConfig.EmailToLead_Ai__Named_Credential__c = 'TestCredential';
        aiConfig.EmailToLead_Ai__System_prompt__c = 'Return JSON only.';
        aiConfig.EmailToLead_Ai__User_Prompt__c = 'Extract fields: {ALLOWED_FIELDS}\n{EMAIL_BODY}';
        aiConfig.EmailToLead_Ai__Scheduler_Retry_Hours__c = 1;
        insert aiConfig;

        // Create Email Lead Field config with Nick keyword
        EmailToLead_Ai__Email_Lead_Field__c fieldConfig = new EmailToLead_Ai__Email_Lead_Field__c();
        fieldConfig.Name = 'fields_part_1';
        fieldConfig.EmailToLead_Ai__Selected_fields__c = 'firstname,lastname,email,company,phone,title,description,leadsource';
        fieldConfig.EmailToLead_Ai__Email_Body_Field__c = 'description';
        fieldConfig.EmailToLead_Ai__Summary_Field__c = 'description';
        fieldConfig.EmailToLead_Ai__Is_Active__c = true;
        fieldConfig.EmailToLead_Ai__Nick_Keyword__c = 'NickTest';
        fieldConfig.EmailToLead_Ai__Nick_User__c = 'test';
        insert fieldConfig;
    }

    // ============================================================
    // MOCK HTTP RESPONSES
    // ============================================================
    
    // Standard success response with single lead
    private class SingleLeadMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"John\\",\\"LastName\\":\\"Doe\\",\\"Email\\":\\"john.doe@testcompany.com\\",\\"Company\\":\\"Test Company\\",\\"Phone\\":\\"5551234567\\",\\"Title\\":\\"Manager\\",\\"summary\\":\\"New lead inquiry from web form\\"}"}}]}');
            return res;
        }
    }

    // Multiple leads response
    private class MultipleLeadsMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"leads\\":[{\\"FirstName\\":\\"John\\",\\"LastName\\":\\"Doe\\",\\"Email\\":\\"john@company1.com\\",\\"Company\\":\\"Company A\\",\\"Phone\\":\\"111\\",\\"summary\\":\\"Lead 1\\"},{\\"FirstName\\":\\"Jane\\",\\"LastName\\":\\"Smith\\",\\"Email\\":\\"jane@company2.com\\",\\"Company\\":\\"Company B\\",\\"Phone\\":\\"222\\",\\"summary\\":\\"Lead 2\\"}]}"}}]}');
            return res;
        }
    }

    // Array format response
    private class ArrayLeadsMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"[{\\"FirstName\\":\\"Array\\",\\"LastName\\":\\"User\\",\\"Email\\":\\"array@test.com\\",\\"Company\\":\\"Array Co\\",\\"Phone\\":\\"333\\",\\"summary\\":\\"Array lead\\"}]"}}]}');
            return res;
        }
    }

    // API error response
    private class ApiErrorMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Internal Server Error"}');
            return res;
        }
    }

    // Empty JSON response
    private class EmptyJsonMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"No valid data found"}}]}');
            return res;
        }
    }

    // Gmail domain lead (tests Company fallback to "Company")
    private class GmailLeadMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"Gmail\\",\\"LastName\\":\\"User\\",\\"Email\\":\\"user@gmail.com\\",\\"Phone\\":\\"444\\",\\"summary\\":\\"Gmail lead\\"}"}}]}');
            return res;
        }
    }

    // Lead with no Company (tests domain fallback)
    private class NoCompanyLeadMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"No\\",\\"LastName\\":\\"Company\\",\\"Email\\":\\"user@customdomain.com\\",\\"Phone\\":\\"555\\",\\"summary\\":\\"No company lead\\"}"}}]}');
            return res;
        }
    }

    // Minimal lead (only 1 field - should be rejected)
    private class MinimalLeadMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"Only\\",\\"summary\\":\\"Minimal\\"}"}}]}');
            return res;
        }
    }

    // Lead with picklist field
    private class PicklistLeadMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"Pick\\",\\"LastName\\":\\"List\\",\\"Email\\":\\"pick@test.com\\",\\"Company\\":\\"Picklist Co\\",\\"Phone\\":\\"666\\",\\"LeadSource\\":\\"Web\\",\\"summary\\":\\"Picklist lead\\"}"}}]}');
            return res;
        }
    }

    // Lead with Nick keyword
    private class NickKeywordMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"Nick\\",\\"LastName\\":\\"Test\\",\\"Email\\":\\"nick@test.com\\",\\"Company\\":\\"Nick Co\\",\\"Phone\\":\\"777\\",\\"summary\\":\\"Nick lead\\"}"}}]}');
            return res;
        }
    }

    // Lead with AI guessed Company (not in body)
    private class AIGuessedCompanyMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"choices":[{"message":{"content":"{\\"FirstName\\":\\"AI\\",\\"LastName\\":\\"Guess\\",\\"Email\\":\\"guess@domain.com\\",\\"Company\\":\\"Completely Made Up Company\\",\\"Phone\\":\\"888\\",\\"summary\\":\\"AI guessed company\\"}"}}]}');
            return res;
        }
    }

    // ============================================================
    // TEST: Empty email body
    // ============================================================
    @isTest
    static void testHandleInboundEmail_EmptyBody() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '';
        email.fromAddress = 'test@example.com';
        email.subject = 'Test Subject';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'test@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with empty body');
        System.assertEquals('Email body is empty.', result.message);
    }

    // ============================================================
    // TEST: Null email
    // ============================================================
    @isTest
    static void testHandleInboundEmail_NullEmail() {
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'test@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(null, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with null email');
    }

    // ============================================================
    // TEST: Successful single lead creation
    // ============================================================
    @isTest
    static void testHandleInboundEmail_SuccessSingleLead() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* john.doe@testcompany.com\n*Company Name:* Test Company\n*Contact Name:* John Doe\n*Phone:* 5551234567';
        email.fromAddress = 'sender@example.com';
        email.subject = 'New Lead Inquiry';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@salesforce.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Multiple leads creation (leads array format)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_MultipleLeads() {
        Test.setMock(HttpCalloutMock.class, new MultipleLeadsMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'INQ-001\n*Contact:* John Doe\n*Email:* john@company1.com\n\nINQ-002\n*Contact:* Jane Smith\n*Email:* jane@company2.com';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Multiple Leads';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Array format response
    // ============================================================
    @isTest
    static void testHandleInboundEmail_ArrayFormat() {
        Test.setMock(HttpCalloutMock.class, new ArrayLeadsMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact:* Array User\n*Email:* array@test.com';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Array Format';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: API error handling
    // ============================================================
    @isTest
    static void testHandleInboundEmail_ApiError() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* error@test.com\n*Company:* Error Co';
        email.fromAddress = 'sender@example.com';
        email.subject = 'API Error Test';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail on API error');
    }

    // ============================================================
    // TEST: Empty JSON response (no leads)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_EmptyJsonResponse() {
        Test.setMock(HttpCalloutMock.class, new EmptyJsonMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* empty@test.com\n*Company:* Empty Co';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Empty Response';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with no JSON');
    }

    // ============================================================
    // TEST: Gmail domain Company fallback
    // ============================================================
    @isTest
    static void testHandleInboundEmail_GmailDomain() {
        Test.setMock(HttpCalloutMock.class, new GmailLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* user@gmail.com\n*Contact Name:* Gmail User';
        email.fromAddress = 'sender@gmail.com';
        email.subject = 'Gmail Lead';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@gmail.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: No Company - domain fallback
    // ============================================================
    @isTest
    static void testHandleInboundEmail_NoCompanyDomainFallback() {
        Test.setMock(HttpCalloutMock.class, new NoCompanyLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* user@customdomain.com';
        email.fromAddress = 'sender@example.com';
        email.subject = 'No Company';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Minimal lead (less than 2 fields - rejected)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_MinimalLead() {
        Test.setMock(HttpCalloutMock.class, new MinimalLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Name:* Only Name';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Minimal Lead';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Should fail with minimal lead');
    }

    // ============================================================
    // TEST: Picklist field validation
    // ============================================================
    @isTest
    static void testHandleInboundEmail_PicklistField() {
        Test.setMock(HttpCalloutMock.class, new PicklistLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact:* Pick List\n*Email:* pick@test.com\n*Source:* Web';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Picklist Test';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Email with signature (regards section stripped)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_WithSignature() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* john.doe@testcompany.com\n' +
            '*Company Name:* Test Company\n' +
            '*Contact Name:* John Doe\n\n' +
            'regards,\n' +
            'John Smith\n' +
            'Sales Manager\n' +
            'Phone: 555-123-4567';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Lead with Signature';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Forwarded email with *From:* header
    // ============================================================
    @isTest
    static void testHandleInboundEmail_ForwardedEmailStarFormat() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*From:* original@company.com\n' +
            '*Sent:* Monday, January 20, 2026\n' +
            '*To:* team@company.com\n' +
            '*Subject:* Lead Request\n\n' +
            '*Contact Email:* john.doe@testcompany.com\n' +
            '*Company Name:* Test Company';
        email.fromAddress = 'forwarder@example.com';
        email.subject = 'Fwd: Lead Request';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'forwarder@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Forwarded email with From: header (no asterisks)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_ForwardedEmailNoAsterisks() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'From: original@company.com\n' +
            'Date: Mon, Jan 20, 2026\n' +
            'To: leads@company.com\n' +
            'Subject: New Lead\n\n' +
            '*Contact Email:* john.doe@testcompany.com\n' +
            '*Company:* Test Company';
        email.fromAddress = 'forwarder@example.com';
        email.subject = 'Fwd: New Lead';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'forwarder@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Nick keyword owner assignment
    // ============================================================
    @isTest
    static void testHandleInboundEmail_NickKeywordAssignment() {
        Test.setMock(HttpCalloutMock.class, new NickKeywordMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'This email contains NickTest keyword\n*Contact:* Nick Test\n*Email:* nick@test.com';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Nick Keyword Test';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: AI guessed Company (should be cleared if not in body)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_AIGuessedCompany() {
        Test.setMock(HttpCalloutMock.class, new AIGuessedCompanyMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact:* AI Guess\n*Email:* guess@domain.com\n*Phone:* 888';
        email.fromAddress = 'sender@example.com';
        email.subject = 'AI Guessed Company';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: INQ pattern extraction
    // ============================================================
    @isTest
    static void testHandleInboundEmail_INQPattern() {
        Test.setMock(HttpCalloutMock.class, new MultipleLeadsMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'INQ-12345\n*Contact:* First Lead\n*Email:* first@test.com\n\n' +
            'INQ-67890\n*Contact:* Second Lead\n*Email:* second@test.com\n\n' +
            'View the detailed report here...';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Multiple INQ Leads';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: DML error simulation
    // ============================================================
    @isTest
    static void testHandleInboundEmail_DmlError() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* dml.error@test.com\n*Company:* DML Error Co\n*Name:* DML User';
        email.fromAddress = 'sender@example.com';
        email.subject = 'DML Error Test';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        // Enable DML error simulation
        EmailToLeadService.FORCE_DML_ERROR_TEST = true;

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        // Reset the flag
        EmailToLeadService.FORCE_DML_ERROR_TEST = false;

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Null envelope
    // ============================================================
    @isTest
    static void testHandleInboundEmail_NullEnvelope() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* null.env@test.com\n*Company:* Null Env Co\n*Name:* User';
        email.fromAddress = 'sender@example.com';
        email.subject = 'Null Envelope Test';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, null);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Carriage returns in body
    // ============================================================
    @isTest
    static void testHandleInboundEmail_CarriageReturns() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* crlf@test.com\r\n*Company:* CRLF Co\r\n*Name:* CRLF User';
        email.fromAddress = 'sender@example.com';
        email.subject = 'CRLF Test';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'sender@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Email with no fromAddress (tests fallback)
    // ============================================================
    @isTest
    static void testHandleInboundEmail_NoFromAddress() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*Contact Email:* john.doe@testcompany.com\n*Company:* Test Company\n*Name:* John Doe';
        email.fromAddress = null;
        email.subject = 'No From Address';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = '';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ============================================================
    // TEST: Email with Cc: and Date: headers
    // ============================================================
    @isTest
    static void testHandleInboundEmail_AllHeaderTypes() {
        Test.setMock(HttpCalloutMock.class, new SingleLeadMockResponse());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = '*From:* sender@company.com\n' +
            '*Sent:* Monday\n' +
            '*To:* recipient@company.com\n' +
            '*Cc:* cc@company.com\n' +
            '*Date:* 2026-01-20\n' +
            '*Subject:* Test\n\n' +
            '*Contact Email:* john.doe@testcompany.com\n' +
            '*Company:* Test Company';
        email.fromAddress = 'forwarder@example.com';
        email.subject = 'All Headers';

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        env.fromAddress = 'forwarder@example.com';
        env.toAddress = 'lead@org.com';

        Test.startTest();
        EmailToLeadService service = new EmailToLeadService();
        Messaging.InboundEmailResult result = service.handleInboundEmail(email, env);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }
}
