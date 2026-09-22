/*
 * fix_lpf_definitive_returncode_2026.apex
 * ------------------------------------------
 * Corrige 5 payments tipo Late Payment Fee (los "segundos payments" de
 * 5 de los 8 contratos del fix anterior de la cola de Cancelar
 * Contratos) de PENDING a NOT_COLLECTED SIN esperar el plazo normal de
 * la Rule 3 (26 dias -- estos llevan solo 25) -- instruccion explicita
 * del usuario 2026-09-22: si el codigo de retorno es de los que nunca
 * se resuelven reintentando, proceder de una vez.
 *
 * Los 5 tienen un codigo NACHA de la misma categoria que ya usa
 * SM_ReturnCodeNotifier para R02/R04+R13 (nunca se resuelven
 * reintentando el mismo metodo de pago):
 *   PY-01890514 (00317788) R04 -- cuenta invalida
 *   PY-01890520 (00317916) R02 -- cuenta cerrada
 *   PY-01890521 (00317918) R04 -- cuenta invalida
 *   PY-01890522 (00317927) R02 -- cuenta cerrada
 *   PY-01890540 (00317861) R13 -- routing invalido
 *
 * Excluidos a proposito (mismo lote de 7, pero con codigo NO
 * definitivo -- se dejan esperar el plazo normal de 26 dias, quedan
 * elegibles el 2026-09-24):
 *   PY-01890523 (00317954) R08 -- pago detenido, puede ser puntual
 *   PY-01890524 (00317971) R01/NSF -- se resuelve reintentando
 *
 * Todas las ordenes ACH de estos 5 ya estan 'Canceled' (no se
 * reactivan). Verificado antes de aplicar: 0 anomalias, ninguno
 * Test/VIP, ninguno cambio desde el analisis previo. Sin
 * triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution) --
 * ademas Payment_Status__c no cambia (se queda REJECTED) y ningun Flow
 * escucha SM_Check_Collection_Status__c.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22: codigos de retorno definitivos, no esperar los dias de Rule 3 (preview 5/5 sin saltos)

Set<String> targetNames = new Set<String>{
    'PY-01890514','PY-01890520','PY-01890521','PY-01890522','PY-01890540'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name IN :targetNames
];

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetNames.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status == 'Cancelled') {
        System.debug(' -> ***** SALTADO (contrato ya Cancelled, revisar aparte): ' + p.Name);
        continue;
    }
    if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** SALTADO (Test/VIP): ' + p.Name);
        continue;
    }
    if (p.Payment_Status__c.equals('REJECTED') && p.SM_Check_Collection_Status__c.equals('NOT_COLLECTED')) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: NOT_COLLECTED //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Codigo ' + p.SM_Return_code__c + ')' +
        ' | Payment_Status__c (sin cambio): ' + p.Payment_Status__c +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> NOT_COLLECTED' +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
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
