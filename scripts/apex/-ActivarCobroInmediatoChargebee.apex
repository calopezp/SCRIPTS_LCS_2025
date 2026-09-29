// ============================================================
//  NO USAR -- DEPRECADO 2026-09-28. Ver hallazgo de esa fecha.
//
//  Este script disparaba POST .../collect_payment, que SÍ ejecuta un
//  cargo real e inmediato contra la tarjeta (confirmado -- no es un
//  simple "activar" pasivo). El usuario aclaró que lo que hace falta
//  es solo PROGRAMAR una fecha de cobro (para que Comercial decida
//  cuándo apretar el botón real), nunca disparar el cobro nosotros
//  mismos -- ver memoria feedback_chargebee_activar_vs_cobrar.
//
//  Se investigó el mecanismo real de "programar" en Chargebee (botón
//  "Pause dunning" en la UI, que pide fecha/hora): capturado vía
//  DevTools, es POST a
//  https://harmoneyllc.ui.chargebee.com/i/invoices/{id}/set_expected_payment_date
//  -- un endpoint PRIVADO del backend de la interfaz web (dominio
//  "ui.chargebee.com", ruta "/i/..."), autenticado con un Bearer JWT
//  de sesión + _csrf_token propios del login humano en el dashboard,
//  NO con la API key del Named Credential "Chargebee_API". No hay
//  forma correcta de llamar esto desde Apex.
//
//  Conclusión: "programar fecha de cobro" es una acción EXCLUSIVAMENTE
//  MANUAL, solo desde el dashboard de Chargebee, por una persona con
//  sesión iniciada ahí (Comercial). Nuestro rol se queda en el reporte
//  de solo lectura (COLLECTIONS/estado_cobros.py), que ya señala qué
//  facturas necesitan esa acción -- no en ejecutarla.
//
//  Se deja el código original comentado abajo como referencia (por si
//  algún día sí hace falta un cobro DIRECTO de verdad, con
//  autorización explícita caso por caso -- no confundir con
//  "programar").
// ============================================================

