/*
 * -CONTRACARGO_ACH_R10_R11_BATCH_CANCELLED_2026.apex
 * ----------------------------------------------------
 * Aplica la regla de contracargo R10/R11 (CLAUDE.md seccion 2.2, confirmada
 * 2026-10-04, ver -CONTRACARGO_ACH_R10_R11.apex para el detalle completo de
 * la regla de negocio) en LOTE para el piloto acordado: solo contratos
 * CREADOS en 2026, y dentro de ese piloto, SOLO los que estan Cancelled.
 *
 * ALCANCE CONFIRMADO POR CARLOS (2026-10-05) para contratos Cancelled:
 *   1) Payment original -> ACCEPTED/COLLECTED (se trata como cobro real).
 *   2) Se crea el Payment REFUNDED (monto negativo, SM_Payments_refunded__c
 *      al original, SM_Reason_for_refund__c='CONTRA CARGO (R10/R11)').
 *   3) Se marca Historical_Claim_On_Record__c=true en el Contract Y en el
 *      Account, ademas de Has_Refund_History__c=true en el Account (mismos
 *      2 campos que ya marca -CONTRACARGO_CHARGEBEE.apex para TC).
 *   4) NADA MAS -- explicitamente NO se crea Late Payment Fee/Charge Request
 *      (recobro), NO se crea Task de seguimiento (ese Task es solo para
 *      contratos activos, Activated/Payment Process, ver TAREAS_PENDIENTES.md
 *      fila 2026-10-05), y NO se reactiva ninguna Subscription/Invoice/Order
 *      -- el contrato esta Cancelled, no hay nada que reactivar a proposito.
 *
 * Los 25 payments de este lote vienen de la cuenta en vivo contra MONEE
 * 2026-10-05 (contratos con CreatedDate=THIS_YEAR, Status='Cancelled',
 * SM_Return_code__c IN ('R10','R11')) -- incluye PY-01895410/00318380, que
 * es el mismo caso ya identificado en TAREAS_PENDIENTES.md como pendiente de
 * revision bajo la regla nueva (fila 2026-10-04, "3 payments corregidos bajo
 * la regla VIEJA").
 *
 * MODO DE USO: correr primero con DRY_RUN=true (preview, no escribe nada).
 * Si todo se ve bien, cambiar a false y correr de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
// ========================================

Map<String, String> paymentToReturnCode = new Map<String, String>{
    'PY-01824479' => 'R10', 'PY-01824581' => 'R10', 'PY-01824989' => 'R10',
    'PY-01797727' => 'R11',
    'PY-01849219' => 'R10',
    'PY-01819316' => 'R11', 'PY-01883327' => 'R11', 'PY-01884620' => 'R11', 'PY-01884648' => 'R11', 'PY-01884694' => 'R11',
    'PY-01847653' => 'R10',
    'PY-01847651' => 'R10',
    'PY-01810295' => 'R11',
    'PY-01802627' => 'R11',
    'PY-01849469' => 'R10', 'PY-01865165' => 'R10',
    'PY-01828949' => 'R11',
    'PY-01838226' => 'R11',
    'PY-01872289' => 'R10', 'PY-01869482' => 'R10',
    'PY-01884676' => 'R10',
    'PY-01861633' => 'R11',
    'PY-01888816' => 'R11',
    'PY-01894631' => 'R10',
    'PY-01895410' => 'R10'
};

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments en el lote: ' + paymentToReturnCode.size());
System.debug(' -> ======================================================');

List<SM_Payment__c> originals = [
    SELECT Id, Name, SM_Contract__c, SM_ACH_Order__c, RecordTypeId, Payment_Status__c,
           SM_Check_Collection_Status__c, SM_Check_Collection__c, SM_Amount__c, SM_Fee_value__c,
           SM_Penalty_value__c, SM_Type__c, SM_Original_Type__c, SM_Payment_Method__c,
           SM_ACH_Account_Number__c, SM_ACH_Account_Routing_Number__c, SM_Routing_Number_Check_Digit__c,
           SM_Recurring__c, Invoice__c, SM_Concepto_Pago_Cash__c, Installment_number__c,
           SM_P_IVU_Municipal_Amount__c, SM_P_IVU_State_Amount__c, SM_Payment_Date__c,
           SM_Historical_Collection_Status__c, SM_Id_Salesforce_LCS__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.AccountId,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c,
           SM_Contract__r.Historical_Claim_On_Record__c
    FROM SM_Payment__c
    WHERE Name IN :paymentToReturnCode.keySet()
];

if (originals.size() != paymentToReturnCode.size()) {
    System.debug(' -> ***** ALERTA: se esperaban ' + paymentToReturnCode.size() + ' payments, se encontraron ' + originals.size() + '. Revisar nombres antes de seguir.');
}

// Dedupe: no reprocesar si ya existe un REFUND para alguno de estos originales
Set<Id> originalIds = new Set<Id>();
for (SM_Payment__c p : originals) { originalIds.add(p.Id); }
Set<Id> alreadyRefunded = new Set<Id>();
for (SM_Payment__c r : [SELECT SM_Payments_refunded__c FROM SM_Payment__c WHERE SM_Payments_refunded__c IN :originalIds AND Payment_Status__c = 'REFUNDED']) {
    alreadyRefunded.add(r.SM_Payments_refunded__c);
}

Set<Id> accountIds = new Set<Id>();
for (SM_Payment__c p : originals) { accountIds.add(p.SM_Contract__r.AccountId); }
Map<Id, Account> accountsById = new Map<Id, Account>([SELECT Id, Historical_Claim_On_Record__c, Has_Refund_History__c FROM Account WHERE Id IN :accountIds]);

List<SM_Payment__c> originalsToUpdate = new List<SM_Payment__c>();
List<SM_Payment__c> refundsToInsert = new List<SM_Payment__c>();
Map<Id, Contract> contractsToUpdate = new Map<Id, Contract>();
Map<Id, Account> accountsToUpdate = new Map<Id, Account>();

for (SM_Payment__c original : originals) {
    String returnCode = paymentToReturnCode.get(original.Name);

    if (original.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** OMITIDO (no esta Cancelled, status real=' + original.SM_Contract__r.Status + '): ' + original.Name + ' -- revisar aparte, no es parte de este lote.');
        continue;
    }
    if (original.SM_Contract__r.Is_Test_Contract__c == true || original.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** OMITIDO (Test/VIP): ' + original.Name);
        continue;
    }
    if (alreadyRefunded.contains(original.Id)) {
        System.debug(' -> ***** OMITIDO (ya existe un REFUND para este payment): ' + original.Name);
        continue;
    }

    System.debug(' -> ' + original.Name + ' | Contrato ' + original.SM_Contract__r.ContractNumber +
        ' | Return: ' + returnCode + ' | Estado actual: ' + original.Payment_Status__c + '/' + original.SM_Check_Collection_Status__c +
        ' -> ACCEPTED/COLLECTED + REFUND');

    String histTag = 'PRC_AUT_CONTRACARGO_' + returnCode + ': ACCEPTED/COLLECTED //';
    String histPrevious = original.SM_Historical_Collection_Status__c == null ? '' : original.SM_Historical_Collection_Status__c;
    String histNew = (histTag + histPrevious).left(150);

    String origNote = 'MANUAL: Contracargo ' + returnCode + ' -- Payment REFUNDED creado - ' + Date.today().format();
    String origNoteCombined = String.isBlank(original.SM_Id_Salesforce_LCS__c) ? origNote : origNote + ' // ' + original.SM_Id_Salesforce_LCS__c;
    origNoteCombined = origNoteCombined.left(255);

    SM_Payment__c upd = new SM_Payment__c(
        Id = original.Id,
        Payment_Status__c = 'ACCEPTED',
        SM_Check_Collection_Status__c = 'COLLECTED',
        SM_Check_Collection__c = true,
        SM_Historical_Collection_Status__c = histNew,
        SM_Id_Salesforce_LCS__c = origNoteCombined
    );
    originalsToUpdate.add(upd);

    refundsToInsert.add(new SM_Payment__c(
        RecordTypeId                      = original.RecordTypeId,
        Payment_Status__c                 = 'REFUNDED',
        SM_Check_Collection_Status__c      = null,
        SM_Reason_for_refund__c           = 'CONTRA CARGO (R10/R11)',
        SM_Return_code__c                 = returnCode,
        SM_Contract__c                     = original.SM_Contract__c,
        SM_ACH_Order__c                   = original.SM_ACH_Order__c,
        SM_Amount__c                       = (original.SM_Amount__c != null) ? original.SM_Amount__c * -1 : null,
        SM_Fee_value__c                     = (original.SM_Fee_value__c != null) ? original.SM_Fee_value__c * -1 : null,
        SM_Penalty_value__c                = (original.SM_Penalty_value__c != null) ? original.SM_Penalty_value__c * -1 : null,
        SM_Payments_refunded__c           = original.Id,
        SM_Type__c                         = original.SM_Type__c,
        SM_Original_Type__c               = original.SM_Original_Type__c,
        SM_Payment_Method__c              = original.SM_Payment_Method__c,
        SM_ACH_Account_Number__c          = original.SM_ACH_Account_Number__c,
        SM_ACH_Account_Routing_Number__c  = original.SM_ACH_Account_Routing_Number__c,
        SM_Routing_Number_Check_Digit__c  = original.SM_Routing_Number_Check_Digit__c,
        SM_Recurring__c                   = original.SM_Recurring__c,
        Invoice__c                         = original.Invoice__c,
        SM_Concepto_Pago_Cash__c          = original.SM_Concepto_Pago_Cash__c,
        Installment_number__c             = original.Installment_number__c,
        SM_P_IVU_Municipal_Amount__c      = original.SM_P_IVU_Municipal_Amount__c,
        SM_P_IVU_State_Amount__c          = original.SM_P_IVU_State_Amount__c,
        SM_Payment_Due_Date__c            = original.SM_Payment_Date__c,
        SM_Payment_Date__c                = original.SM_Payment_Date__c,
        SM_Id_Salesforce_LCS__c           = ('MANUAL: Contracargo ' + returnCode + ' -- ver ' + original.Name + ' - ' + Date.today().format())
    ));

    if (original.SM_Contract__r.Historical_Claim_On_Record__c != true && !contractsToUpdate.containsKey(original.SM_Contract__c)) {
        contractsToUpdate.put(original.SM_Contract__c, new Contract(Id = original.SM_Contract__c, Historical_Claim_On_Record__c = true));
    }

    Account acc = accountsById.get(original.SM_Contract__r.AccountId);
    if (acc != null && (acc.Historical_Claim_On_Record__c != true || acc.Has_Refund_History__c != true) && !accountsToUpdate.containsKey(acc.Id)) {
        accountsToUpdate.put(acc.Id, new Account(Id = acc.Id, Historical_Claim_On_Record__c = true, Has_Refund_History__c = true));
    }
}

System.debug(' -> ======================================================');
System.debug(' -> RESUMEN: ' + originalsToUpdate.size() + ' payments a corregir | ' + refundsToInsert.size() + ' REFUND a crear | ' +
    contractsToUpdate.size() + ' Contract a marcar | ' + accountsToUpdate.size() + ' Account a marcar');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        if (!originalsToUpdate.isEmpty()) {
            Database.update(originalsToUpdate, false);
        }
        if (!refundsToInsert.isEmpty()) {
            Database.insert(refundsToInsert, false);
        }
        if (!contractsToUpdate.isEmpty()) {
            Database.update(contractsToUpdate.values(), false);
        }
        if (!accountsToUpdate.isEmpty()) {
            Database.update(accountsToUpdate.values(), false);
        }
        System.debug(' -> COMPLETADO.');
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada. Cambiar DRY_RUN a false para aplicar.');
}
