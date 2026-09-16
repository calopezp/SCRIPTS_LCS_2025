// ============================================================
//  Anula (void) en Chargebee, vía API, los INVOICEs pendientes
//  de un lote de contratos marcados para cancelar.
//
//  Reemplaza el paso manual:
//    1. Abrir el Contract, listar sus chargebeeapps__CB_Invoice__c
//       con Status NOT IN ('VOIDED','PAID','NOT_PAID')
//    2. Ir a https://harmoneyllc.chargebee.com/d/invoices/<id>
//    3. Click "Void this invoice" \u2192 confirmar
//  ...por una llamada directa a la API de Chargebee
//  (POST /api/v2/invoices/{invoice-id}/void), una vez por invoice
//  (Chargebee no tiene endpoint de bulk void — hay que iterar).
//
//  Requisitos ANTES de correr en modo real (modoDryRun = false):
//   1. Named Credential — CONFIRMADO 2026-09-15: "Chargebee_API"
//      es el API Name correcto (probado con un invoice real,
//      void exitoso end-to-end vía este script).
//   2. ID real de Chargebee usado en la URL/API — CONFIRMADO
//      2026-09-15 con un caso real (invoice 6012): coincide con
//      chargebeeapps__CB_Invoice_Id__c (y también con el Name del
//      registro, pero se usa CB_Invoice_Id__c por ser el campo
//      explícito). chargebeeapps__CB_Id__c es OTRO campo (Id
//      interno del conector, idLookup/unique) — NO usar ese para
//      la URL/API, aunque parecía el candidato obvio.
//
//  Autor: Carlos Lopez / Claude Code — SEPTIEMBRE 2026
// ============================================================

// ---------------- CONFIG ----------------
Boolean modoDryRun   = false;   // true = solo simula/lista, no llama a Chargebee ni actualiza nada — 1ra pasada del lote completo: dejar en true
String  NAMED_CRED   = 'Chargebee_API';           // confirmado 2026-09-15
String  VOID_COMMENT = 'CONTRACT CANCELLED';
Set<String> ESTADOS_A_OMITIR = new Set<String>{ 'VOIDED', 'PAID' }; // mismo criterio manual actual

// Lote completo: COLLECTIONS/ACH_REPORTADOS/Contratos_para_Cancelar_LOG.csv (479 contratos, 2026-09-15)
Set<String> contractNumbers = new Set<String>{
    '00317762'
};
// -----------------------------------------

public class VoidResult {
    public String  contractNumber;
    public String  invoiceName;
    public String  cbInvoiceId;
    public String  statusBefore;
    public String  outcome;   // DRY_RUN / VOIDED / SKIPPED_NO_ID / API_ERROR / EXCEPTION
    public String  detail;
}

List<VoidResult> results = new List<VoidResult>();

// ── 1. Cargar invoices candidatos ──────────────────────────
List<chargebeeapps__CB_Invoice__c> invoices = [
    SELECT Id, Name, chargebeeapps__CB_Invoice_Id__c, chargebeeapps__Status__c,
           Contract__c, Contract__r.ContractNumber
    FROM   chargebeeapps__CB_Invoice__c
    WHERE  Contract__r.ContractNumber IN :contractNumbers
      AND  chargebeeapps__Status__c NOT IN :ESTADOS_A_OMITIR
];

System.debug('\u2192 Invoices candidatos a VOID: ' + invoices.size());

if (invoices.size() > 80) {
    System.debug('\u2192 ⚠️ ALERTA: ' + invoices.size()
        + ' invoices en un solo run. El límite de Salesforce es 100 callouts/transacción '
        + 'y 120s de tiempo total de callout — dividir la lista de contractNumbers en lotes más chicos.');
}

// ── 2. Procesar uno por uno (Chargebee no tiene bulk void) ──
List<chargebeeapps__CB_Invoice__c> toUpdateLocal = new List<chargebeeapps__CB_Invoice__c>();

