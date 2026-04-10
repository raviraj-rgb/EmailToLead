List<EmailToLead_Ai__Custom_Exception__c> recs = [
    SELECT Id, Name, EmailToLead_Ai__Retry_Status__c, EmailToLead_Ai__Retry_Count__c,
           EmailToLead_Ai__Email_Header__c, EmailToLead_Ai__Email_Body__c,
           EmailToLead_Ai__Exception_message__c
    FROM EmailToLead_Ai__Custom_Exception__c
    WHERE EmailToLead_Ai__Retry_Status__c = 'Pending'
    ORDER BY CreatedDate DESC
    LIMIT 5
];
for (EmailToLead_Ai__Custom_Exception__c r : recs) {
    String header = r.EmailToLead_Ai__Email_Header__c;
    String body = r.EmailToLead_Ai__Email_Body__c;
    System.debug('Name=' + r.Name + ' | Status=' + r.EmailToLead_Ai__Retry_Status__c + ' | Count=' + r.EmailToLead_Ai__Retry_Count__c);
    System.debug('Header length=' + (header != null ? header.length() : 0));
    System.debug('Header content: ' + header);
    System.debug('Body length=' + (body != null ? body.length() : 0));
    System.debug('Body (first 300): ' + (body != null && body.length() > 300 ? body.substring(0,300) : body));
}
