// ============================================================
//  TEST de solo lectura: consulta directa a la API de Chargebee
//  (GET /api/v2/credit_notes?reference_invoice_id[is]=<id>)
//  para validar el endpoint antes de correrlo contra los 390
//  invoices del analisis de write-off.
//
//  Named Credential confirmado por scripts/apex/-VoidInvoicesChargebee.apex
//  (2026-09-15): 'Chargebee_API'. ID a usar en la URL:
//  chargebeeapps__CB_Invoice_Id__c (no CB_Id__c).
// ============================================================

String NAMED_CRED = 'Chargebee_API';
String testInvoiceId = '1231'; // conocido: CN-256 (write off $25) y CN-244 (write off $100)

HttpRequest req = new HttpRequest();
req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/credit_notes?reference_invoice_id[is]='
    + EncodingUtil.urlEncode(testInvoiceId, 'UTF-8'));
req.setMethod('GET');
req.setTimeout(60000);

Http http = new Http();
HttpResponse res = http.send(req);

System.debug('=== STATUS: ' + res.getStatusCode() + ' ===');
System.debug('=== BODY ===');
System.debug(res.getBody());
