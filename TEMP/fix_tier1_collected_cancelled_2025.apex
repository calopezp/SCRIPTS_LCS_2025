/*
 * fix_tier1_collected_cancelled_2025.apex
 * ----------------------------------------
 * Corrige 37 Payments (contratos Cancelled) transmitidos por ACH en 2025
 * que quedaron en REJECTED/PENDING desde la corrida de catch-up del
 * 2026-09-09 (aplico entonces lo que el indice sabia: PENDING, del
 * reporte "ResumenOctNovDec2025.pdf") pero cuyo resultado FINAL real
 * -- ACCEPTED/COLLECTED -- ya llego despues en un reporte de Check
 * Collection individual (semanal, fechado Ene/Feb 2026: "Check
 * Collections Jan X 2026.pdf" / "Reporte Feb 1-17.pdf") y nunca se
 * volvio a aplicar porque esa fecha de transaccion (Sep-Dic 2025) ya
 * cae fuera de la ventana de 2 meses de la Rule 2 (CLAUDE.md seccion
 * 2.2) -- no es un bug nuevo, es la reprocesada pendiente que esa regla
 * exige confirmar explicitamente. Detalle completo: analisis pedido por
 * el usuario 2026-09-22, ver TEMP/validacion_payments_contratos_cancelados_2025_2026-09-22.csv
 * (fila Priority = T1_CORREGIR_A_COBRADO).
 *
 * Verificado uno por uno contra el PDF de origen antes de este fix: los
 * 37 tienen el mismo patron -- "ResumenOctNovDec2025.pdf" (recap
 * trimestral) lista el cheque como PENDING (aun en proceso de
 * reingreso tras un NSF), y un reporte semanal posterior, YA con fecha
 * propia parseable y mas reciente, confirma COLLECTED. Ninguno de los
 * 37 tiene contrato Test/VIP, ninguno tiene otro Payment de la misma
 * SM_ACH_Order__c todavia 'ACH TRANSMITTED' (se descarto el guard de
 * "cancelledContractBlockedRows" -- no aplica), y la fecha
 * SM_Check_Collection_Date__c actual YA coincide con la del reporte
 * ganador en los 37 -- solo cambian Payment_Status__c y
 * SM_Check_Collection_Status__c.
 *
 * Instruccion explicita del usuario (2026-09-22): aplicar el fix pero
 * SIN disparar triggers/handlers -- solo actualizar los campos de
 * estado, sin efectos secundarios en SM_ACH_Order__c/clonado a
 * dependientes/etc. Se usa SM_TriggerHandler.avoidAllHandlerExcecution,
 * mismo patron que TEMP/fix_py01888816_regression.apex.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (37/37 sin saltos)

Set<String> targetNames = new Set<String>{'PY-01754186','PY-01756731','PY-01762889','PY-01765921','PY-01766010','PY-01766908','PY-01766931','PY-01769080','PY-01769205','PY-01769829','PY-01769831','PY-01771572','PY-01771583','PY-01771634','PY-01771687','PY-01771705','PY-01771736','PY-01771740','PY-01771746','PY-01771758','PY-01771770','PY-01771773','PY-01771798','PY-01771801','PY-01771802','PY-01771812','PY-01771834','PY-01771840','PY-01771851','PY-01771863','PY-01771867','PY-01771882','PY-01771884','PY-01771890','PY-01771892','PY-01771901','PY-01772394'};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :targetNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetNames.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled, revisar manualmente): ' + p.Name + ' -> ' + (p.SM_Contract__r != null ? p.SM_Contract__r.Status : '(sin contrato)'));
        continue;
    }
    if (p.Payment_Status__c == 'ACCEPTED' && p.SM_Check_Collection_Status__c == 'COLLECTED') {
        System.debug(' -> ***** SALTADO (ya esta ACCEPTED/COLLECTED, no necesita cambio): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
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
