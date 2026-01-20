@IsTest
private class EmailToLeadService_Test {

    // ==================== MOCK CLASSES ====================
    
    private class MockZApiSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String content = JSON.serialize(new Map<String, Object>{
                'LastName' => 'Mitchell',
                'Email' => 'john.mitchell@abctech.com',
                'Phone' => '(408) 555-1234',
                'MobilePhone' => '(408) 555-5678',
                'Website' => 'https://www.abctech.com',
                'Company' => 'ABC Tech Solutions',
                'LeadSource' => 'Web',
                'summary' => 'This is a summary returned by AI.'
            });
            String body = JSON.serialize(new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'content' => content
                        }
                    }
                }
            });
            res.setBody(body);
            return res;
        }
    }

    private class MockZApiMultipleLeads implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            List<Map<String, Object>> leads = new List<Map<String, Object>>{
                new Map<String, Object>{
                    'LastName' => 'Hernandez',
                    'Email' => 'jhernandez@oaktreelearningcenter.com',
                    'Phone' => '9093522497',
                    'Company' => 'Oak Tree Learning Center'
                },
                new Map<String, Object>{
                    'LastName' => 'Oliver',
                    'Email' => 'kimberly.oliver@menifeeusd.org',
                    'Phone' => '9518522450',
                    'Company' => 'Menifee USD'
                }
            };
            
            String content = JSON.serialize(new Map<String, Object>{ 'leads' => leads });
            
            String body = JSON.serialize(new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'content' => content
                        }
                    }
                }
            });
            res.setBody(body);
            return res;
        }
    }

    private class MockZApiBadContent implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String body = JSON.serialize(new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'content' => 'Hello, this is not JSON'
                        }
                    }
                }
            });
            res.setBody(body);
            return res;
        }
    }

    // ==================== SETUP METHODS ====================

    private static void createAiConfig() {
        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c();
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'glm-4.5-air';
        cfg.EmailToLead_Ai__System_prompt__c = 'You are a Salesforce Lead Extractor.';
        cfg.EmailToLead_Ai__User_Prompt__c = 'Extract ONLY the following fields into JSON: {ALLOWED_FIELDS}\n\n{EMAIL_BODY}';
        cfg.EmailToLead_Ai__Named_Credential__c = 'Dummy_NC';
        insert cfg;
    }

    private static void createAllowedFieldsCS() {
        EmailToLead_Ai__Email_Lead_Field__c cs = new EmailToLead_Ai__Email_Lead_Field__c();
        cs.Name = 'ActiveConfig';
        cs.EmailToLead_Ai__Is_Active__c = true;
        cs.EmailToLead_Ai__Selected_fields__c = 'LastName,Email,Phone,MobilePhone,Website,Company,LeadSource';
        cs.EmailToLead_Ai__Email_Body_Field__c = 'Description';
        cs.EmailToLead_Ai__Summary_Field__c = 'Description';
        cs.EmailToLead_Ai__Nick_Keyword__c = 'nick';
        cs.EmailToLead_Ai__Nick_User__c = 'adm';
        insert cs;
    }

    // ==================== TEST METHODS ====================

    @IsTest 
    static void test_handleInboundEmail_success() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'john.mitchell@abctech.com';
        email.subject = 'LSI Lead Inquiry';
        email.plainTextBody = 'Lead Inquiry\nCompany: ABC Tech\nPhone: (408) 555-1234';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest 
    static void test_handleInboundEmail_blankBody() {
        createAiConfig();
        createAllowedFieldsCS();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = null;
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest 
    static void test_nickOwnerKeyword() {
        createAiConfig();
        createAllowedFieldsCS();
        EmailToLeadService.FORCE_DML_ERROR_TEST = false;
        
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'URGENT nick handle this important lead';
        email.fromAddress = 'test@example.com';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();
    }

    @IsTest 
    static void test_forceDmlErrorPath() {
        createAiConfig();
        createAllowedFieldsCS();
        EmailToLeadService.FORCE_DML_ERROR_TEST = true;
        
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'test body';
        email.fromAddress = 'test@example.com';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest 
    static void test_badAIResponse() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiBadContent());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.plainTextBody = 'valid body but bad AI';
        email.fromAddress = 'bad@example.com';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest 
    static void test_nullEmailObject() {
        createAiConfig();
        createAllowedFieldsCS();

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(null, env);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    @IsTest 
    static void test_multipleLeadsFromEmail() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiMultipleLeads());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'sender@company.com';
        email.subject = 'Lead Daily Summary';
        email.plainTextBody = 'Your daily summary of Leads\nLead 1: Hernandez\nLead 2: Oliver';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest 
    static void test_forwardedEmail() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'forwarder@company.com';
        email.subject = 'Fwd: Lead Inquiry';
        email.plainTextBody = 'FYI\n\n---------- Forwarded message ---------\nFrom: Original Sender <original@test.com>\nDate: Mon, 19 Jan 2026\nSubject: Lead Inquiry\n\nLead details here';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest 
    static void test_signatureStripping() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'test@signature.com';
        email.subject = 'Lead with Signature';
        email.plainTextBody = 'Please process this lead\n\nBest regards,\nJohn Doe';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }

    @IsTest 
    static void test_gmailDomainHandling() {
        createAiConfig();
        createAllowedFieldsCS();
        Test.setMock(HttpCalloutMock.class, new MockZApiSuccess());

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.fromAddress = 'user@gmail.com';
        email.subject = 'Gmail Lead';
        email.plainTextBody = 'Lead from gmail user';
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        Test.startTest();
        Messaging.InboundEmailResult res = new EmailToLeadService().handleInboundEmail(email, env);
        Test.stopTest();

        System.assertEquals(true, res.success);
    }
}