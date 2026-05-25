trigger AI_Configure
on EmailToLead_Ai__AI_Configure__c (before insert, before update) {

    // Pre-fetch all configs to avoid multiple lookups/queries in the loop
    Map<String, EmailToLead_Ai__Ai_Configs__c> allConfigs = EmailToLead_Ai__Ai_Configs__c.getAll();

    for (EmailToLead_Ai__AI_Configure__c cfg : Trigger.new) {

        if (String.isBlank(cfg.EmailToLead_Ai__Model__c)) {
            continue;
        }

        String modelName = cfg.EmailToLead_Ai__Model__c;
        EmailToLead_Ai__Ai_Configs__c targetCS = null;

        // 1. Try exact Name match (fastest lookup)
        if (allConfigs.containsKey(modelName)) {
            targetCS = allConfigs.get(modelName);
        } else {
            // 2. Try matching by the unique Model_Name__c field
            for (EmailToLead_Ai__Ai_Configs__c cs : allConfigs.values()) {
                if (cs.EmailToLead_Ai__Model_Name__c == modelName) {
                    targetCS = cs;
                    break;
                }
            }
        }

        // 3. Create new if still not found
        if (targetCS == null) {
            targetCS = new EmailToLead_Ai__Ai_Configs__c();
            targetCS.Name = modelName; // Use modelName as key for new records
        }

        // Always sync model + active flag
        targetCS.EmailToLead_Ai__Model_Name__c = modelName;
        targetCS.EmailToLead_Ai__Is_Active__c  = cfg.EmailToLead_Ai__isActive__c;

        // Only override when a value is present on the UI record
        if (!String.isBlank(cfg.EmailToLead_Ai__Endpoint__c)) {
            targetCS.EmailToLead_Ai__Endpoint__c = cfg.EmailToLead_Ai__Endpoint__c;
        }

        if (!String.isBlank(cfg.EmailToLead_Ai__Named_Credential__c)) {
            targetCS.EmailToLead_Ai__Named_Credential__c =
                cfg.EmailToLead_Ai__Named_Credential__c;
        }

        if (!String.isBlank(cfg.EmailToLead_Ai__Response_Content_Path__c)) {
            targetCS.EmailToLead_Ai__Response_Content_Path__c =
                cfg.EmailToLead_Ai__Response_Content_Path__c;
        }

        // Upsert this one row (per model)
        upsert targetCS;
    }
}