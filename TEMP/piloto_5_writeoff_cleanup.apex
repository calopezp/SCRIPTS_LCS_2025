// ============================================================
//  PILOTO — 5 invoices, contrato Cancelled, write-off CN activa.
//  4 pasos por invoice, validado uno por uno:
//    1. Void Credit Note  (POST /credit_notes/{id}/void)
//    2. Re-chequear el Invoice -> confirmar que ya NO es 'paid'
//    3. Void Invoice        (POST /invoices/{id}/void)
//    4. Validar Subscription Cancelled + Contract Cancelled (SF)
//
//  Nota usada en AMBOS voids (CN e Invoice): "Contract Cancellation (WOff)"
//  Named Credential: Chargebee_API (confirmado 2026-09-15)
// ============================================================

String NAMED_CRED = 'Chargebee_API';
String NOTE = 'Contract Cancellation (WOff)';

// invoice_id -> credit_note_id (los 5 del piloto)
Map<String, String> pilotPairs = new Map<String, String>{
    '9300' => 'CN-484',
    '2512' => 'CN-483',
    '4625' => 'CN-482',
    '6940' => 'CN-481',
    '9346' => 'CN-480'
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

// Contract/Subscription lookup vía Salesforce (una sola query para los 5)
Map<String, chargebeeapps__CB_Invoice__c> invByCbId = new Map<String, chargebeeapps__CB_Invoice__c>();
for (chargebeeapps__CB_Invoice__c inv : [
        SELECT Id, chargebeeapps__CB_Invoice_Id__c, Contract__r.ContractNumber, Contract__r.Status,
               chargebeeapps__SubscriptionId__r.chargebeeapps__Subscription_status__c
        FROM chargebeeapps__CB_Invoice__c
        WHERE chargebeeapps__CB_Invoice_Id__c IN :pilotPairs.keySet()]) {
    invByCbId.put(inv.chargebeeapps__CB_Invoice_Id__c, inv);
}

for (String invId : pilotPairs.keySet()) {
    String cnId = pilotPairs.get(invId);
    StepResult r = new StepResult();
    r.invoiceId = invId;
    r.creditNoteId = cnId;

    chargebeeapps__CB_Invoice__c invRec = invByCbId.get(invId);
    r.contractNumber = invRec != null ? invRec.Contract__r.ContractNumber : '???';

    try {
        // ── PASO 1: Void Credit Note ──────────────────────────
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

        // ── PASO 2: Re-chequear el Invoice ────────────────────
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
            r.detail = 'Invoice sigue en status=' + statusAfterCN + ' tras anular la CN — no se fuerza el void.';
            results.add(r);
            continue;
        }

        // ── PASO 3: Void Invoice ──────────────────────────────
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

        // ── PASO 4: Validar Subscription + Contract (Salesforce) ──
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
        r.detail = e.getMessage() + ' (línea ' + e.getLineNumber() + ')';
    }

    results.add(r);
}

// ── REPORTE ──────────────────────────────────────────────────
List<String> lines = new List<String>();
lines.add('═══════════════════════════════════════════════════');
lines.add('PILOTO WRITE-OFF CLEANUP — 5 INVOICES');
lines.add('═══════════════════════════════════════════════════');
for (StepResult r : results) {
    lines.add('');
    lines.add('Invoice ' + r.invoiceId + ' / ' + r.creditNoteId + ' / Contrato ' + r.contractNumber);
    lines.add('  Paso 1 (Void CN):            ' + r.step1_voidCN);
    lines.add('  Paso 2 (Invoice tras CN):    ' + r.step2_invoiceStatusAfterCN);
    lines.add('  Paso 3 (Void Invoice):       ' + r.step3_voidInvoice);
    lines.add('  Paso 4 (Subscription):       ' + r.step4_subscriptionStatus);
    lines.add('  Paso 4 (Contract):           ' + r.step4_contractStatus);
    lines.add('  RESULTADO FINAL:             ' + r.finalOutcome);
    lines.add('  Detalle:                     ' + r.detail);
}
lines.add('');
lines.add('═══════════════════════════════════════════════════');
System.debug('PILOTREPORT|' + String.join(lines, '\n'));
