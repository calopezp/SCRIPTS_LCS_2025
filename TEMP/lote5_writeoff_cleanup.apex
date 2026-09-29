// ============================================================
//  LOTE 5 -- 30 invoices, contrato Cancelled, write-off CN activa.
//  4 pasos por invoice, validado uno por uno:
//    1. Void Credit Note  (POST /credit_notes/{id}/void)
//    2. Re-chequear el Invoice -> confirmar que ya NO es 'paid'
//    3. Void Invoice        (POST /invoices/{id}/void)
//    4. Validar Subscription Cancelled + Contract Cancelled (SF)
//
//  Nota usada en AMBOS voids (CN e Invoice): "Contract Cancellation (WOff)"
//  (conocido: la CN no muestra esta nota en su propio timeline de
//  comentarios -- Chargebee solo genera su mensaje de sistema ahi;
//  el Invoice si la muestra como "Reason for voiding: ...")
//  Named Credential: Chargebee_API (confirmado 2026-09-15)
// ============================================================

String NAMED_CRED = 'Chargebee_API';
String NOTE = 'Contract Cancellation (WOff)';

Map<String, String> pairs = new Map<String, String>{
    '7627' => 'CN-378',
    '1052' => 'CN-377',
    '3238' => 'CN-376',
    '3288' => 'CN-375',
    '5400' => 'CN-374',
    '5518' => 'CN-373',
    '7788' => 'CN-372',
    '7947' => 'CN-371',
    '7621' => 'CN-370',
    '7736' => 'CN-369',
    '4174' => 'CN-368',
    '6077' => 'CN-367',
    '6453' => 'CN-366',
    '8456' => 'CN-365',
    '746' => 'CN-359',
    '761' => 'CN-358',
    '4288' => 'CN-357',
    '4321' => 'CN-356',
    '744' => 'CN-355',
    '2362' => 'CN-354',
    '345' => 'CN-353',
    '351' => 'CN-352',
    '766' => 'CN-351',
    '769' => 'CN-350',
    '7859' => 'CN-348',
    '1007' => 'CN-347',
    '1017' => 'CN-346',
    '3305' => 'CN-345',
    '3377' => 'CN-344',
    '5472' => 'CN-343'
};

public class StepResult {
    public String invoiceId;
    public String creditNoteId;
    public String contractNumber;
    public String step1_voidCN;
    public String step2_invoiceStatusAfterCN;
    public String step3_voidInvoice;
    public String step4_subscriptionStatus;
    public String step4_contractStatus;
    public String finalOutcome;
    public String detail;
}

List<StepResult> results = new List<StepResult>();

Map<String, chargebeeapps__CB_Invoice__c> invByCbId = new Map<String, chargebeeapps__CB_Invoice__c>();
for (chargebeeapps__CB_Invoice__c inv : [
        SELECT Id, chargebeeapps__CB_Invoice_Id__c, Contract__r.ContractNumber, Contract__r.Status,
               chargebeeapps__SubscriptionId__r.chargebeeapps__Subscription_status__c
        FROM chargebeeapps__CB_Invoice__c
        WHERE chargebeeapps__CB_Invoice_Id__c IN :pairs.keySet()]) {
    invByCbId.put(inv.chargebeeapps__CB_Invoice_Id__c, inv);
}

