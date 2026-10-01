// ============================================================
//  Cancela las SM_ACH_Order__c activas (Pending/Initiated/Recurring)
//  de un contrato que ya cambió su método de pago a Credit Card --
//  SOLO si no tiene ningún payment ACH bloqueante sin resolver.
//
//  Por qué CANCELAR y no Stopped (regla DISTINTA a la de
//  CancelarContratosRunner.cls / validate_pending_payments.py, que usa
//  Stopped porque ahí el contrato TODAVÍA no terminó de cancelarse):
//  aquí el contrato YA se movió a Chargebee para cobrar -- si tenía
//  algún cobro ACH pendiente real, ese cobro ya se recreó del lado de
//  Chargebee (el subscription mismo si era la mensualidad, o un
//  CB_Charge_Request__c si era una Late Payment Fee) antes de hacer el
//  cambio. Confirmado por el usuario 2026-09-28 (caso real 00317356).
//
//  Guardas de seguridad:
//   - El contrato debe tener SM_Payment_methods__c = 'Credit Card'
//     ahora mismo (si sigue en ACH, no aplica este flujo).
//   - Ningún SM_Payment__c del contrato puede estar bloqueante
//     (Payment_Status__c REJECTED/ACH TRANSMITTED con
//     SM_Check_Collection_Status__c fuera de los estados resueltos) --
//     mismo criterio que check_estado_cancelaciones.py /
//     validate_pending_payments.py.
//   - Deja nota de auditoría en SM_Id_Salesforce_LCS__c (regla de
//     CLAUDE.md sección 1) vía SM_AutomationLogHelper.appendNote.
//
//  Autor: Carlos Lopez / Claude Code -- SEPTIEMBRE 2026
// ============================================================

// ---------------- CONFIG ----------------
Boolean modoDryRun = true;     // true = solo valida y simula, NO escribe nada -- dejar en true la 1ra pasada
String  PROCESS_NAME = 'CancelarACHOrdersSwitchTC';

Set<String> contractNumbers = new Set<String>{
    '00317356'
};
// -----------------------------------------

Set<String> BLOCKING_PAYMENT_STATUSES = new Set<String>{ 'REJECTED', 'ACH TRANSMITTED' };
Set<String> ALLOWED_COLLECTION_STATUSES = new Set<String>{
    'NOT_COLLECTED', 'Not_Collected', 'Not_collected',
    'NOT COLLECTED', 'Not Collected', 'Not collected',
    'ACCEPTED', 'Accepted',
    'COLLECTED', 'COLECTED', 'Collected',
    'REJECTED'
};
Set<String> ACTIVE_ORDER_STATUSES = new Set<String>{ 'Pending', 'Initiated', 'Recurring' };

public class Resultado {
    public String contractNumber;
    public String orderName;
    public String statusBefore;
    public String outcome;
    public String detail;
}

List<Resultado> results = new List<Resultado>();

Map<String, Contract> contractsByNumber = new Map<String, Contract>();
for (Contract c : [
    SELECT Id, ContractNumber, Status, SM_Payment_methods__c
    FROM   Contract
    WHERE  ContractNumber IN :contractNumbers
]) {
    contractsByNumber.put(c.ContractNumber, c);
}

