/*trigger AI_Configure on EmailToLead_Ai__AI_Configure__c (before insert, before update) {
     

     if (!TriggerRecursionGuard.canRun('AI_Configure')) {
        return;
    }
    // Load Ai Configs Custom Setting (key = Name = Model)
    Map<String, EmailToLead_Ai__Ai_Configs__c> cfgByModel =
        EmailToLead_Ai__Ai_Configs__c.getAll();

    for (EmailToLead_Ai__AI_Configure__c rec : Trigger.new) {

        if (String.isBlank(rec.EmailToLead_Ai__Model__c)) {
            continue;
        }

        // Sync only when:
        // - Insert
        // - Model changed
        // - Old model was blank and new model is filled
        Boolean shouldSync = Trigger.isInsert;

        if (Trigger.isUpdate) {
            EmailToLead_Ai__AI_Configure__c oldRec = Trigger.oldMap.get(rec.Id);

            String oldModel = oldRec != null ? oldRec.EmailToLead_Ai__Model__c : null;
            String newModel = rec.EmailToLead_Ai__Model__c;

            shouldSync = (oldModel != newModel);
        }

        if (!shouldSync) {
            continue;
        }

        String selectedModel = rec.EmailToLead_Ai__Model__c.trim();
        EmailToLead_Ai__Ai_Configs__c cs = cfgByModel.get(selectedModel);

        // Validate model exists in custom settings
        if (cs == null) {
            rec.addError('No AI Config exists in Ai Configs custom setting for model: ' + selectedModel);
            continue;
        }

        // Validate model active
        if (!cs.EmailToLead_Ai__Is_Active__c) {
            rec.addError('Selected model is inactive in Ai Configs custom setting: ' + selectedModel);
            continue;
        }

        // Validate required runtime values
        if (String.isBlank(cs.EmailToLead_Ai__Named_Credential__c)) {
            rec.addError('Named Credential missing in Ai Configs for model: ' + selectedModel);
            continue;
        }

        if (String.isBlank(cs.EmailToLead_Ai__Endpoint__c)) {
            rec.addError('Endpoint missing in Ai Configs for model: ' + selectedModel);
            continue;
        }

        if (String.isBlank(cs.EmailToLead_Ai__Response_Content_Path__c)) {
            rec.addError('Response Content Path missing in Ai Configs for model: ' + selectedModel);
            continue;
        }

        // Populate hidden fields in AI Configure record
        rec.EmailToLead_Ai__Named_Credential__c      = cs.EmailToLead_Ai__Named_Credential__c;
        rec.EmailToLead_Ai__Endpoint__c              = cs.EmailToLead_Ai__Endpoint__c;
        rec.EmailToLead_Ai__Response_Content_Path__c = cs.EmailToLead_Ai__Response_Content_Path__c;
    }
}*/
trigger AI_Configure on EmailToLead_Ai__AI_Configure__c (before insert, before update) {

    // Load all Custom Setting rows
    Map<String, EmailToLead_Ai__Ai_Configs__c> csAll =
        EmailToLead_Ai__Ai_Configs__c.getAll();

    for (EmailToLead_Ai__AI_Configure__c cfg : Trigger.new) {

        if (String.isBlank(cfg.EmailToLead_Ai__Model__c)) continue;

        Boolean modelChanged = Trigger.isInsert;
        if (Trigger.isUpdate) {
            EmailToLead_Ai__AI_Configure__c oldCfg = Trigger.oldMap.get(cfg.Id);
            modelChanged = oldCfg != null &&
                oldCfg.EmailToLead_Ai__Model__c != cfg.EmailToLead_Ai__Model__c;
        }
        if (!modelChanged) continue;

        String modelName = cfg.EmailToLead_Ai__Model__c.trim();

        EmailToLead_Ai__Ai_Configs__c cs = csAll.get(modelName);
        if (cs == null) {
            cfg.addError('No AI Config found in Custom Setting for model: ' + modelName);
            continue;
        }

        if (!cs.EmailToLead_Ai__Is_Active__c) {
            cfg.addError('Selected model is inactive in Custom Setting: ' + modelName);
            continue;
        }

        // ✅ Only assign Named Credential + Response Path
        cfg.EmailToLead_Ai__Named_Credential__c = cs.EmailToLead_Ai__Named_Credential__c;
        cfg.EmailToLead_Ai__Response_Content_Path__c = cs.EmailToLead_Ai__Response_Content_Path__c;

        // ✅ Endpoint is NOT required because NC contains full URL
        cfg.EmailToLead_Ai__Endpoint__c = null;
    }
}