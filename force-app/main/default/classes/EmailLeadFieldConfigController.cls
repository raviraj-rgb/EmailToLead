/*public with sharing class EmailLeadFieldConfigController {

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean isSelected;

        public FieldWrapper(String label, String apiName, Boolean isSelected) {
            this.label = label;
            this.apiName = apiName;
            this.isSelected = isSelected;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadFieldsWithSelection() {
        System.debug('### getLeadFieldsWithSelection() called');

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        System.debug('### All configs retrieved: ' + allConfigs.keySet());

        Set<String> selected = new Set<String>();
        String emailBodyField = null;
        String summaryField = null;

        for (String key : allConfigs.keySet()) {
            EmailToLead_Ai__Email_Lead_Field__c cfg = allConfigs.get(key);

            if (cfg != null && !String.isBlank(cfg.EmailToLead_Ai__Selected_fields__c)) {
                System.debug('### Processing record: ' + key +
                            ' with fields: ' + cfg.EmailToLead_Ai__Selected_fields__c);

                for (String f : cfg.EmailToLead_Ai__Selected_fields__c.split(',')) {
                    if (!String.isBlank(f)) {
                        selected.add(f.trim());
                    }
                }

                if (String.isBlank(emailBodyField) && !String.isBlank(cfg.EmailToLead_Ai__Email_Body_Field__c)) {
                    emailBodyField = cfg.EmailToLead_Ai__Email_Body_Field__c;
                }
                if (String.isBlank(summaryField) && !String.isBlank(cfg.EmailToLead_Ai__Summary_Field__c)) {
                    summaryField = cfg.EmailToLead_Ai__Summary_Field__c;
                }
            }
        }

        System.debug('### Combined selected fields: ' + selected);

        Map<String, Schema.SObjectField> leadFieldMap =
            Schema.SObjectType.Lead.fields.getMap();

        List<FieldWrapper> allFields = new List<FieldWrapper>();
        List<FieldWrapper> longTextFields = new List<FieldWrapper>();

        for (String apiName : leadFieldMap.keySet()) {
            Schema.DescribeFieldResult d = leadFieldMap.get(apiName).getDescribe();

            if (!d.isCreateable()) {
                continue;
            }

            Boolean isSelected = selected.contains(apiName);
            FieldWrapper fw = new FieldWrapper(d.getLabel(), apiName, isSelected);

            allFields.add(fw);

            if (d.getType() == Schema.DisplayType.TEXTAREA || d.getLength() > 255) {
                longTextFields.add(fw);
            }
        }

        allFields.sort(new FieldLabelSorter());
        longTextFields.sort(new FieldLabelSorter());

        Map<String, Object> result = new Map<String, Object>();
        result.put('allFields', allFields);
        result.put('longTextFields', longTextFields);
        result.put('emailBodyField', emailBodyField);
        result.put('summaryField', summaryField);

        return result;
    }

    @AuraEnabled
public static void saveSelectedFields(
    List<String> fieldApiNames,
    String emailBodyFieldApi,
    String summaryFieldApi
) {
    System.debug('### saveSelectedFields() called');

    if (fieldApiNames == null || fieldApiNames.isEmpty()) {
        throw new AuraHandledException('Please select at least one Lead field.');
    }

    if (String.isBlank(emailBodyFieldApi)) {
        throw new AuraHandledException('Please select a field to store the email body.');
    }

    if (String.isBlank(summaryFieldApi)) {
        throw new AuraHandledException('Please select a field to store the AI summary.');
    }

    Set<String> unique = new Set<String>();
    for (String f : fieldApiNames) {
        if (!String.isBlank(f)) {
            unique.add(f.trim());
        }
    }

    List<String> fieldsList = new List<String>(unique);
    System.debug('### Total unique fields: ' + fieldsList.size());

    // ===== SPLIT BY 200 CHARACTER LIMIT (MAX 3 PARTS) WITH 255 HARD LIMIT =====
    List<String> parts = new List<String>();
    String currentPart = '';
    Integer charLimit = 200;
    Integer hardLimit = 255;
    Integer maxParts = 3;

    for (String field : fieldsList) {
        String testString = String.isBlank(currentPart) ? field : currentPart + ',' + field;

        // Check if we can add to current part
        if (testString.length() <= charLimit && parts.size() < maxParts - 1) {
            // Field fits within 200 char target
            currentPart = testString;
        } else if (testString.length() <= hardLimit && parts.size() < maxParts - 1) {
            // Field exceeds 200 but fits within 255 hard limit
            currentPart = testString;
        } else if (parts.size() < maxParts - 1) {
            // Doesn't fit, save current part and start new one
            if (!String.isBlank(currentPart)) {
                parts.add(currentPart);
                System.debug('### Part ' + (parts.size()) + ' added: ' + currentPart + ' (length: ' + currentPart.length() + ')');
            }
            currentPart = field;
        } else {
            // We're on the last part (part 3), check hard limit
            String testStringLast = String.isBlank(currentPart) ? field : currentPart + ',' + field;
            
            if (testStringLast.length() <= hardLimit) {
                // Fits in hard limit
                if (!String.isBlank(currentPart)) {
                    currentPart = currentPart + ',' + field;
                } else {
                    currentPart = field;
                }
            } else {
                // EXCEEDS 255 char hard limit - ERROR
                throw new AuraHandledException(
                    'Too many fields selected. The last part would exceed 255 characters. ' +
                    'Please select fewer fields or remove some of the custom fields.'
                );
            }
        }
    }

    // Add last part
    if (!String.isBlank(currentPart)) {
        if (currentPart.length() > hardLimit) {
            throw new AuraHandledException(
                'Last part exceeds 255 character limit. Please select fewer fields.'
            );
        }
        parts.add(currentPart);
        System.debug('### Part ' + parts.size() + ' added: ' + currentPart + ' (length: ' + currentPart.length() + ')');
    }

    System.debug('### Total parts created: ' + parts.size());

    // ===== SAVE TO 3 RECORDS ONLY =====
    Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs = 
        EmailToLead_Ai__Email_Lead_Field__c.getAll();

    List<EmailToLead_Ai__Email_Lead_Field__c> recordsToUpsert = new List<EmailToLead_Ai__Email_Lead_Field__c>();

    for (Integer i = 0; i < maxParts; i++) {
        String partName = 'fields_part_' + (i + 1);
        
        EmailToLead_Ai__Email_Lead_Field__c cfg = null;
        
        if (allConfigs.containsKey(partName)) {
            cfg = allConfigs.get(partName);
        } else {
            cfg = new EmailToLead_Ai__Email_Lead_Field__c(Name = partName);
        }

        if (i < parts.size()) {
            cfg.EmailToLead_Ai__Selected_fields__c = parts[i];
            cfg.EmailToLead_Ai__Is_Active__c = true;
            System.debug('### ' + partName + ': ' + parts[i] + ' (length: ' + parts[i].length() + ')');
        } else {
            cfg.EmailToLead_Ai__Selected_fields__c = '';
            cfg.EmailToLead_Ai__Is_Active__c = false;
            System.debug('### ' + partName + ': CLEARED (not needed)');
        }

        cfg.EmailToLead_Ai__Email_Body_Field__c = emailBodyFieldApi;
        cfg.EmailToLead_Ai__Summary_Field__c = summaryFieldApi;

        recordsToUpsert.add(cfg);
    }

    try {
        upsert recordsToUpsert;
        System.debug('### ✅ All 3 field parts saved successfully');
    } catch (Exception ex) {
        System.debug('### ❌ ERROR: ' + ex.getMessage());
        throw new AuraHandledException('Error saving field configuration: ' + ex.getMessage());
    }
}



    @AuraEnabled(cacheable=true)
    public static List<String> getSelectedFields() {

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> all =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        List<String> result = new List<String>();
        Set<String> uniq = new Set<String>();

        // ✅ FIXED names
        List<String> names = new List<String>{ 'fields_part_1', 'fields_part_2', 'fields_part_3' };

        for (String name : names) {
            if (all.containsKey(name)) {
                String csv = all.get(name).EmailToLead_Ai__Selected_fields__c;
                if (!String.isBlank(csv)) {
                    for (String f : csv.split(',')) {
                        if (!String.isBlank(f)) {
                            uniq.add(f.trim());
                        }
                    }
                }
            }
        }

        result.addAll(uniq);
        result.sort();
        return result;
    }

    private class FieldLabelSorter implements Comparator<FieldWrapper> {
        public Integer compare(FieldWrapper a, FieldWrapper b) {
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        }
    }
}*/
/*public with sharing class EmailLeadFieldConfigController {

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean isSelected;

        public FieldWrapper(String label, String apiName, Boolean isSelected) {
            this.label = label;
            this.apiName = apiName;
            this.isSelected = isSelected;
        }
    }

    // ------------------------------------------------------------
    // Returns:
    //  allFields        -> all createable Lead fields + selected flag
    //  longTextFields   -> textarea or long fields (>255)
    //  emailBodyField   -> configured field to store email body
    //  summaryField     -> configured field to store summary
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadFieldsWithSelection() {

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (allConfigs == null) {
            allConfigs = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();
        }

        Set<String> selected = new Set<String>();
        String emailBodyField = null;
        String summaryField   = null;

        // Collect selected fields + emailBody/summary storage fields
        for (String key : allConfigs.keySet()) {
            EmailToLead_Ai__Email_Lead_Field__c cfg = allConfigs.get(key);

            if (cfg != null && !String.isBlank(cfg.EmailToLead_Ai__Selected_fields__c)) {

                for (String f : cfg.EmailToLead_Ai__Selected_fields__c.split(',')) {
                    if (!String.isBlank(f)) {
                        selected.add(f.trim());
                    }
                }

                if (String.isBlank(emailBodyField) && !String.isBlank(cfg.EmailToLead_Ai__Email_Body_Field__c)) {
                    emailBodyField = cfg.EmailToLead_Ai__Email_Body_Field__c;
                }
                if (String.isBlank(summaryField) && !String.isBlank(cfg.EmailToLead_Ai__Summary_Field__c)) {
                    summaryField = cfg.EmailToLead_Ai__Summary_Field__c;
                }
            }
        }

        Map<String, Schema.SObjectField> leadFieldMap =
            Schema.SObjectType.Lead.fields.getMap();

        List<FieldWrapper> allFields      = new List<FieldWrapper>();
        List<FieldWrapper> longTextFields = new List<FieldWrapper>();

        for (String apiName : leadFieldMap.keySet()) {

            Schema.DescribeFieldResult d = leadFieldMap.get(apiName).getDescribe();

            // only createable fields
            if (!d.isCreateable()) continue;

            Boolean isSelected = selected.contains(apiName);
            FieldWrapper fw = new FieldWrapper(d.getLabel(), apiName, isSelected);

            allFields.add(fw);

            // TextArea covers textarea fields; length > 255 catches long text / rich text
            Schema.DisplayType t = d.getType();
            if (t == Schema.DisplayType.TextArea || d.getLength() > 255) {
                longTextFields.add(fw);
            }
        }

        allFields.sort(new FieldLabelSorter());
        longTextFields.sort(new FieldLabelSorter());

        Map<String, Object> result = new Map<String, Object>();
        result.put('allFields', allFields);
        result.put('longTextFields', longTextFields);
        result.put('emailBodyField', emailBodyField);
        result.put('summaryField', summaryField);

        return result;
    }

    // ------------------------------------------------------------
    // Saves selected Lead fields into 3 custom setting records:
    // fields_part_1, fields_part_2, fields_part_3
    //
    // Splits CSV into max 3 parts:
    // preferred 200 char limit for first 2 parts
    // hard 255 char max for each part
    // ------------------------------------------------------------
    @AuraEnabled
    public static void saveSelectedFields(
        List<String> fieldApiNames,
        String emailBodyFieldApi,
        String summaryFieldApi
    ) {

        if (fieldApiNames == null || fieldApiNames.isEmpty()) {
            throw new AuraHandledException('Please select at least one Lead field.');
        }
        if (String.isBlank(emailBodyFieldApi)) {
            throw new AuraHandledException('Please select a field to store the email body.');
        }
        if (String.isBlank(summaryFieldApi)) {
            throw new AuraHandledException('Please select a field to store the AI summary.');
        }

        // Unique + stable order
        Set<String> unique = new Set<String>();
        for (String f : fieldApiNames) {
            if (!String.isBlank(f)) unique.add(f.trim());
        }

        List<String> fieldsList = new List<String>(unique);
        fieldsList.sort();

        Integer preferredLimit = 200;
        Integer hardLimit = 255;
        Integer maxParts = 3;

        List<String> parts = new List<String>();
        String current = '';

        for (String field : fieldsList) {

            String candidate = String.isBlank(current) ? field : current + ',' + field;

            // Fill first 2 parts with preferred/hard limits
            if (candidate.length() <= preferredLimit && parts.size() < maxParts - 1) {
                current = candidate;
                continue;
            }
            if (candidate.length() <= hardLimit && parts.size() < maxParts - 1) {
                current = candidate;
                continue;
            }

            // Push current part and start new
            if (!String.isBlank(current)) {
                parts.add(current);
            }
            current = field;

            // If we are on last part, enforce hard limit strictly
            if (parts.size() == maxParts - 1 && current.length() > hardLimit) {
                throw new AuraHandledException(
                    'Too many fields selected. Please select fewer fields (limit exceeded 255 characters).'
                );
            }
        }

        // Add last part
        if (!String.isBlank(current)) {
            if (current.length() > hardLimit) {
                throw new AuraHandledException(
                    'Too many fields selected. Please select fewer fields (limit exceeded 255 characters).'
                );
            }
            parts.add(current);
        }

        if (parts.size() > maxParts) {
            throw new AuraHandledException('Too many fields selected. Please select fewer fields.');
        }

        // ===== SAVE TO 3 RECORDS ONLY =====
        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (allConfigs == null) {
            allConfigs = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();
        }

        List<EmailToLead_Ai__Email_Lead_Field__c> recordsToUpsert =
            new List<EmailToLead_Ai__Email_Lead_Field__c>();

        for (Integer i = 0; i < maxParts; i++) {

            String partName = 'fields_part_' + (i + 1);
            EmailToLead_Ai__Email_Lead_Field__c cfg;

            if (allConfigs.containsKey(partName)) {
                cfg = allConfigs.get(partName);
            } else {
                cfg = new EmailToLead_Ai__Email_Lead_Field__c(Name = partName);
            }

            if (i < parts.size()) {
                cfg.EmailToLead_Ai__Selected_fields__c = parts[i];
                cfg.EmailToLead_Ai__Is_Active__c = true;
            } else {
                cfg.EmailToLead_Ai__Selected_fields__c = '';
                cfg.EmailToLead_Ai__Is_Active__c = false;
            }

            cfg.EmailToLead_Ai__Email_Body_Field__c = emailBodyFieldApi;
            cfg.EmailToLead_Ai__Summary_Field__c    = summaryFieldApi;

            recordsToUpsert.add(cfg);
        }

        try {
            upsert recordsToUpsert;
        } catch (Exception ex) {
            throw new AuraHandledException('Error saving field configuration: ' + ex.getMessage());
        }
    }

    // ------------------------------------------------------------
    // Returns unique selected fields from parts 1/2/3
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<String> getSelectedFields() {

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> all =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (all == null) all = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();

        Set<String> uniq = new Set<String>();
        List<String> names = new List<String>{ 'fields_part_1', 'fields_part_2', 'fields_part_3' };

        for (String name : names) {
            if (all.containsKey(name)) {
                String csv = all.get(name).EmailToLead_Ai__Selected_fields__c;
                if (!String.isBlank(csv)) {
                    for (String f : csv.split(',')) {
                        if (!String.isBlank(f)) uniq.add(f.trim());
                    }
                }
            }
        }

        List<String> result = new List<String>(uniq);
        result.sort();
        return result;
    }

    // ------------------------------------------------------------
    // Comparator: sort by label
    // ------------------------------------------------------------
    private class FieldLabelSorter implements Comparator<FieldWrapper> {
        public Integer compare(FieldWrapper a, FieldWrapper b) {
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;

            String la = (a.label == null) ? '' : a.label.toLowerCase();
            String lb = (b.label == null) ? '' : b.label.toLowerCase();
            return la.compareTo(lb);
        }
    }
}*/
public with sharing class EmailLeadFieldConfigController {

    public class FieldWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean isSelected;

        public FieldWrapper(String label, String apiName, Boolean isSelected) {
            this.label = label;
            this.apiName = apiName;
            this.isSelected = isSelected;
        }
    }

    // ------------------------------------------------------------
    // Returns:
    //  allFields        -> all createable Lead fields + selected flag
    //  longTextFields   -> textarea or long fields (>255)
    //  emailBodyField   -> configured field to store email body
    //  summaryField     -> configured field to store summary
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadFieldsWithSelection() {

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (allConfigs == null) {
            allConfigs = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();
        }

        Set<String> selected = new Set<String>();
        String emailBodyField = null;
        String summaryField   = null;

        // Collect selected fields + emailBody/summary storage fields
        for (String key : allConfigs.keySet()) {
            EmailToLead_Ai__Email_Lead_Field__c cfg = allConfigs.get(key);

            if (cfg != null && !String.isBlank(cfg.EmailToLead_Ai__Selected_fields__c)) {

                for (String f : cfg.EmailToLead_Ai__Selected_fields__c.split(',')) {
                    if (!String.isBlank(f)) {
                        selected.add(f.trim());
                    }
                }

                if (String.isBlank(emailBodyField) && !String.isBlank(cfg.EmailToLead_Ai__Email_Body_Field__c)) {
                    emailBodyField = cfg.EmailToLead_Ai__Email_Body_Field__c;
                }
                if (String.isBlank(summaryField) && !String.isBlank(cfg.EmailToLead_Ai__Summary_Field__c)) {
                    summaryField = cfg.EmailToLead_Ai__Summary_Field__c;
                }
            }
        }

        Map<String, Schema.SObjectField> leadFieldMap =
            Schema.SObjectType.Lead.fields.getMap();

        List<FieldWrapper> allFields      = new List<FieldWrapper>();
        List<FieldWrapper> longTextFields = new List<FieldWrapper>();

        for (String apiName : leadFieldMap.keySet()) {

            Schema.DescribeFieldResult d = leadFieldMap.get(apiName).getDescribe();

            // only createable fields
            if (!d.isCreateable()) continue;

            Boolean isSelected = selected.contains(apiName);
            FieldWrapper fw = new FieldWrapper(d.getLabel(), apiName, isSelected);

            allFields.add(fw);

            // TextArea covers textarea fields; length > 255 catches long text / rich text
            Schema.DisplayType t = d.getType();
            if (t == Schema.DisplayType.TextArea || d.getLength() > 255) {
                longTextFields.add(fw);
            }
        }

        allFields.sort(new FieldLabelSorter());
        longTextFields.sort(new FieldLabelSorter());

        Map<String, Object> result = new Map<String, Object>();
        result.put('allFields', allFields);
        result.put('longTextFields', longTextFields);
        result.put('emailBodyField', emailBodyField);
        result.put('summaryField', summaryField);

        return result;
    }

    // ------------------------------------------------------------
    // Saves selected Lead fields into 10 custom setting records:
    // fields_part_1 through fields_part_10
    //
    // Splits CSV into max 10 parts:
    // preferred 200 char limit for first 9 parts
    // hard 255 char max for each part
    // ------------------------------------------------------------
    @AuraEnabled
    public static void saveSelectedFields(
        List<String> fieldApiNames,
        String emailBodyFieldApi,
        String summaryFieldApi
    ) {

        if (fieldApiNames == null || fieldApiNames.isEmpty()) {
            throw new AuraHandledException('Please select at least one Lead field.');
        }
        if (String.isBlank(emailBodyFieldApi)) {
            throw new AuraHandledException('Please select a field to store the email body.');
        }
        if (String.isBlank(summaryFieldApi)) {
            throw new AuraHandledException('Please select a field to store the AI summary.');
        }

        // Unique + stable order
        Set<String> unique = new Set<String>();
        for (String f : fieldApiNames) {
            if (!String.isBlank(f)) unique.add(f.trim());
        }

        List<String> fieldsList = new List<String>(unique);
        fieldsList.sort();

        Integer preferredLimit = 200;
        Integer hardLimit = 255;
        Integer maxParts = 10; // Increased from 3 to 10 for more fields

        List<String> parts = new List<String>();
        String current = '';

        for (String field : fieldsList) {

            String candidate = String.isBlank(current) ? field : current + ',' + field;

            // Fill first 9 parts with preferred/hard limits
            if (candidate.length() <= preferredLimit && parts.size() < maxParts - 1) {
                current = candidate;
                continue;
            }
            if (candidate.length() <= hardLimit && parts.size() < maxParts - 1) {
                current = candidate;
                continue;
            }

            // Push current part and start new
            if (!String.isBlank(current)) {
                parts.add(current);
            }
            current = field;

            // If we are on last part, enforce hard limit strictly
            if (parts.size() == maxParts - 1 && current.length() > hardLimit) {
                throw new AuraHandledException(
                    'Too many fields selected. Please select fewer fields (limit exceeded 255 characters).'
                );
            }
        }

        // Add last part
        if (!String.isBlank(current)) {
            if (current.length() > hardLimit) {
                throw new AuraHandledException(
                    'Too many fields selected. Please select fewer fields (limit exceeded 255 characters).'
                );
            }
            parts.add(current);
        }

        if (parts.size() > maxParts) {
            throw new AuraHandledException('Too many fields selected. Please select fewer fields.');
        }

        // ===== SAVE TO 10 RECORDS =====
        Map<String, EmailToLead_Ai__Email_Lead_Field__c> allConfigs =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (allConfigs == null) {
            allConfigs = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();
        }

        List<EmailToLead_Ai__Email_Lead_Field__c> recordsToUpsert =
            new List<EmailToLead_Ai__Email_Lead_Field__c>();

        for (Integer i = 0; i < maxParts; i++) {

            String partName = 'fields_part_' + (i + 1);
            EmailToLead_Ai__Email_Lead_Field__c cfg;

            if (allConfigs.containsKey(partName)) {
                cfg = allConfigs.get(partName);
            } else {
                cfg = new EmailToLead_Ai__Email_Lead_Field__c(Name = partName);
            }

            if (i < parts.size()) {
                cfg.EmailToLead_Ai__Selected_fields__c = parts[i];
                cfg.EmailToLead_Ai__Is_Active__c = true;
            } else {
                cfg.EmailToLead_Ai__Selected_fields__c = '';
                cfg.EmailToLead_Ai__Is_Active__c = false;
            }

            cfg.EmailToLead_Ai__Email_Body_Field__c = emailBodyFieldApi;
            cfg.EmailToLead_Ai__Summary_Field__c    = summaryFieldApi;

            recordsToUpsert.add(cfg);
        }

        try {
            upsert recordsToUpsert;
        } catch (Exception ex) {
            throw new AuraHandledException('Error saving field configuration: ' + ex.getMessage());
        }
    }

    // ------------------------------------------------------------
    // Returns unique selected fields from parts 1-10
    // ------------------------------------------------------------
    @AuraEnabled(cacheable=true)
    public static List<String> getSelectedFields() {

        Map<String, EmailToLead_Ai__Email_Lead_Field__c> all =
            EmailToLead_Ai__Email_Lead_Field__c.getAll();

        if (all == null) all = new Map<String, EmailToLead_Ai__Email_Lead_Field__c>();

        Set<String> uniq = new Set<String>();
        // Support up to 10 parts for more fields
        List<String> names = new List<String>();
        for (Integer i = 1; i <= 10; i++) {
            names.add('fields_part_' + i);
        }

        for (String name : names) {
            if (all.containsKey(name)) {
                String csv = all.get(name).EmailToLead_Ai__Selected_fields__c;
                if (!String.isBlank(csv)) {
                    for (String f : csv.split(',')) {
                        if (!String.isBlank(f)) uniq.add(f.trim());
                    }
                }
            }
        }

        List<String> result = new List<String>(uniq);
        result.sort();
        return result;
    }

    // ------------------------------------------------------------
    // Comparator: sort by label
    // ------------------------------------------------------------
    private class FieldLabelSorter implements Comparator<FieldWrapper> {
        public Integer compare(FieldWrapper a, FieldWrapper b) {
            if (a == null && b == null) return 0;
            if (a == null) return -1;
            if (b == null) return 1;

            String la = (a.label == null) ? '' : a.label.toLowerCase();
            String lb = (b.label == null) ? '' : b.label.toLowerCase();
            return la.compareTo(lb);
        }
    }
}