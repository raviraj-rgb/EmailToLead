// Test full lead extraction callout — same as what the service sends
try {
    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint('callout:EmailToLead_Ai__Mistral');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(120000);
    req.setBody('{"model":"mistral-large-latest","messages":[{"role":"user","content":"Extract lead: Pastor Rocky Loyce, Sunridge Church, setfreetem@roadrunner.com, 9515250055, 42299 Winchester Rd Temecula CA 92590. Return JSON with firstname, lastname, company, email, phone, city, state, street, postalcode."}]}');

    HttpResponse res = new Http().send(req);
    System.debug('STATUS: ' + res.getStatusCode());
    String body = res.getBody();
    System.debug('BODY: ' + (body.length() > 500 ? body.substring(0,500) : body));

    // Check rate limit headers
    for (String h : new String[]{'x-ratelimit-limit-requests','x-ratelimit-remaining-requests','x-ratelimit-limit-tokens','x-ratelimit-remaining-tokens','retry-after'}) {
        String val = res.getHeader(h);
        if (val != null) System.debug('HEADER ' + h + ': ' + val);
    }
} catch (Exception ex) {
    System.debug('ERROR: ' + ex.getMessage());
}
