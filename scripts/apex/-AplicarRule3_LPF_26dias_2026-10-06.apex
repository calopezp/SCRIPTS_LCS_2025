/*
 * -AplicarRule3_LPF_26dias_2026-10-06.apex
 * -------------------------------------------
 * Correccion PUNTUAL (no recurrente): aplica la Rule 3 (CLAUDE.md seccion 2.2)
 * a 13 Late Payment Fee que llevan mas de 26 dias en REJECTED/PENDING sin
 * ningun reporte posterior del banco -- identificados por
 * activar_ach_chronic_unpaid.apex (seccion EXCLUIDO_LPF_TRANSITO, tag
 * ">26 dias, Rule 3") en la corrida del correo diario "[ACH] Contratos
 * cronicos sin cobrar".
 *
 * Validado uno por uno antes de escribir (2026-10-06):
 *   - Los 13 tienen exactamente 1 reporte de Returns (RETURN, con codigo real)
 *     y 1 reporte de Collections (PENDING) -- NUNCA UN REPORTE POSTERIOR,
 *     cruzado contra returns_index.csv/collections_index.csv (nunca
 *     SM_Payment__History). Consistente con que el banco dejo de reportar en
 *     silencio, exactamente el escenario que la Rule 3 cubre.
 *   - Los 11 contratos: todos Activated, no Test/VIP/Customer_Cancellation.
 *   - Ningun payment tiene nota en SM_Id_Salesforce_LCS__c.
 *   - 00316755 tiene un REFUND de contracargo (PY-01916600) pero apunta a
 *     OTRO payment (PY-01884599) -- no afecta a PY-01899194.
 *   - 2 payments (PY-01899149, PY-01899207) tenian SM_Return_code__c vacio en
 *     Salesforce aunque el reporte real de Returns muestra R01 -- se
 *     backfillea de paso (mismo patron del backfill de 2026-09-14).
 *
 * NO bypassea triggers (igual que update_check_collection.apex/
 * update_ach_returns.apex en el pipeline real -- este es el mismo tipo de
 * actualizacion que esos scripts aplicarian si el reporte hubiera llegado).
 *
 * Deja nota "MANUAL: Rule 3 (>26 dias sin reporte posterior)..." en
 * SM_Id_Salesforce_LCS__c de cada payment + 1 Task por contrato (regla de
 * CLAUDE.md seccion 1 sobre acciones manuales fuera del proceso normal).
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO escribe nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar el update real

Map<String, String> returnCodeBackfill = new Map<String, String>{
    'PY-01899149' => 'R01',
    'PY-01899207' => 'R01'
};

Set<String> paymentNames = new Set<String>{
    'PY-01892870', 'PY-01892874', 'PY-01899173', 'PY-01899205', 'PY-01895397',
    'PY-01899207', 'PY-01899149', 'PY-01899144', 'PY-01899172', 'PY-01899209',
    'PY-01899194', 'PY-01899189', 'PY-01899203'
};
// ========================================

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a actualizar)'));
System.debug(' -> ======================================================');

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c, SM_Return_code__c,
           SM_Id_Salesforce_LCS__c, SM_Contract__c, SM_Contract__r.ContractNumber,
           SM_Transmission_Date_ACH_File__c, SM_Amount__c
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
];

Map<Id, List<SM_Payment__c>> paymentsByContract = new Map<Id, List<SM_Payment__c>>();
List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    Integer dias = p.SM_Transmission_Date_ACH_File__c == null ? null : p.SM_Transmission_Date_ACH_File__c.daysBetween(Date.today());
    System.debug(' -> ' + p.Name + ' (' + p.SM_Contract__r.ContractNumber + ') -- ' + dias + ' dias desde transmision, ' +
        p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c + ' -> REJECTED/NOT_COLLECTED');

    String note = 'MANUAL: Rule 3 (>26 dias sin reporte posterior) aplicado - ' + Date.today().format();
    String noteCombined = String.isBlank(p.SM_Id_Salesforce_LCS__c) ? note : note + ' // ' + p.SM_Id_Salesforce_LCS__c;
    if (noteCombined.length() > 255) { noteCombined = noteCombined.substring(0, 255); }

    SM_Payment__c upd = new SM_Payment__c(
        Id = p.Id,
        Payment_Status__c = 'REJECTED',
        SM_Check_Collection_Status__c = 'NOT_COLLECTED',
        SM_Id_Salesforce_LCS__c = noteCombined
    );
    if (returnCodeBackfill.containsKey(p.Name)) {
        upd.SM_Return_code__c = returnCodeBackfill.get(p.Name);
        System.debug('   -> de paso, backfill SM_Return_code__c = ' + returnCodeBackfill.get(p.Name));
    }
    toUpdate.add(upd);

    if (!paymentsByContract.containsKey(p.SM_Contract__c)) {
        paymentsByContract.put(p.SM_Contract__c, new List<SM_Payment__c>());
    }
    paymentsByContract.get(p.SM_Contract__c).add(p);
}

System.debug(' -> ======================================================');
System.debug(' -> Total a actualizar: ' + toUpdate.size() + ' payments en ' + paymentsByContract.size() + ' contratos');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    update toUpdate;
    System.debug(' -> Payments actualizados: ' + toUpdate.size());

    Id taskRecordTypeId = '0121U00000085XiQAI';
    Id taskOwnerId = '0051U000007bbx5QAA';
    List<Task> tasksToInsert = new List<Task>();

    for (Id contractId : paymentsByContract.keySet()) {
        List<SM_Payment__c> contractPayments = paymentsByContract.get(contractId);
        List<String> paymentNamesList = new List<String>();
        for (SM_Payment__c p : contractPayments) { paymentNamesList.add(p.Name); }

        tasksToInsert.add(new Task(
            WhatId = contractId,
            RecordTypeId = taskRecordTypeId,
            OwnerId = taskOwnerId,
            Subject = 'TIADM - RULE 3 APLICADA (LPF >26 dias sin reporte)',
            Description = 'Late Payment Fee con mas de 26 dias en transito sin reporte posterior del banco -- ' +
                'aplicada Rule 3 (CLAUDE.md seccion 2.2): ' + String.join(paymentNamesList, ', ') +
                ' pasaron a REJECTED/NOT_COLLECTED. ' + Date.today().format(),
            Status = 'Completed',
            ActivityDate = Date.today()
        ));
    }
    insert tasksToInsert;
    System.debug(' -> Tasks creadas: ' + tasksToInsert.size());

    System.debug(' -> ======================================================');
    System.debug(' -> COMPLETADO');
    System.debug(' -> ======================================================');
} else {
    System.debug(' -> DRY RUN activo: no se actualizo nada. Cambia DRY_RUN a false para aplicar.');
}
