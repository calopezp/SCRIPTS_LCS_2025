/*
 * fix_cancelar_queue_ac_2026.apex
 * ---------------------------------
 * Corrige 13 payments tipo AC (contratos en Payment Process, dentro del
 * lote activo de "Cancelar Contratos" -- bloqueados como
 * PENDING_ACH_PAYMENT en COLLECTIONS/CANCELACIONES/Contratos_para_Cancelar_ESTADO.csv)
 * de PENDING/RETURN a NOT_COLLECTED, por Rule 3 (CLAUDE.md 2.2): mas de
 * 26 dias desde SM_Transmission_Date_ACH_File__c sin un reporte que lo
 * resuelva mejor.
 *
 * Corresponden al "Grupo C" del analisis de AC 2026-09-22: orden ACH
 * ya Canceled, SM_AC_collected__c=false, sin ninguna Subscription
 * order creada -- sin evidencia de cobro real, seguro aplicar.
 *
 * Excluido a proposito de este lote: PY-01873013 (00318054), que en la
 * misma cola figura como REVISAR_MANUAL (SM_Customer_Cancellation__c=true,
 * 2 ordenes ACH con una todavia Initiated) -- necesita revision humana,
 * no un simple cambio de estado.
 *
 * Validado antes de este fix (mismo dia): 0 anomalias -- los 13 siguen
 * exactamente igual que en el snapshot del analisis, ninguno Test/VIP,
 * ninguno cambio de contrato. Se confirmo ademas que ningun Flow
 * escucha SM_Check_Collection_Status__c (0 resultados en
 * force-app/main/default/flows), y que Payment_Status__c NO cambia
 * (se queda REJECTED) por lo que ningun Flow disparado por
 * Payment_Status__c IsChanged aplica tampoco.
 *
 * Nota: 8 de estos 13 contratos tienen OTRO payment (PY-018905xx,
 * probablemente la Late Payment Fee generada por el rechazo del AC)
 * tambien PENDING -- corregir solo estos 13 no desbloquea esos 8
 * contratos por si solo, haria falta revisar ese segundo payment aparte.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (13/13 sin saltos)

Set<String> targetNames = new Set<String>{
    'PY-01866368','PY-01870713','PY-01870714','PY-01870715','PY-01870721',
    'PY-01870727','PY-01872247','PY-01872248','PY-01872251','PY-01873011',
    'PY-01873040','PY-01876642','PY-01879751'
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
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Status ' + p.SM_Contract__r.Status + ')' +
        ' | Payment_Status__c (sin cambio): ' + p.Payment_Status__c +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> NOT_COLLECTED' +
        ' | SM_Check_Collection_Date__c (sin cambio): ' + p.SM_Check_Collection_Date__c +
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
