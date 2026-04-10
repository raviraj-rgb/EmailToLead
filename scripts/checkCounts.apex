Integer exc = [SELECT COUNT() FROM EmailToLead_Ai__Custom_Exception__c];
Integer leads = [SELECT COUNT() FROM Lead];
System.debug('Custom Exception records: ' + exc);
System.debug('Lead records: ' + leads);
