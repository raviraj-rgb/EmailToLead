// Tiny request to check if Mistral rate limit has reset
try {
    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint('callout:EmailToLead_Ai__Mistral');
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(15000);
    req.setBody('{"model":"mistral-large-latest","messages":[{"role":"user","content":"hi"}]}');

    HttpResponse res = new Http().send(req);
    System.debug('STATUS: ' + res.getStatusCode());
    System.debug('BODY: ' + res.getBody().substring(0, Math.min(300, res.getBody().length())));

    // Check rate limit headers
    String[] headers = new String[]{
        'x-ratelimit-limit-requests',
        'x-ratelimit-remaining-requests',
        'x-ratelimit-limit-tokens',
        'x-ratelimit-remaining-tokens',
        'x-ratelimit-reset-requests',
        'x-ratelimit-reset-tokens',
        'retry-after'
    };
    for (String h : headers) {
        String val = res.getHeader(h);
        if (val != null) {
            System.debug('HEADER ' + h + ': ' + val);
        }
    }
} catch (Exception ex) {
    System.debug('ERROR: ' + ex.getMessage());
}
