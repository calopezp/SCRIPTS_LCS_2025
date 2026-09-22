/*
 * fix_ac_t1_activated_2026.apex
 * -------------------------------
 * Corrige los 2 payments tipo AC de Tier 1 pendientes (contratos
 * Activated, no Cancelled): PY-01788856 (00316539) y PY-01788739
 * (00316376). Ambos REJECTED/PENDING pero un reporte de Check
 * Collection individual y posterior confirma COLLECTED.
 *
 * Validado ANTES de aplicar (2026-09-22): ambos contratos ya tienen
 * SM_AC_collected__c=true y su propia SM_ACH_Order__r ya esta
 * 'Completed' -- este fix solo corrige el campo rezagado del Payment,
 * no crea nada nuevo. Se reviso el Flow activo
 * PAYMENT_Accumulate_AC_On_Contract (el unico que escucha
 * Payment_Status__c=ACCEPTED + SM_Type__c=AC en SM_Payment__c -- OJO,
 * avoidAllHandlerExcecution NO bloquea Flows, solo triggers Apex): su
 * gate "Contract_Eligible" exige SM_AC_collected__c=false, asi que se
 * dispara pero no hace nada (cae al Default Outcome). Los otros Flows
 * relacionados (CONTRACT_Create_ACH_AC_Order/_Subscription_Order)
 * escuchan SM_ACH_Order__c, no se tocan aqui. Las Late Payment Fee
 * asociadas (ACH-25708, ACH-25723) ya estan 'Canceled', no 'Stopped' --
 * SM_LateFeeReconciliationHandler no tiene nada que limpiar.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (2/2) y validar que ningun Flow/trigger produce efectos secundarios

Set<String> targetNames = new Set<String>{'PY-01788856', 'PY-01788739'};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.SM_AC_collected__c
    FROM SM_Payment__c
    WHERE Name IN :targetNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetNames.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.Payment_Status__c == 'ACCEPTED' && p.SM_Check_Collection_Status__c == 'COLLECTED') {
        System.debug(' -> ***** SALTADO (ya esta ACCEPTED/COLLECTED): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber +
        ', Status ' + p.SM_Contract__r.Status + ', SM_AC_collected__c ' + p.SM_Contract__r.SM_AC_collected__c + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> ACCEPTED' +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> COLLECTED' +
        ' | SM_Check_Collection_Date__c (sin cambio): ' + p.SM_Check_Collection_Date__c +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = 'ACCEPTED';
    p.SM_Check_Collection_Status__c = 'COLLECTED';
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