for (String invId : pairs.keySet()) {
    String cnId = pairs.get(invId);
    StepResult r = new StepResult();
    r.invoiceId = invId;
    r.creditNoteId = cnId;

    chargebeeapps__CB_Invoice__c invRec = invByCbId.get(invId);
    r.contractNumber = invRec != null ? invRec.Contract__r.ContractNumber : '???';

    try {
        HttpRequest req1 = new HttpRequest();
        req1.setEndpoint('callout:' + NAMED_CRED + '/api/v2/credit_notes/'
            + EncodingUtil.urlEncode(cnId, 'UTF-8') + '/void');
        req1.setMethod('POST');
        req1.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req1.setBody('comment=' + EncodingUtil.urlEncode(NOTE, 'UTF-8'));
        req1.setTimeout(60000);
        HttpResponse res1 = new Http().send(req1);

        if (res1.getStatusCode() != 200) {
            r.step1_voidCN = 'ERROR';
            r.finalOutcome = 'ERROR_STEP1';
            r.detail = 'HTTP ' + res1.getStatusCode() + ' - ' + res1.getBody();
            results.add(r);
            continue;
        }
        Map<String, Object> body1 = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
        Map<String, Object> cnBody = (Map<String, Object>) body1.get('credit_note');
        r.step1_voidCN = 'OK (status=' + cnBody.get('status') + ')';

        HttpRequest req2 = new HttpRequest();
        req2.setEndpoint('callout:' + NAMED_CRED + '/api/v2/invoices/' + EncodingUtil.urlEncode(invId, 'UTF-8'));
        req2.setMethod('GET');
        req2.setTimeout(60000);
        HttpResponse res2 = new Http().send(req2);
        Map<String, Object> body2 = (Map<String, Object>) JSON.deserializeUntyped(res2.getBody());
        Map<String, Object> invBody = (Map<String, Object>) body2.get('invoice');
        String statusAfterCN = (String) invBody.get('status');
        r.step2_invoiceStatusAfterCN = statusAfterCN;

        if (statusAfterCN == 'paid' || statusAfterCN == 'voided') {
            r.step3_voidInvoice = 'SKIPPED';
            r.finalOutcome = statusAfterCN == 'voided' ? 'YA_ESTABA_VOIDED' : 'NEEDS_REVIEW_SIGUE_PAID';
            r.detail = 'Invoice sigue en status=' + statusAfterCN + ' tras anular la CN.';
            results.add(r);
            continue;
        }

        HttpRequest req3 = new HttpRequest();
        req3.setEndpoint('callout:' + NAMED_CRED + '/api/v2/invoices/'
            + EncodingUtil.urlEncode(invId, 'UTF-8') + '/void');
        req3.setMethod('POST');
        req3.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req3.setBody('comment=' + EncodingUtil.urlEncode(NOTE, 'UTF-8'));
        req3.setTimeout(60000);
        HttpResponse res3 = new Http().send(req3);

        if (res3.getStatusCode() != 200) {
            r.step3_voidInvoice = 'ERROR';
            r.finalOutcome = 'ERROR_STEP3';
            r.detail = 'HTTP ' + res3.getStatusCode() + ' - ' + res3.getBody();
            results.add(r);
            continue;
        }
        Map<String, Object> body3 = (Map<String, Object>) JSON.deserializeUntyped(res3.getBody());
        Map<String, Object> invBody3 = (Map<String, Object>) body3.get('invoice');
        r.step3_voidInvoice = 'OK (status=' + invBody3.get('status') + ')';

        r.step4_subscriptionStatus = invRec != null
            ? invRec.chargebeeapps__SubscriptionId__r.chargebeeapps__Subscription_status__c
            : 'NO_ENCONTRADO';
        r.step4_contractStatus = invRec != null ? invRec.Contract__r.Status : 'NO_ENCONTRADO';

        Boolean subOk = r.step4_subscriptionStatus == 'CANCELLED';
        Boolean contractOk = r.step4_contractStatus == 'Cancelled';
        r.finalOutcome = (subOk && contractOk) ? 'OK_COMPLETO' : 'OK_PERO_REVISAR_SUB_O_CONTRATO';
        r.detail = 'Ciclo completo.';

    } catch (Exception e) {
        r.finalOutcome = 'EXCEPTION';
        r.detail = e.getMessage() + ' (linea ' + e.getLineNumber() + ')';
    }

    results.add(r);
}

String SEP = '｜'; // separador visual (fullwidth vertical bar) -- evita el ruido de &#124; que deja el "|" normal en el Debug log

List<String> lines = new List<String>();
lines.add('LOTEHEADER5');
Integer okCount = 0, reviewCount = 0, errorCount = 0;
for (StepResult r : results) {
    lines.add('ROW' + SEP + r.invoiceId + SEP + r.creditNoteId + SEP + r.contractNumber
        + SEP + r.step1_voidCN + SEP + r.step2_invoiceStatusAfterCN + SEP + r.step3_voidInvoice
        + SEP + r.step4_subscriptionStatus + SEP + r.step4_contractStatus
        + SEP + r.finalOutcome + SEP + r.detail);
    if (r.finalOutcome == 'OK_COMPLETO') okCount++;
    else if (r.finalOutcome == 'ERROR_STEP1' || r.finalOutcome == 'ERROR_STEP3' || r.finalOutcome == 'EXCEPTION') errorCount++;
    else reviewCount++;
}
System.debug('LOTESUMMARY5' + SEP + 'OK=' + okCount + SEP + 'REVISAR=' + reviewCount + SEP + 'ERROR=' + errorCount + SEP + 'TOTAL=' + results.size());
for (String ln : lines) {
    System.debug('LOTEDATA5' + SEP + ln);
}
