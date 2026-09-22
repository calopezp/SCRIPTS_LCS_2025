/*
 * fix_tier2_revert_cancelled_2025.apex
 * -------------------------------------
 * Corrige 2 Payments (contratos Cancelled) que un mismo lote de mass-update
 * (LastModifiedById 0051U000007bbx5QAA, 2026-08-04 12:14-12:15 UTC) dejo
 * marcados ACCEPTED / "Collected" (casing minuscula -- NUNCA usada por el
 * pipeline real de Check Collection, que siempre escribe "COLLECTED" en
 * mayusculas) sin ningun soporte de reporte bancario real:
 * SM_Historical_Collection_Status__c estaba NULL en ambos -- nunca los toco
 * update_check_collection.apex/update_ach_returns.apex.
 *
 * El unico reporte real que existe para estos 2 (ResumenOctNovDec2025.pdf,
 * PY-01738648 fecha 2025-10-07, PY-01741839 fecha 2025-10-16) los lista
 * como PENDING (mismo patron ambiguo del recap trimestral que en el fix de
 * Tier 1, PERO sin ningun reporte semanal posterior que confirme COLLECTED
 * como si tuvieron los 37 de Tier 1) -- no hay ninguna evidencia de un
 * cobro real. El mismo lote del 2026-08-04 tambien dejo 2 casos mas
 * (PY-01726132, PY-01729785) con el mismo casing "Collected" pero esos SI
 * tenian Payment_Status__c=ACCEPTED ya correcto por otra via (T3 del
 * analisis, solo cosmetico) -- estos 2 no: no hay ninguna otra fuente que
 * respalde ACCEPTED/Collected.
 *
 * Ver TEMP/validacion_payments_contratos_cancelados_2025_2026-09-22.csv,
 * filas Priority = T2_REVISION_MANUAL. Decision del usuario 2026-09-22:
 * "para el tier2 actualiza al estado real" -> revertir al PENDING del
 * reporte real, incluyendo su propia fecha (2025-10-07 / 2025-10-16),
 * reemplazando la fecha sin respaldo (2025-11-19 / 2025-11-17) que dejo el
 * mass-update.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution),
 * mismo patron que TEMP/fix_py01888816_regression.apex y
 * TEMP/fix_tier1_collected_cancelled_2025.apex.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (2/2 sin saltos)

Map<String, Date> targetDateByName = new Map<String, Date>{
    'PY-01738648' => Date.newInstance(2025, 10, 7),
    'PY-01741839' => Date.newInstance(2025, 10, 16)
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :targetDateByName.keySet()
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetDateByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled, revisar manualmente): ' + p.Name + ' -> ' + (p.SM_Contract__r != null ? p.SM_Contract__r.Status : '(sin contrato)'));
        continue;
    }
    if (p.Payment_Status__c == 'REJECTED' && p.SM_Check_Collection_Status__c == 'PENDING') {
        System.debug(' -> ***** SALTADO (ya esta REJECTED/PENDING, no necesita cambio): ' + p.Name);
        continue;
    }

    Date targetDate = targetDateByName.get(p.Name);

    String tag = 'PRC_AUT: PENDING //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> REJECTED' +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> PENDING' +
        ' | SM_Check_Collection_Date__c: ' + p.SM_Check_Collection_Date__c + ' -> ' + targetDate +
        ' | SM_Return_code__c (sin cambio): ' + p.SM_Return_code__c +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = 'REJECTED';
    p.SM_Check_Collection_Status__c = 'PENDING';
    p.SM_Check_Collection_Date__c = targetDate;
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> Total a actualizar: ' + toUpdate.size());
System.debug('=======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    Database.SaveResult[] results = Database.update(toUpdate, false);
    SM_TriggerHandler.avoidAllHandlerExcecution = false;

    Integer okCount = 0;
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            okCount++;
        } else {
            System.debug(' -> ***** ERROR actualizando ' + toUpdate[i].Name + ': ' + results[i].getErrors());
        }
    }
    System.debug(' -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para aplicar.');
}