/*
// ---------------- CONFIG ----------------
Boolean modoDryRun = true;     // true = solo valida y simula, NO llama a Chargebee -- dejar en true la 1ra pasada
String  NAMED_CRED = 'Chargebee_API';

// Contratos a activar para cobro HOY -- se activan TODAS sus invoices
// PAYMENT_DUE actuales (fee + multa quedan en la misma corrida/fecha).
// Validar cada contrato a mano contra el Reporte de Estado de Cobros
// (y contra Contratos_para_Cancelar_LOG.csv) antes de agregarlo aquí.
Set<String> contractNumbers = new Set<String>{
    '00316671'
};
// -----------------------------------------

public class ActivationResult {
    public String contractNumber;
    public String invoiceName;
    public String cbInvoiceId;
    public String statusBefore;
    public String outcome;   // DRY_RUN / TRIGGERED_PAID / TRIGGERED_STILL_DUE / SKIPPED_* / API_ERROR / EXCEPTION
    public String detail;
}

List<ActivationResult> results = new List<ActivationResult>();

// ── 1. Detectar automáticamente las invoices PAYMENT_DUE de estos contratos ──
List<chargebeeapps__CB_Invoice__c> invoices = [
    SELECT Id, Name, chargebeeapps__CB_Invoice_Id__c, chargebeeapps__Status__c,
           chargebeeapps__Invoice_Date__c, Parent_CB_Invoice_Number__c,
           Contract__c, Contract__r.ContractNumber, Contract__r.Status
    FROM   chargebeeapps__CB_Invoice__c
    WHERE  Contract__r.ContractNumber IN :contractNumbers
      AND  chargebeeapps__Status__c = 'PAYMENT_DUE'
    ORDER BY Contract__r.ContractNumber, chargebeeapps__Invoice_Date__c ASC
];

System.debug('\n \u2192 Invoices PAYMENT_DUE encontradas: ' + invoices.size()
    + ' (de ' + contractNumbers.size() + ' contrato(s) declarado(s))');

Set<String> contratosConHallazgo = new Set<String>();
List<chargebeeapps__CB_Invoice__c> toUpdateLocal = new List<chargebeeapps__CB_Invoice__c>();

// ── 2. Procesar cada invoice detectada ──────────────────────
for (chargebeeapps__CB_Invoice__c inv : invoices) {
    contratosConHallazgo.add(inv.Contract__r.ContractNumber);

    ActivationResult r = new ActivationResult();
    r.contractNumber = inv.Contract__r.ContractNumber;
    r.invoiceName    = inv.Name;
    r.cbInvoiceId    = inv.chargebeeapps__CB_Invoice_Id__c;
    r.statusBefore   = inv.chargebeeapps__Status__c;

    if (String.isBlank(inv.chargebeeapps__CB_Invoice_Id__c)) {
        r.outcome = 'SKIPPED_NO_ID';
        r.detail  = 'chargebeeapps__CB_Invoice_Id__c vacío -- no se puede armar el endpoint de Chargebee.';
        results.add(r);
        continue;
    }

    if (inv.Contract__r.Status == 'Cancelled') {
        r.outcome = 'SKIPPED_CONTRACT_CANCELLED';
        r.detail  = 'El contrato ya está Cancelled -- no se activa cobro.';
        results.add(r);
        continue;
    }

    if (modoDryRun) {
        r.outcome = 'DRY_RUN';
        //r.detail  = 'Se dispararía POST /api/v2/invoices/' + inv.chargebeeapps__CB_Invoice_Id__c + '/collect_payment (cobro HOY)';
        r.detail  = 'para cobro HOY';
        
        results.add(r);
        continue;
    }

    // ── Disparar el intento de cobro de HOY vía Chargebee ──
    // (nosotros solo activamos; Chargebee decide/ejecuta el cargo real)
    try {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/invoices/'
            + EncodingUtil.urlEncode(inv.chargebeeapps__CB_Invoice_Id__c, 'UTF-8') + '/collect_payment');
        req.setMethod('POST');
        req.setTimeout(60000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> invBody = (Map<String, Object>) body.get('invoice');
            String newStatus = invBody != null ? (String) invBody.get('status') : null;

            r.outcome = (newStatus == 'paid') ? 'TRIGGERED_PAID' : 'TRIGGERED_STILL_DUE';
            r.detail  = 'Chargebee status tras el intento = ' + newStatus;

            if (newStatus != null) {
                inv.chargebeeapps__Status__c = newStatus.toUpperCase();
                toUpdateLocal.add(inv);
            }
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

// ── 3. Avisar de contratos declarados que no tenían nada pendiente ──
for (String cn : contractNumbers) {
    if (!contratosConHallazgo.contains(cn)) {
        System.debug('\u2192 ℹ️ Contrato ' + cn + ' no tiene ninguna invoice en PAYMENT_DUE ahora mismo -- nada que activar.');
    }
}

// ── 4. Reflejar el nuevo status en Salesforce de inmediato ──────
// (el conector debería sincronizarlo solo en su próxima corrida;
//  esto sólo adelanta ese reflejo para no depender de esa cadencia)
if (!toUpdateLocal.isEmpty() && !modoDryRun) {
    Database.SaveResult[] saves = Database.update(toUpdateLocal, false);
    for (Integer i = 0; i < saves.size(); i++) {
        if (!saves[i].isSuccess()) {
            System.debug('\u2192 ⚠️ No se pudo reflejar el status localmente en '
                + toUpdateLocal[i].Name + ': ' + saves[i].getErrors());
        }
    }
}

// ── 5. Reporte ───────────────────────────────────────────────
Integer disparados = 0, pagados = 0, rechazados = 0, fail = 0, skip = 0;
List<String> lines = new List<String>();
lines.add('\u2192 ══════════════════════════════════════════════════════');
lines.add('\u2192 ACTIVAR COBRO INMEDIATO — CHARGEBEE ' + (modoDryRun ? '(DRY RUN)' : '(EJECUCIÓN REAL)'));
lines.add('\u2192 ══════════════════════════════════════════════════════');
for (ActivationResult r : results) {
    lines.add('\u2192 [' + r.outcome + '] Contrato ' + r.contractNumber
        + ' ▫ Invoice ' + r.invoiceName //+ ' (CB Id: ' + r.cbInvoiceId + ')'
        + ' ▫ Status previo: ' + r.statusBefore
        + ' ▫ ' + r.detail);

    if (r.outcome == 'DRY_RUN') disparados++;
    else if (r.outcome == 'TRIGGERED_PAID') { disparados++; pagados++; }
    else if (r.outcome == 'TRIGGERED_STILL_DUE') { disparados++; rechazados++; }
    else if (r.outcome.startsWith('SKIPPED')) skip++;
    else fail++;
}
lines.add('\u2192 ══════════════════════════════════════════════════════');
lines.add('\u2192 Disparados: ' + disparados + ' (Pagados: ' + pagados + ', Rechazados de nuevo: ' + rechazados
    + ')   Errores técnicos: ' + fail + '   Omitidos: ' + skip);
lines.add('\u2192 ══════════════════════════════════════════════════════');
System.debug('\n' + String.join(lines, '\n'));
*/

System.debug('DEPRECADO 2026-09-28 -- este script no hace nada. Ver el comentario al inicio del archivo.');