@IsTest
private class EmailToLeadAIConfigControllerTest {

    @testSetup
    static void setup() { 
        // No active config inserted here so createDefaultConfig() will create one
    }
 
    @IsTest
    static void testCreateDefaultConfigCreatesRecord() {
        Test.startTest();
        EmailToLead_Ai__AI_Configure__c cfg = EmailToLeadAIConfigController.createDefaultConfig();
        Test.stopTest();

        System.assertNotEquals(null, cfg, 'Config should not be null after creation');

        // Re‑query to verify values actually persisted
        EmailToLead_Ai__AI_Configure__c insertedCfg = [
            SELECT Id,
                   Name,
                   EmailToLead_Ai__isActive__c,
                   EmailToLead_Ai__System_prompt__c,
                   EmailToLead_Ai__User_Prompt__c,
                   EmailToLead_Ai__Response_Content_Path__c
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE Id = :cfg.Id
        ];

        System.assertEquals('Default', insertedCfg.Name, 'Default name should be set');
        System.assertEquals(true, insertedCfg.EmailToLead_Ai__isActive__c, 'Config must be active');
        System.assertEquals('choices[0].message.content',
                            insertedCfg.EmailToLead_Ai__Response_Content_Path__c,
                            'Default response content path must match');

        // Basic sanity on prompts: non‑null and contain key phrases
        System.assertNotEquals(null, insertedCfg.EmailToLead_Ai__System_prompt__c,
                               'System prompt must be populated');
        System.assert(insertedCfg.EmailToLead_Ai__System_prompt__c.contains('Salesforce Lead Extractor'),
                      'System prompt should mention Salesforce Lead Extractor');

        System.assertNotEquals(null, insertedCfg.EmailToLead_Ai__User_Prompt__c,
                               'User prompt must be populated');
        System.assert(insertedCfg.EmailToLead_Ai__User_Prompt__c.contains('{ALLOWED_FIELDS}'),
                      'User prompt should contain {ALLOWED_FIELDS} placeholder');
        System.assert(insertedCfg.EmailToLead_Ai__User_Prompt__c.contains('{EMAIL_BODY}'),
                      'User prompt should contain {EMAIL_BODY} placeholder');
    }

    @IsTest
    static void testCreateDefaultConfigWhenActiveExists() {
        // Insert an active config record first
        EmailToLead_Ai__AI_Configure__c existing = new EmailToLead_Ai__AI_Configure__c(
            Name = 'Existing',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__System_prompt__c = 'Existing system prompt',
            EmailToLead_Ai__User_Prompt__c = 'Existing user prompt',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content'
        );
        insert existing;

        Test.startTest();
        EmailToLead_Ai__AI_Configure__c returnedCfg = EmailToLeadAIConfigController.createDefaultConfig();
        Test.stopTest();

        // Method should return the existing active config and not create a new one
        System.assertEquals(existing.Id, returnedCfg.Id, 'Existing active config should be returned');

        Integer countActive = [
            SELECT COUNT()
            FROM EmailToLead_Ai__AI_Configure__c
            WHERE EmailToLead_Ai__isActive__c = true
        ];
        System.assertEquals(1, countActive, 'There should still be only one active config');
    }

    @IsTest
    static void testGetActiveConfig() {
        // Ensure we have a known active record
        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c(
            Name = 'Active Config',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__System_prompt__c = 'System prompt',
            EmailToLead_Ai__User_Prompt__c = 'User prompt',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content'
        );
        insert cfg;

        Test.startTest();
        EmailToLead_Ai__AI_Configure__c activeCfg = EmailToLeadAIConfigController.getActiveConfig();
        Test.stopTest();

        System.assertNotEquals(null, activeCfg, 'Active config should not be null');
        System.assertEquals(cfg.Id, activeCfg.Id, 'getActiveConfig should return the active config');
        System.assertEquals(true, activeCfg.EmailToLead_Ai__isActive__c, 'Returned config must be active');
    }
}