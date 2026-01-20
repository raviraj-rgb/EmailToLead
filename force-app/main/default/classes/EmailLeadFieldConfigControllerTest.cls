@IsTest
private class EmailLeadFieldConfigControllerTest {

    // ---------------------------------------------------------------------
    // Utility: Get all creatable Lead fields
    // ---------------------------------------------------------------------
    private static List<String> getCreatableLeadFields() {
        Map<String, Schema.SObjectField> leadFieldMap = Schema.SObjectType.Lead.fields.getMap();
        List<String> apiNames = new List<String>();

        for (String apiName : leadFieldMap.keySet()) {
            Schema.DescribeFieldResult d = leadFieldMap.get(apiName).getDescribe();
            if (d.isCreateable()) {
                apiNames.add(apiName);
            }
        }
        apiNames.sort();
        return apiNames;
    }

    // ---------------------------------------------------------------------
    // ✅ Build a "large enough" list that triggers split, but never exceeds 255
    // This method auto-finds a safe max list.
    // ---------------------------------------------------------------------
    private static List<String> buildSafeLargeSelection() {
        List<String> allFields = getCreatableLeadFields();

        // Fallback
        if (allFields.isEmpty()) {
            return new List<String>{'LastName','Company'};
        }

        // We build progressively; lastGood is always valid.
        List<String> candidate = new List<String>();
        List<String> lastGood = new List<String>();

        for (String f : allFields) {
            candidate.add(f);

            try {
                // Attempt save with current candidate
                EmailLeadFieldConfigController.saveSelectedFields(
                    candidate,
                    'Description',
                    'Description'
                );
                // If no exception => store as last good
                lastGood = new List<String>(candidate);

            } catch (AuraHandledException ex) {
                // Too many selected => break and return last good
                System.debug('### Hit limit at size=' + candidate.size() + ' msg=' + ex.getMessage());
                break;
            }
        }

        // Always ensure we have something
        if (lastGood.isEmpty()) {
            lastGood.addAll(new List<String>{'LastName','Company'});
        }
        return lastGood;
    }

    // ---------------------------------------------------------------------
    // ✅ 1) getLeadFieldsWithSelection() should return payload
    // ---------------------------------------------------------------------
    @IsTest
    static void test_getLeadFieldsWithSelection_success() {
        Test.startTest();

        Map<String, Object> result = EmailLeadFieldConfigController.getLeadFieldsWithSelection();
        System.assertNotEquals(null, result);

        System.assert(result.containsKey('allFields'));
        System.assert(result.containsKey('longTextFields'));
        System.assert(result.containsKey('emailBodyField'));
        System.assert(result.containsKey('summaryField'));

        Test.stopTest();
    }

    // ---------------------------------------------------------------------
    // ✅ 2) saveSelectedFields() -> empty list error
    // ---------------------------------------------------------------------
    @IsTest
    static void test_saveSelectedFields_noFields_error() {
        Test.startTest();
        Boolean thrown = false;

        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>(),
                'Description',
                'Description'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
            System.debug('### Exception: ' + ex.getMessage());
        }

        System.assertEquals(true, thrown);
        Test.stopTest();
    }

    // ---------------------------------------------------------------------
    // ✅ 3) missing email body field
    // ---------------------------------------------------------------------
    @IsTest
    static void test_saveSelectedFields_missingEmailBody_error() {
        Test.startTest();
        Boolean thrown = false;

        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>{ 'LastName', 'Email' },
                null,
                'Description'
            );
        } catch (AuraHandledException ex) {
            thrown = true;
            System.debug('### Exception: ' + ex.getMessage());
        }

        System.assertEquals(true, thrown);
        Test.stopTest();
    }

    // ---------------------------------------------------------------------
    // ✅ 4) missing summary field
    // ---------------------------------------------------------------------
    @IsTest
    static void test_saveSelectedFields_missingSummary_error() {
        Test.startTest();
        Boolean thrown = false;

        try {
            EmailLeadFieldConfigController.saveSelectedFields(
                new List<String>{ 'LastName', 'Email' },
                'Description',
                ''
            );
        } catch (AuraHandledException ex) {
            thrown = true;
            System.debug('### Exception: ' + ex.getMessage());
        }

        System.assertEquals(true, thrown);
        Test.stopTest();
    }

    // ---------------------------------------------------------------------
    // ✅ 5) SUCCESS path: big selection but safe (split logic covered)
    // ---------------------------------------------------------------------
    @IsTest
    static void test_saveSelectedFields_success_largeSelection() {
        Test.startTest();

        List<String> manyFields = buildSafeLargeSelection();

        // Now call final time inside test for coverage
        EmailLeadFieldConfigController.saveSelectedFields(
            manyFields,
            'Description',
            'Description'
        );

        Test.stopTest();

        List<String> selected = EmailLeadFieldConfigController.getSelectedFields();
        System.assert(selected != null && selected.size() > 0, 'Selected fields should be returned');
    }

    // ---------------------------------------------------------------------
    // ✅ 6) getSelectedFields safe
    // ---------------------------------------------------------------------
    @IsTest
    static void test_getSelectedFields_safe() {
        Test.startTest();
        List<String> selected = EmailLeadFieldConfigController.getSelectedFields();
        System.assertNotEquals(null, selected);
        Test.stopTest();
    }
}