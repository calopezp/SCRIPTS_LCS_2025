/*
 * fix_sweep_cancelled_queue_2026.apex
 * -------------------------------------
 * Barrido puntual (2026-09-22, pedido explicito del usuario):
 * "actualiza todo lo que corresponda a contratos cancelados o que
 * aparezcan en el listado de contratos para cancelar; si el rechazo
 * prueba que nunca se van a cobrar, saltate la regla de los 26 dias".
 *
 * 32 payments (Payment_Status__c=REJECTED, SM_Check_Collection_Status__c
 * en PENDING/RETURN) en contratos Cancelled o en la lista de
 * Cancelar Contratos -- corregidos a NOT_COLLECTED porque:
 *   - o ya pasaron mas de 26 dias desde la transmision (Rule 3), o
 *   - tienen un codigo de retorno definitivo (R02/R04/R07/R10/R13/R16
 *     -- la misma lista que usa SM_ReturnCodeNotifier para "nunca se
 *     resuelve reintentando el mismo metodo de pago"), sin importar
 *     cuantos dias lleven transmitidos.
 *
 * Se dejaron A PROPOSITO sin tocar 22 payments del mismo universo:
 * codigo R01/R09 (NSF, se resuelve reintentando) o R08 (pago detenido,
 * puede ser puntual) con 26 dias o menos -- estos si esperan el plazo
 * normal.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-22: >26 dias o codigo de retorno definitivo

Set<String> targetNames = new Set<String>{
    'PY-01773962',
    'PY-01805556',
    'PY-01828889',
    'PY-01828891',
    'PY-01828907',
    'PY-01828909',
    'PY-01828910',
    'PY-01828912',
    'PY-01828914',
    'PY-01828924',
    'PY-01828928',
    'PY-01828950',
    'PY-01829085',
    'PY-01829086',
    'PY-01829087',
    'PY-01829090',
    'PY-01829094',
    'PY-01829099',
    'PY-01840729',
    'PY-01847651',
    'PY-01847653',
    'PY-01849219',
    'PY-01857176',
    'PY-01869482',
    'PY-01870682',
    'PY-01872289',
    'PY-01872955',
    'PY-01884676',
    'PY-01899177',
    'PY-01889259',
    'PY-01889260',
    'PY-01889261'
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
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Status ' + p.SM_Contract__r.Status + ', Codigo ' + p.SM_Return_code__c + ')' +
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