for (chargebeeapps__CB_Invoice__c inv : invoices) {
    VoidResult r      = new VoidResult();
    r.contractNumber  = inv.Contract__r.ContractNumber;
    r.invoiceName     = inv.Name;
    r.cbInvoiceId     = inv.chargebeeapps__CB_Invoice_Id__c;
    r.statusBefore    = inv.chargebeeapps__Status__c;

    if (String.isBlank(inv.chargebeeapps__CB_Invoice_Id__c)) {
        r.outcome = 'SKIPPED_NO_ID';
        r.detail  = 'chargebeeapps__CB_Invoice_Id__c vacío — no se puede armar el endpoint de Chargebee.';
        results.add(r);
        continue;
    }

    if (modoDryRun) {
        r.outcome = 'DRY_RUN';
        r.detail  = 'Se anularía vía POST /api/v2/invoices/' + inv.chargebeeapps__CB_Invoice_Id__c + '/void';
        results.add(r);
        continue;
    }

    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/invoices/'
            + EncodingUtil.urlEncode(inv.chargebeeapps__CB_Invoice_Id__c, 'UTF-8') + '/void');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('comment=' + EncodingUtil.urlEncode(VOID_COMMENT, 'UTF-8'));
        req.setTimeout(60000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> invBody = (Map<String, Object>) body.get('invoice');
            String newStatus = invBody != null ? (String) invBody.get('status') : null;
            r.outcome = 'VOIDED';
            r.detail  = 'Chargebee status = ' + newStatus;

            inv.chargebeeapps__Status__c = 'VOIDED';
            toUpdateLocal.add(inv);
        } else {
            r.outcome = 'API_ERROR';
            r.detail  = 'HTTP ' + res.getStatusCode() + ' — ' + res.getBody();
        }
    } catch (Exception e) {
        r.outcome = 'EXCEPTION';
        r.detail  = e.getMessage() + ' (línea ' + e.getLineNumber() + ')';
    }

    results.add(r);
}

// ── 3. Reflejar el VOIDED en Salesforce de inmediato ────────
// (el conector debería sincronizarlo solo en su próxima corrida;
//  esto sólo adelanta ese reflejo para no depender de esa cadencia)
if (!toUpdateLocal.isEmpty() && !modoDryRun) {
    Database.SaveResult[] saves = Database.update(toUpdateLocal, false);
    for (Integer i = 0; i < saves.size(); i++) {
        if (!saves[i].isSuccess()) {
            System.debug('\u2192 ⚠️ No se pudo reflejar VOIDED localmente en '
                + toUpdateLocal[i].Name + ': ' + saves[i].getErrors());
        }
    }
}

// ── 4. Reporte ───────────────────────────────────────────────
Integer ok = 0, fail = 0, skip = 0;
List<String> lines = new List<String>();
lines.add('\u2192 ══════════════════════════════════════════════════════');
lines.add('\u2192 REPORTE VOID INVOICES CHARGEBEE ' + (modoDryRun ? '(DRY RUN)' : '(EJECUCIÓN REAL)'));
lines.add('\u2192 ══════════════════════════════════════════════════════');
for (VoidResult r : results) {
    lines.add('\u2192 [' + r.outcome + '] Contrato ' + r.contractNumber
        + ' ▫ Invoice ' + r.invoiceName + ' (CB Id: ' + r.cbInvoiceId + ')'
        + ' ▫ Status previo: ' + r.statusBefore
        + ' ▫ ' + r.detail);
    if (r.outcome == 'VOIDED' || r.outcome == 'DRY_RUN') ok++;
    else if (r.outcome == 'SKIPPED_NO_ID') skip++;
    else fail++;
}
lines.add('\u2192 ══════════════════════════════════════════════════════');
lines.add('\u2192 OK: ' + ok + '   Fallidos: ' + fail + '   Sin ID: ' + skip);
lines.add('\u2192 ══════════════════════════════════════════════════════');
System.debug('\u2192 \n' + String.join(lines, '\n'));