for (String cn : contractNumbers) {
    Contract cont = contractsByNumber.get(cn);

    if (cont == null) {
        Resultado r = new Resultado();
        r.contractNumber = cn;
        r.outcome = 'SKIPPED_NOT_FOUND';
        r.detail  = 'ContractNumber no existe en MONEE.';
        results.add(r);
        continue;
    }

    if (cont.SM_Payment_methods__c != 'Credit Card') {
        Resultado r = new Resultado();
        r.contractNumber = cn;
        r.outcome = 'SKIPPED_NOT_CREDIT_CARD';
        r.detail  = 'SM_Payment_methods__c actual = ' + cont.SM_Payment_methods__c
            + ' -- este flujo solo aplica a contratos que YA están en Credit Card.';
        results.add(r);
        continue;
    }

    // ── Verificar que no haya ningún payment ACH bloqueante sin resolver ──
    Boolean tienePagoBloqueante = false;
    for (SM_Payment__c p : [
        SELECT Id, Payment_Status__c, SM_Check_Collection_Status__c
        FROM   SM_Payment__c
        WHERE  SM_Contract__c = :cont.Id
    ]) {
        if (BLOCKING_PAYMENT_STATUSES.contains(p.Payment_Status__c)
            && !ALLOWED_COLLECTION_STATUSES.contains(p.SM_Check_Collection_Status__c)) {
            tienePagoBloqueante = true;
            break;
        }
    }

    if (tienePagoBloqueante) {
        Resultado r = new Resultado();
        r.contractNumber = cn;
        r.outcome = 'SKIPPED_HAS_PENDING_PAYMENT';
        r.detail  = 'Tiene un SM_Payment__c bloqueante sin resolver -- NO se cancela nada, revisar a mano primero.';
        results.add(r);
        continue;
    }

    List<SM_ACH_Order__c> ordenes = [
        SELECT Id, Name, SM_Payment_Status__c, SM_Id_Salesforce_LCS__c
        FROM   SM_ACH_Order__c
        WHERE  SM_Contract__c = :cont.Id
        AND    SM_Payment_Status__c IN :ACTIVE_ORDER_STATUSES
    ];

    if (ordenes.isEmpty()) {
        Resultado r = new Resultado();
        r.contractNumber = cn;
        r.outcome = 'SIN_ORDENES_ACTIVAS';
        r.detail  = 'No hay ninguna SM_ACH_Order__c en Pending/Initiated/Recurring -- nada que cancelar.';
        results.add(r);
        continue;
    }

    List<SM_ACH_Order__c> toUpdate = new List<SM_ACH_Order__c>();
    for (SM_ACH_Order__c o : ordenes) {
        Resultado r = new Resultado();
        r.contractNumber = cn;
        r.orderName       = o.Name;
        r.statusBefore    = o.SM_Payment_Status__c;

        if (modoDryRun) {
            r.outcome = 'DRY_RUN';
            r.detail  = 'Se cancelaría (Canceled) -- sin cobro pendiente, contrato ya en Credit Card.';
        } else {
            o.SM_Payment_Status__c = 'Canceled';
            o.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(
                o.SM_Id_Salesforce_LCS__c, PROCESS_NAME,
                'Cancelada -- contrato pasó a Credit Card sin cobro ACH pendiente'
            );
            toUpdate.add(o);
            r.outcome = 'CANCELADO';
            r.detail  = 'Actualizado a Canceled.';
        }
        results.add(r);
    }

    if (!toUpdate.isEmpty() && !modoDryRun) {
        Database.SaveResult[] saves = Database.update(toUpdate, false);
        for (Integer i = 0; i < saves.size(); i++) {
            if (!saves[i].isSuccess()) {
                System.debug('→ ⚠️ ERROR actualizando ' + toUpdate[i].Name + ': ' + saves[i].getErrors());
            }
        }
    }
}

// ── Reporte ───────────────────────────────────────────────
System.debug('→ ══════════════════════════════════════════════════════');
System.debug('→ CANCELAR ACH ORDERS (SWITCH A TC) ' + (modoDryRun ? '(DRY RUN)' : '(EJECUCIÓN REAL)'));
System.debug('→ ══════════════════════════════════════════════════════');
for (Resultado r : results) {
    System.debug('→ [' + r.outcome + '] Contrato ' + r.contractNumber
        + (r.orderName != null ? ' ▫ Orden ' + r.orderName + ' (era ' + r.statusBefore + ')' : '')
        + ' ▫ ' + r.detail);
}
System.debug('→ ══════════════════════════════════════════════════════');
