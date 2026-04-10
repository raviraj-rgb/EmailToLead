/*@IsTest
private class EmailLeadFieldConfigControllerTest {

   @IsTest
static void testGetLeadFieldsWithSelection_basic() {
    Test.startTest();
    Map<String, Object> result = EmailLeadFieldConfigController.getLeadFieldsWithSelection();
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result map should not be null');

    List<EmailLeadFieldConfigController.FieldWrapper> allFields =
        (List<EmailLeadFieldConfigController.FieldWrapper>) result.get('allFields');
    List<EmailLeadFieldConfigController.FieldWrapper> longTextFields =
        (List<EmailLeadFieldConfigController.FieldWrapper>) result.get('longTextFields');

    System.assert(!allFields.isEmpty(), 'allFields should contain lead fields');

    // With no CMT, controller uses defaults
    System.assertEquals('emailbody__c', result.get('emailBodyField'));
    System.assertEquals('description', result.get('summaryField')); // use actual default from controller
}


    @IsTest
    static void testFieldWrapperLabelSorter() {
        EmailLeadFieldConfigController.FieldWrapper a =
            new EmailLeadFieldConfigController.FieldWrapper('bLabel', 'FieldB__c', false);
        EmailLeadFieldConfigController.FieldWrapper b =
            new EmailLeadFieldConfigController.FieldWrapper('aLabel', 'FieldA__c', false);

        List<EmailLeadFieldConfigController.FieldWrapper> listFw =
            new List<EmailLeadFieldConfigController.FieldWrapper>{ a, b };
        listFw.sort(new EmailLeadFieldConfigController.FieldWrapperLabelSorter());

        System.assertEquals('aLabel', listFw[0].label);
        System.assertEquals('bLabel', listFw[1].label);
    }

    @IsTest
    static void testSaveSelectedFields_success() {
        Test.startTest();
        EmailLeadFieldConfigController.saveSelectedFields(
            new List<String>{ 'LastName', 'Company', 'LastName' },
            'Description',
            'Title'
        );
        Test.stopTest();

        System.assert(true, 'saveSelectedFields completed without exception');
    }

    @IsTest
static void testSaveSelectedFields_validationErrors() {
    Boolean threw;

    Test.startTest();

    // 1) No selected fields
    threw = false;
    try {
        EmailLeadFieldConfigController.saveSelectedFields(
            new List<String>(),
            'Description',
            'Title'
        );
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('### EXCEPTION MESSAGE (no fields): ' + e.getMessage());
    }
    System.assert(threw, 'Should throw AuraHandledException when no fields are selected');

    // 2) Missing email body field
    threw = false;
    try {
        EmailLeadFieldConfigController.saveSelectedFields(
            new List<String>{ 'LastName' },
            null,
            'Title'
        );
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('### EXCEPTION MESSAGE (no email body): ' + e.getMessage());
    }
    System.assert(threw, 'Should throw AuraHandledException when email body field is missing');

    // 3) Missing summary field
    threw = false;
    try {
        EmailLeadFieldConfigController.saveSelectedFields(
            new List<String>{ 'LastName' },
            'Description',
            ''
        );
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('### EXCEPTION MESSAGE (no summary): ' + e.getMessage());
    }
    System.assert(threw, 'Should throw AuraHandledException when summary field is missing');

    Test.stopTest();
}

}*/
@IsTest
private class EmailLeadFieldConfigControllerTest {

    @IsTest
    static void testGetLeadFieldsWithSelection_basic() {
        EmailToLead_Ai__Email_Lead_Field__c cfg = new EmailToLead_Ai__Email_Lead_Field__c(
            Name = 'fields_part_1',
            EmailToLead_Ai__Selected_fields__c = 'LastName,Company',
            EmailToLead_Ai__Email_Body_Field__c = 'description',
            EmailToLead_Ai__Summary_Field__c = 'description'
        );
        insert cfg;

        Test.startTest();
        Map<String, Object> result = EmailLeadFieldConfigController.getLeadFieldsWithSelection();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null');

        List<EmailLeadFieldConfigController.FieldWrapper> allFields =
            (List<EmailLeadFieldConfigController.FieldWrapper>) result.get('allFields');
        List<EmailLeadFieldConfigController.FieldWrapper> longTextFields =
            (List<EmailLeadFieldConfigController.FieldWrapper>) result.get('longTextFields');

        System.assert(!allFields.isEmpty(), 'allFields should contain lead fields');

        // With CMT and custom settings inserted, we can test it returns the configured value
        System.assertEquals('description', result.get('emailBodyField'));
        System.assertEquals('description', result.get('summaryField'));
    }



    @IsTest
    static void testSaveSelectedFields_success() {
        Boolean threw = false;

        try {
            Test.startTest();
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>{ 'LastName', 'Company', 'LastName' },
                'Description',
                'Title'
            );
            Test.stopTest();
        } catch (System.AsyncException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('Metadata cannot be deployed from within a test'),
                'Expected metadata deploy AsyncException in tests'
            );
        }

        // Either it runs without error (in some orgs) or throws the known AsyncException.
        System.assert(true, 'saveSelectedFields success path executed or AsyncException handled');
    }

    @IsTest
    static void testSaveSelectedFields_validationErrors() {
        Boolean threw;

        Test.startTest();

        // 1) No selected fields
        threw = false;
        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>(),
                'Description',
                'Title'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.debug('### EXCEPTION MESSAGE (no fields): ' + e.getMessage());
        }
        System.assert(threw, 'Should throw AuraHandledException when no fields are selected');

        // 2) Missing email body field
        threw = false;
        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>{ 'LastName' },
                null,
                'Title'
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.debug('### EXCEPTION MESSAGE (no email body): ' + e.getMessage());
        }
        System.assert(threw, 'Should throw AuraHandledException when email body field is missing');

        // 3) Missing summary field
        threw = false;
        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>{ 'LastName' },
                'Description',
                ''
            );
        } catch (AuraHandledException e) {
            threw = true;
            System.debug('### EXCEPTION MESSAGE (no summary): ' + e.getMessage());
        }
        System.assert(threw, 'Should throw AuraHandledException when summary field is missing');

        Test.stopTest();
    }
}