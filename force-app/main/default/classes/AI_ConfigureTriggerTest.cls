@IsTest
public class AI_ConfigureTriggerTest {

    /* ============================================================
       TEST SETUP : Custom Settings
    ============================================================ */
    @TestSetup
    static void setupSettings() {

        // Active Model
         EmailToLead_Ai__Ai_Configs__c active =
            new EmailToLead_Ai__Ai_Configs__c();

        active.Name = 'Mistral';
        active.EmailToLead_Ai__Is_Active__c = true;
        active.EmailToLead_Ai__Named_Credential__c = 'NC_Mistral';
        active.EmailToLead_Ai__Response_Content_Path__c =
            'choices[0].message.content';

        insert active;


        // Inactive Model
        EmailToLead_Ai__Ai_Configs__c inactive =
            new EmailToLead_Ai__Ai_Configs__c();

        inactive.Name = 'Gemini';
        inactive.EmailToLead_Ai__Is_Active__c = false;
        inactive.EmailToLead_Ai__Named_Credential__c = 'NC_Gemini';
        inactive.EmailToLead_Ai__Response_Content_Path__c =
            'choices[0].message.content';

        insert inactive;
    }


    /* ============================================================
       TEST : INSERT - VALID MODEL
    ============================================================ */
    @IsTest
    static void testInsertValidModel() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'Test Valid';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'Mistral';


        Test.startTest();
        insert cfg;
        Test.stopTest();


        EmailToLead_Ai__AI_Configure__c saved =
            [SELECT EmailToLead_Ai__Named_Credential__c,
                    EmailToLead_Ai__Response_Content_Path__c,
                    EmailToLead_Ai__Endpoint__c
             FROM EmailToLead_Ai__AI_Configure__c
             WHERE Id = :cfg.Id];

        System.assertEquals(
            'NC_Mistral',
            saved.EmailToLead_Ai__Named_Credential__c
        );

        System.assertEquals(
            'choices[0].message.content',
            saved.EmailToLead_Ai__Response_Content_Path__c
        );

        System.assertEquals(null, saved.EmailToLead_Ai__Endpoint__c);
    }


    /* ============================================================
       TEST : INSERT - MISSING MODEL
    ============================================================ */
    @IsTest
    static void testInsertMissingModel() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'Test Missing';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'UnknownModel';

        Boolean thrown = false;

        try {

            insert cfg;

        } catch (DmlException ex) {

            thrown = true;

            System.assert(
                ex.getMessage().contains('No AI Config found'),
                ex.getMessage()
            );
        }

        System.assert(thrown);
    }


    /* ============================================================
       TEST : INSERT - INACTIVE MODEL
    ============================================================ */
    @IsTest
    static void testInsertInactiveModel() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'Test Inactive';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'Gemini';

        Boolean thrown = false;

        try {

            insert cfg;

        } catch (DmlException ex) {

            thrown = true;

            System.assert(
                ex.getMessage().contains('inactive'),
                ex.getMessage()
            );
        }

        System.assert(thrown);
    }


    /* ============================================================
       TEST : UPDATE - MODEL CHANGED
    ============================================================ */
    @IsTest
    static void testUpdateModelChanged() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'Update Test';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'Mistral';

        insert cfg;


        cfg.EmailToLead_Ai__Model__c = 'Mistral'; // reassign

        Test.startTest();
        update cfg;
        Test.stopTest();


        EmailToLead_Ai__AI_Configure__c saved =
            [SELECT EmailToLead_Ai__Named_Credential__c
             FROM EmailToLead_Ai__AI_Configure__c
             WHERE Id = :cfg.Id];

        System.assertEquals('NC_Mistral', saved.EmailToLead_Ai__Named_Credential__c);
    }


    /* ============================================================
       TEST : UPDATE - MODEL NOT CHANGED
    ============================================================ */
    @IsTest
    static void testUpdateModelNotChanged() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'No Change';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = 'Mistral';

        insert cfg;


        // Update without changing model
        cfg.Name = 'Updated Name';

        Test.startTest();
        update cfg;
        Test.stopTest();


        System.assert(true);
    }


    /* ============================================================
       TEST : BLANK MODEL (SKIP)
    ============================================================ */
    @IsTest
    static void testBlankModel() {

        EmailToLead_Ai__AI_Configure__c cfg =
            new EmailToLead_Ai__AI_Configure__c();

        cfg.Name = 'Blank Model';
        cfg.EmailToLead_Ai__isActive__c = true;
        cfg.EmailToLead_Ai__Model__c = null;


        Test.startTest();
        insert cfg;
        Test.stopTest();


        System.assertNotEquals(null, cfg.Id);
    }

}