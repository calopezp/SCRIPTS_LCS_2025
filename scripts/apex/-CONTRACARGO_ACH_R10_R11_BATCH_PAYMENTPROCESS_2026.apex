/*
 * -CONTRACARGO_ACH_R10_R11_BATCH_PAYMENTPROCESS_2026.apex
 * ------------------------------------------------------------
 * Mismo proceso que -CONTRACARGO_ACH_R10_R11_BATCH_CANCELLED_2026.apex, para
 * los 2 payments del piloto 2026 en contratos 'Payment Process' (activos):
 *   PY-01901116 (00318330) y PY-01902689 (00318474).
 *
 * Verificado contra los reportes reales antes de correr (2026-10-05):
 *   - PY-01901116: R01/NSF (14-sep) -> PENDING (15-sep, reintento normal)
 *     -> NOT_COLLECTED con razon "R10 CUST ADV NOT" (reporte 21-sep). El R10
 *     real ocurrio en el reintento, es el veredicto final del banco.
 *   - PY-01902689: R10 CUSTOMER ADVISES NOT AUTHORIZED (reporte 15-sep,
 *     transaccion 15-sep) -> un reporte de Check Collection POSTERIOR
 *     (29-sep) lo muestra PENDING otra vez. Confirmado por el usuario
 *     (2026-10-05): un R10/R11 es un estado FINAL, el banco no reintenta un
 *     cobro despues de el -- ese PENDING posterior es una novedad en
 *     validacion con el banco (ver TAREAS_PENDIENTES.md), NO se trata como
 *     un reintento real. Se procesa igual que los demas R10/R11.
 *
 * A diferencia del lote de Cancelled, estos SI llevan Task de seguimiento
 * (contratos activos) -- mismo patron que
 * -CONTRACARGO_ACH_R10_R11_BATCH_CANCELLED_2026_TASKS.apex. CREAR_RECOBRO
 * queda en false por decision explicita (pendiente decidir aparte si alguno
 * amerita Late Payment Fee).
 *
 * MODO DE USO: correr primero con DRY_RUN=true. Si se ve bien, DRY_RUN=false.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
String TASK_SUBJECT = 'TIADM - REFUND CONTRA CARGO (R10/R11)';
Id TASK_RECORD_TYPE_ID = '0121U00000085XiQAI';
Id TASK_OWNER_ID = '0051U000007bbx5QAA'; // Carlos Lopez
// ========================================

class Seed {
    String returnCode;
    Date rejectionDate;
    Date reportDate;
    String sourceFile;
    Seed(String rc, Date rd, Date repd, String sf) {
        returnCode = rc; rejectionDate = rd; reportDate = repd; sourceFile = sf;
    }
}

Map<String, Seed> seeds = new Map<String, Seed>{
    'PY-01901116' => new Seed('R10', Date.newInstance(2026,9,15), Date.newInstance(2026,9,21), 'CheckCollectionDailyReport_09212026.pdf'),
    'PY-01902689' => new Seed('R10', Date.newInstance(2026,9,15), Date.newInstance(2026,9,28), 'ACH Returns Report_09_28_2026.pdf')
};

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments en el lote: ' + seeds.size());
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
    WHERE Name IN :seeds.keySet()
];

if (originals.size() != seeds.size()) {
    System.debug(' -> ***** ALERTA: se esperaban ' + seeds.size() + ' payments, se encontraron ' + originals.size() + '. Revisar antes de seguir.');
}

Set<Id> originalIds = new Set<Id>();
for (SM_Payment__c p : originals) { originalIds.add(p.Id); }
Set<Id> alreadyRefunded = new Set<Id>();
for (SM_Payment__c r : [SELECT SM_Payments_refunded__c FROM SM_Payment__c WHERE SM_Payments_refunded__c IN :originalIds AND Payment_Status__c = 'REFUNDED']) {
    alreadyRefunded.add(r.SM_Payments_refunded__c);
}

Set<Id> contractIds = new Set<Id>();
Set<Id> accountIds = new Set<Id>();
for (SM_Payment__c p : originals) { contractIds.add(p.SM_Contract__c); accountIds.add(p.SM_Contract__r.AccountId); }
Map<Id, Account> accountsById = new Map<Id, Account>([SELECT Id, Historical_Claim_On_Record__c, Has_Refund_History__c FROM Account WHERE Id IN :accountIds]);
Set<Id> contractsWithTaskAlready = new Set<Id>();
for (Task t : [SELECT WhatId FROM Task WHERE WhatId IN :contractIds AND Subject = :TASK_SUBJECT]) {
    contractsWithTaskAlready.add(t.WhatId);
}

List<SM_Payment__c> originalsToUpdate = new List<SM_Payment__c>();
List<SM_Payment__c> refundsToInsert = new List<SM_Payment__c>();
Map<Id, Contract> contractsToUpdate = new Map<Id, Contract>();
Map<Id, Account> accountsToUpdate = new Map<Id, Account>();
List<Task> tasksToInsert = new List<Task>();

for (SM_Payment__c original : originals) {
    Seed seed = seeds.get(original.Name);
    String returnCode = seed.returnCode;

    if (original.SM_Contract__r.Status != 'Payment Process') {
        System.debug(' -> ***** OMITIDO (no esta Payment Process, status real=' + original.SM_Contract__r.Status + '): ' + original.Name);
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
        ' -> ACCEPTED/COLLECTED + REFUND + Task');

    String histTag = 'PRC_AUT_CONTRACARGO_' + returnCode + ': ACCEPTED/COLLECTED //';
    String histPrevious = original.SM_Historical_Collection_Status__c == null ? '' : original.SM_Historical_Collection_Status__c;
    String histNew = (histTag + histPrevious).left(150);

    String origNote = 'MANUAL: Contracargo ' + returnCode + ' -- Payment REFUNDED creado - ' + Date.today().format();
    String origNoteCombined = String.isBlank(original.SM_Id_Salesforce_LCS__c) ? origNote : origNote + ' // ' + original.SM_Id_Salesforce_LCS__c;
    origNoteCombined = origNoteCombined.left(255);

    originalsToUpdate.add(new SM_Payment__c(
        Id = original.Id,
        Payment_Status__c = 'ACCEPTED',
        SM_Check_Collection_Status__c = 'COLLECTED',
        SM_Check_Collection__c = true,
        SM_Historical_Collection_Status__c = histNew,
        SM_Id_Salesforce_LCS__c = origNoteCombined
    ));

    SM_Payment__c refund = new SM_Payment__c(
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
    );
    refundsToInsert.add(refund);

    if (original.SM_Contract__r.Historical_Claim_On_Record__c != true && !contractsToUpdate.containsKey(original.SM_Contract__c)) {
        contractsToUpdate.put(original.SM_Contract__c, new Contract(Id = original.SM_Contract__c, Historical_Claim_On_Record__c = true));
    }
    Account acc = accountsById.get(original.SM_Contract__r.AccountId);
    if (acc != null && (acc.Historical_Claim_On_Record__c != true || acc.Has_Refund_History__c != true) && !accountsToUpdate.containsKey(acc.Id)) {
        accountsToUpdate.put(acc.Id, new Account(Id = acc.Id, Historical_Claim_On_Record__c = true, Has_Refund_History__c = true));
    }

    if (!contractsWithTaskAlready.contains(original.SM_Contract__c)) {
        String description = ('AUTO: CONTRACARGO_ACH_R10_R11 - Payment ' + original.Name +
            ' (Contrato ' + original.SM_Contract__r.ContractNumber + ') - Codigo ' + returnCode +
            ' - Fecha de rechazo (reporte banco): ' + seed.rejectionDate.format() +
            ' - Reporte: ' + seed.reportDate.format() + ' (' + seed.sourceFile + ')' +
            ' - Refund: ' + '(se crea en este mismo run)').left(255);
        tasksToInsert.add(new Task(
            Subject        = TASK_SUBJECT,
            WhatId         = original.SM_Contract__c,
            OwnerId        = TASK_OWNER_ID,
            RecordTypeId   = TASK_RECORD_TYPE_ID,
            ActivityDate   = seed.reportDate,
            Description    = description
        ));
    } else {
        System.debug(' -> ***** Task OMITIDO (ya existe uno de este tipo en el contrato): ' + original.Name);
    }
}

System.debug(' -> ======================================================');
System.debug(' -> RESUMEN: ' + originalsToUpdate.size() + ' payments a corregir | ' + refundsToInsert.size() + ' REFUND a crear | ' +
    contractsToUpdate.size() + ' Contract a marcar | ' + accountsToUpdate.size() + ' Account a marcar | ' + tasksToInsert.size() + ' Tasks a crear');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        if (!originalsToUpdate.isEmpty()) { Database.update(originalsToUpdate, false); }
        if (!refundsToInsert.isEmpty()) { Database.insert(refundsToInsert, false); }
        if (!contractsToUpdate.isEmpty()) { Database.update(contractsToUpdate.values(), false); }
        if (!accountsToUpdate.isEmpty()) { Database.update(accountsToUpdate.values(), false); }
        if (!tasksToInsert.isEmpty()) { Database.insert(tasksToInsert, false); }
        System.debug(' -> COMPLETADO.');
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada. Cambiar DRY_RUN a false para aplicar.');
}
