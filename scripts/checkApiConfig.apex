// Check active AI config
EmailToLead_Ai__AI_Configure__c cfg = [
    SELECT Id, Name, EmailToLead_Ai__Model__c, EmailToLead_Ai__Named_Credential__c,
           EmailToLead_Ai__Response_Content_Path__c, EmailToLead_Ai__Scheduler_Retry_Hours__c
    FROM EmailToLead_Ai__AI_Configure__c
    WHERE EmailToLead_Ai__isActive__c = true
    LIMIT 1
];
System.debug('Active Config: Model=' + cfg.EmailToLead_Ai__Model__c + ' | NC=' + cfg.EmailToLead_Ai__Named_Credential__c + ' | RetryHours=' + cfg.EmailToLead_Ai__Scheduler_Retry_Hours__c);

// Check Ai_Configs custom setting for active models
List<EmailToLead_Ai__Ai_Configs__c> models = EmailToLead_Ai__Ai_Configs__c.getAll().values();
for (EmailToLead_Ai__Ai_Configs__c m : models) {
    System.debug('Model: ' + m.Name + ' | Active=' + m.EmailToLead_Ai__Is_Active__c + ' | NC=' + m.EmailToLead_Ai__Named_Credential__c + ' | ModelName=' + m.EmailToLead_Ai__Model_Name__c);
}
