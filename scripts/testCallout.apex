// Direct callout test to Mistral Named Credential
try {
    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint('callout:EmailToLead_Ai__Mistral');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(30000);
    req.setBody('{"model":"mistral-large-latest","messages":[{"role":"user","content":"Say hello"}]}');

    HttpResponse res = new Http().send(req);
    System.debug('STATUS: ' + res.getStatusCode());
    System.debug('BODY: ' + res.getBody().substring(0, Math.min(500, res.getBody().length())));
} catch (Exception ex) {
    System.debug('ERROR: ' + ex.getMessage());
    System.debug('TYPE: ' + ex.getTypeName());
}

// Also try without namespace prefix
try {
    HttpRequest req2 = new HttpRequest();
    req2.setMethod('POST');
    req2.setEndpoint('callout:Mistral');
    req2.setHeader('Content-Type', 'application/json');
    req2.setTimeout(30000);
    req2.setBody('{"model":"mistral-large-latest","messages":[{"role":"user","content":"Say hello"}]}');

    HttpResponse res2 = new Http().send(req2);
    System.debug('WITHOUT PREFIX STATUS: ' + res2.getStatusCode());
    System.debug('WITHOUT PREFIX BODY: ' + res2.getBody().substring(0, Math.min(500, res2.getBody().length())));
} catch (Exception ex2) {
    System.debug('WITHOUT PREFIX ERROR: ' + ex2.getMessage());
    System.debug('WITHOUT PREFIX TYPE: ' + ex2.getTypeName());
}
