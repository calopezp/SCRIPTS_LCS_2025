/*
 * fix_grupoA_correccion_2026.apex
 * ----------------------------------
 * CORRECCION de un error propio: estos 9 payments se habian propuesto
 * como candidatos a ACCEPTED/COLLECTED ("Grupo A") por una senal
 * circunstancial (orden ACH marcada Completed + Subscription activa en
 * el contrato) -- pero el usuario pidio validar esa logica y, al
 * revisar SM_Payment__History (Field='Payment_Status__c') de los 9,
 * NINGUNO llego a ACCEPTED en algun momento de su historia: todos van
 * de ACH TRANSMITTED directo a REJECTED y ahi se quedan. La senal de
 * "orden Completed" ya se sabia no confiable (ver el hallazgo del
 * Grupo D/bug de SM_PaymentHandler, misma sesion) -- el
 * SM_AC_collected__c=true del contrato debio venir de OTRO payment del
 * mismo contrato, no de estos.
 *
 * Se corrigen a NOT_COLLECTED (Rule 3 -- todos con mas de 26 dias
 * desde la transmision, fechas ene-ago/2026), igual que el resto de
 * Tier 2.
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Correccion validada con SM_Payment__History (0 de 9 llego a ACCEPTED)

Set<String> targetNames = new Set<String>{
    'PY-01777920','PY-01786040','PY-01773986','PY-01773987','PY-01781564',
    'PY-01802625','PY-01812412','PY-01870729','PY-01872252'
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
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
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
