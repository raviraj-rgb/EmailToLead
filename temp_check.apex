// Test: try inserting 2 leads with same email to see if duplicate rules block or allow
Lead l1 = new Lead(LastName='TestDupCheck1', Company='TestCo', Email='testdupcheck99@example.com');
Lead l2 = new Lead(LastName='TestDupCheck2', Company='TestCo', Email='testdupcheck99@example.com');

Database.DMLOptions opts = new Database.DMLOptions();
opts.DuplicateRuleHeader.allowSave = false;
opts.DuplicateRuleHeader.runAsCurrentUser = true;

try {
    Database.SaveResult[] results = Database.insert(new List<Lead>{l1, l2}, opts);

    for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        if (sr.isSuccess()) {
            System.debug('Lead ' + i + ': SUCCESS - Id=' + sr.getId());
        } else {
            for (Database.Error e : sr.getErrors()) {
                System.debug('Lead ' + i + ': FAILED - ' + e.getStatusCode() + ' | ' + e.getMessage());
            }
        }
    }
} catch (Exception ex) {
    System.debug('EXCEPTION THROWN: ' + ex.getTypeName() + ' | ' + ex.getMessage());
    System.debug('This means optAllOrNone=true is causing entire batch to fail');
}

// Cleanup
List<Lead> cleanup = [SELECT Id FROM Lead WHERE Email='testdupcheck99@example.com'];
if (!cleanup.isEmpty()) {
    delete cleanup;
    System.debug('Cleaned up ' + cleanup.size() + ' test leads');
}
