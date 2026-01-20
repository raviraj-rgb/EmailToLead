trigger AI_Configure
on EmailToLead_Ai__AI_Configure__c (before insert, before update) {

    for (EmailToLead_Ai__AI_Configure__c cfg : Trigger.new) {

        if (String.isBlank(cfg.EmailToLead_Ai__Model__c)) {
            continue;
        }

        String modelName = cfg.EmailToLead_Ai__Model__c;

        // Get existing list custom setting row for this model (Name = model)
        EmailToLead_Ai__Ai_Configs__c cs =
            EmailToLead_Ai__Ai_Configs__c.getValues(modelName);

        if (cs == null) {
            cs = new EmailToLead_Ai__Ai_Configs__c();
            cs.Name = modelName; // key of the list custom setting row
        }

        // Always sync model + active flag
        cs.EmailToLead_Ai__Model_Name__c = modelName;
        cs.EmailToLead_Ai__Is_Active__c  = cfg.EmailToLead_Ai__isActive__c;

        // Only override when a value is present on the UI record
        if (!String.isBlank(cfg.EmailToLead_Ai__Endpoint__c)) {
            cs.EmailToLead_Ai__Endpoint__c = cfg.EmailToLead_Ai__Endpoint__c;
        }

        if (!String.isBlank(cfg.EmailToLead_Ai__Named_Credential__c)) {
            cs.EmailToLead_Ai__Named_Credential__c =
                cfg.EmailToLead_Ai__Named_Credential__c;
        }

        if (!String.isBlank(cfg.EmailToLead_Ai__Response_Content_Path__c)) {
            cs.EmailToLead_Ai__Response_Content_Path__c =
                cfg.EmailToLead_Ai__Response_Content_Path__c;
        }

        // Upsert this one row (per model)
        upsert cs;
    }
}