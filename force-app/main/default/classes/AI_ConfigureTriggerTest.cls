@IsTest
public class AI_ConfigureTriggerTest {

    private static String getValidModel() {
        List<Schema.PicklistEntry> vals =
            EmailToLead_Ai__AI_Configure__c.EmailToLead_Ai__Model__c
                .getDescribe()
                .getPicklistValues();

        System.assert(vals.size() > 0, 'No picklist values configured');

        for (Schema.PicklistEntry p : vals) {
            if (p.getValue() == 'glm-4.5-air') return p.getValue();
        }
        return vals[0].getValue();
    }

    private static EmailToLead_Ai__Ai_Configs__c fetchCSFromDB(String modelKey) {
        List<EmailToLead_Ai__Ai_Configs__c> rows = [
            SELECT
                Id, Name,
                EmailToLead_Ai__Model_Name__c,
                EmailToLead_Ai__Is_Active__c,
                EmailToLead_Ai__Named_Credential__c,
                EmailToLead_Ai__Endpoint__c,
                EmailToLead_Ai__Response_Content_Path__c
            FROM EmailToLead_Ai__Ai_Configs__c
            WHERE Name = :modelKey
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    @IsTest
    static void test_beforeInsert_createsCustomSettingRow() {
        String model = getValidModel();

        Test.startTest();

        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c();
        cfg.EmailToLead_Ai__Model__c = model;
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Named_Credential__c = 'EmailToLead_Ai__zApi';
        // Avoid Endpoint as per your requirement

        insert cfg;

        Test.stopTest();

        // ✅ IMPORTANT: verify by SOQL, not getValues()
        EmailToLead_Ai__Ai_Configs__c cs = fetchCSFromDB(model);

        System.assertNotEquals(null, cs, 'Trigger should create CS row');
        System.assertEquals(model, cs.Name, 'CS key should be model name');
        System.assertEquals(model, cs.EmailToLead_Ai__Model_Name__c, 'Model name must be copied');
        System.assertEquals(true, cs.EmailToLead_Ai__Is_Active__c, 'Active flag must sync');
        System.assertEquals('EmailToLead_Ai__zApi', cs.EmailToLead_Ai__Named_Credential__c,
            'Named Credential must sync');
    }

    @IsTest
    static void test_beforeUpdate_updatesCustomSettingRow() {
        String model = getValidModel();

        // Insert initial config
        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c();
        cfg.EmailToLead_Ai__Model__c = model;
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Named_Credential__c = 'EmailToLead_Ai__zApi';
        insert cfg;

        Test.startTest();

        cfg.EmailToLead_Ai__isActive__c = false;
        update cfg;

        Test.stopTest();

        // ✅ DB query
        EmailToLead_Ai__Ai_Configs__c cs = fetchCSFromDB(model);

        System.assertNotEquals(null, cs, 'CS row must exist');
        System.assertEquals(model, cs.EmailToLead_Ai__Model_Name__c, 'Model name must remain');
        System.assertEquals(false, cs.EmailToLead_Ai__Is_Active__c, 'Active flag should update');
    }

    @IsTest
    static void test_blankModel_skipsTriggerLogic() {
        Integer beforeCount = [SELECT COUNT() FROM EmailToLead_Ai__Ai_Configs__c];

        Test.startTest();

        EmailToLead_Ai__AI_Configure__c cfg = new EmailToLead_Ai__AI_Configure__c();
        cfg.EmailToLead_Ai__Model__c = null; // should hit continue
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Named_Credential__c = 'EmailToLead_Ai__zApi';
        insert cfg;

        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM EmailToLead_Ai__Ai_Configs__c];
        System.assertEquals(beforeCount, afterCount, 'No CS row should be created');
    }
}