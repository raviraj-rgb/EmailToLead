// Check AI UI Config
List<EmailToLead_Ai__AI_Configure__c> uiCfgs = [
    SELECT Id, EmailToLead_Ai__Model__c, EmailToLead_Ai__Named_Credential__c,
           EmailToLead_Ai__isActive__c, EmailToLead_Ai__Response_Content_Path__c
    FROM EmailToLead_Ai__AI_Configure__c
];
for (EmailToLead_Ai__AI_Configure__c c : uiCfgs) {
    System.debug('UI Config: Model=' + c.EmailToLead_Ai__Model__c
        + ' | NamedCred=' + c.EmailToLead_Ai__Named_Credential__c
        + ' | Active=' + c.EmailToLead_Ai__isActive__c
        + ' | ResponsePath=' + c.EmailToLead_Ai__Response_Content_Path__c);
}
if (uiCfgs.isEmpty()) System.debug('NO UI CONFIG FOUND');

// Check API Configs (Custom Settings)
Map<String, EmailToLead_Ai__AI_Configs__c> apiCfgs = EmailToLead_Ai__AI_Configs__c.getAll();
for (String name : apiCfgs.keySet()) {
    EmailToLead_Ai__AI_Configs__c a = apiCfgs.get(name);
    System.debug('API Config [' + name + ']: ModelName=' + a.EmailToLead_Ai__Model_Name__c
        + ' | NamedCred=' + a.EmailToLead_Ai__Named_Credential__c
        + ' | ResponsePath=' + a.EmailToLead_Ai__Response_Content_Path__c);
}
if (apiCfgs.isEmpty()) System.debug('NO API CONFIGS FOUND');

// Check Named Credentials available
System.debug('--- Check Named Credentials in Setup > Named Credentials ---');

// Check exception record email data
List<EmailToLead_Ai__Custom_Exception__c> recs = [
    SELECT Id, EmailToLead_Ai__Email_Header__c, EmailToLead_Ai__Email_Body__c,
           EmailToLead_Ai__Exception_message__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    LIMIT 1
];
for (EmailToLead_Ai__Custom_Exception__c r : recs) {
    String header = r.EmailToLead_Ai__Email_Header__c;
    String body = r.EmailToLead_Ai__Email_Body__c;
    String msg = r.EmailToLead_Ai__Exception_message__c;
    System.debug('Email_Header__c (first 200): ' + (header != null && header.length() > 200 ? header.substring(0,200) : header));
    System.debug('Email_Body__c (first 200): ' + (body != null && body.length() > 200 ? body.substring(0,200) : body));
    System.debug('Full Error: ' + msg);
}
