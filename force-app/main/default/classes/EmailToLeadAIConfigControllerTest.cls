@IsTest
private class EmailToLeadAIConfigControllerTest {

    @IsTest
    static void testGetActiveConfig_noActive_returnsNull() {
        // No EmailToLead_Ai__AI_Configure__c records created
        Test.startTest();
        EmailToLead_Ai__AI_Configure__c cfg = EmailToLeadAIConfigController.getActiveConfig();
        Test.stopTest();

        System.assertEquals(
            null,
            cfg,
            'When no active config exists, getActiveConfig should return null'
        );
    }

    @IsTest
    static void testGetActiveConfig_withActive_returnsRecord() {
        // Prepare one active custom setting so trigger passes
        Ai_Configs__c cs = new Ai_Configs__c(
            Name = 'glm-4.5-air',
            Is_Active__c = true,
            Model_Name__c = 'glm-4.5-air',
            Named_Credential__c = 'My_Named_Credential',
            Endpoint__c = 'https://api.example.com',
            Response_Content_Path__c = 'choices[0].message.content'
        );
        insert cs;

        // Prepare one active config record
        EmailToLead_Ai__AI_Configure__c existing = new EmailToLead_Ai__AI_Configure__c(
            Name = 'Existing Active',
            EmailToLead_Ai__isActive__c = true,
            EmailToLead_Ai__Model__c = 'glm-4.5-air',
            EmailToLead_Ai__System_prompt__c = 'sys prompt',
            EmailToLead_Ai__User_Prompt__c = 'user prompt'
        );
        insert existing;

        Test.startTest();
        EmailToLead_Ai__AI_Configure__c cfg = EmailToLeadAIConfigController.getActiveConfig();
        Test.stopTest();

        System.assertNotEquals(
            null,
            cfg,
            'getActiveConfig should return an active record when one exists'
        );
        System.assertEquals(
            existing.Id,
            cfg.Id,
            'Returned config should be the active one'
        );
        System.assertEquals(true, cfg.EmailToLead_Ai__isActive__c, 'Config should be active');
    }

    @IsTest
    static void testCreateDefaultConfig_whenNoExisting_createsNew() {
        // Insert custom setting first so validation rule passes
        EmailToLead_Ai__AI_Configs__c cs = new EmailToLead_Ai__AI_Configs__c(
            Name = 'Default',
            EmailToLead_Ai__Is_Active__c = true,
            EmailToLead_Ai__Model_Name__c = 'default-model',
            EmailToLead_Ai__Named_Credential__c = 'Test_NC',
            EmailToLead_Ai__Endpoint__c = 'https://api.example.com',
            EmailToLead_Ai__Response_Content_Path__c = 'choices[0].message.content'
        );
        insert cs;

        // No existing active configs
        Test.startTest();
        EmailToLead_Ai__AI_Configure__c created = EmailToLeadAIConfigController.createDefaultConfig();
        Test.stopTest();

        System.assertNotEquals(
            null,
            created,
            'createDefaultConfig should return a config'
        );
        System.assertNotEquals(
            null,
            created.Id,
            'Config should be inserted and have an Id'
        );
        System.assertEquals(
            true,
            created.EmailToLead_Ai__isActive__c,
            'Default config should be active'
        );
        System.assertEquals(
            'Default',
            created.Name,
            'Default config name should be "Default"'
        );
        System.assertEquals(
            null,
            created.EmailToLead_Ai__Response_Content_Path__c,
            'Default response content path should be null as not set by controller'
        );
        System.assertNotEquals(
            null,
            created.EmailToLead_Ai__System_prompt__c,
            'System prompt should be populated'
        );
        System.assertNotEquals(
            null,
            created.EmailToLead_Ai__User_Prompt__c,
            'User prompt should be populated'
        );
    }

    @IsTest
    static void testCreateDefaultConfig_whenExisting_returnsExisting() {
        // Prepare one active config
        EmailToLead_Ai__AI_Configure__c existing = new EmailToLead_Ai__AI_Configure__c(
            Name = 'Existing Active',
            EmailToLead_Ai__isActive__c = true
        );
        insert existing;

        Test.startTest();
        EmailToLead_Ai__AI_Configure__c result = EmailToLeadAIConfigController.createDefaultConfig();
        Test.stopTest();

        System.assertEquals(
            existing.Id,
            result.Id,
            'If an active config exists, createDefaultConfig should return it, not create new'
        );

        Integer countConfigs = [SELECT COUNT() FROM EmailToLead_Ai__AI_Configure__c];
        System.assertEquals(
            1,
            countConfigs,
            'No additional EmailToLead_Ai__AI_Configure__c records should be created when one is already active'
        );
    }

    @IsTest
    static void testGetActiveModels_returnsActiveProviders() {
        // Insert an active custom setting
        Ai_Configs__c cs = new Ai_Configs__c(
            Name = 'Mistral',
            Is_Active__c = true,
            Model_Name__c = 'mistral-large-latest',
            Named_Credential__c = 'Test_NC',
            Endpoint__c = 'https://api.example.com',
            Response_Content_Path__c = 'choices[0].message.content'
        );
        insert cs;

        Test.startTest();
        List<String> models = EmailToLeadAIConfigController.getActiveModels();
        Test.stopTest();

        System.assertNotEquals(null, models);
        System.assert(models.size() > 0, 'Should return at least one active model');
        System.assert(models.contains('Mistral'), 'Should contain Mistral');
    }

    @IsTest
    static void testGetActiveModels_noModels_returnsEmpty() {
        // No custom settings inserted
        Test.startTest();
        List<String> models = EmailToLeadAIConfigController.getActiveModels();
        Test.stopTest();

        System.assertNotEquals(null, models);
        System.assertEquals(0, models.size(), 'Should return empty list when no models exist');
    }
}