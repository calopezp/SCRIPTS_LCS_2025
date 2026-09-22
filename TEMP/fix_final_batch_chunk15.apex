/*
 * fix_final_batch_chunk15.apex
 * Lote 16 del fix final combinado (T1 restante + T2 sin Grupo A +
 * T5 solo formato + T8 sub-estado menor), validacion 2026-09-22.
 * Ver TEMP/validacion_payments_2026_2026-09-22.csv para el detalle
 * completo de cada Tier.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 (T1+T2 sin Grupo A+T5+T8, preview validado)

class TargetState {
    String name;
    String paymentStatus;
    String collectionStatus;
    TargetState(String name, String paymentStatus, String collectionStatus) {
        this.name = name;
        this.paymentStatus = paymentStatus;
        this.collectionStatus = collectionStatus;
    }
}

List<TargetState> targets = new List<TargetState>{
    new TargetState('PY-01775789', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01775801', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01784851', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785948', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785960', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785961', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01785991', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786022', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786046', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786061', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01786064', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787490', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01787492', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804536', 'REJECTED', 'RETURN'),
    new TargetState('PY-01805556', 'REJECTED', 'RETURN'),
    new TargetState('PY-01807462', 'REJECTED', 'RETURN'),
    new TargetState('PY-01807474', 'REJECTED', 'RETURN'),
    new TargetState('PY-01807476', 'REJECTED', 'RETURN'),
    new TargetState('PY-01828889', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828891', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828907', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828909', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828910', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828912', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828914', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828924', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828928', 'REJECTED', 'PENDING'),
    new TargetState('PY-01828950', 'REJECTED', 'PENDING'),
    new TargetState('PY-01829085', 'REJECTED', 'RETURN'),
    new TargetState('PY-01829086', 'REJECTED', 'RETURN'),
    new TargetState('PY-01829087', 'REJECTED', 'RETURN'),
    new TargetState('PY-01829090', 'REJECTED', 'RETURN'),
    new TargetState('PY-01829094', 'REJECTED', 'RETURN'),
    new TargetState('PY-01829099', 'REJECTED', 'RETURN'),
    new TargetState('PY-01840729', 'REJECTED', 'PENDING'),
    new TargetState('PY-01847651', 'REJECTED', 'PENDING'),
    new TargetState('PY-01847653', 'REJECTED', 'PENDING'),
    new TargetState('PY-01849219', 'REJECTED', 'PENDING'),
    new TargetState('PY-01849469', 'REJECTED', 'PENDING'),
    new TargetState('PY-01857176', 'REJECTED', 'PENDING'),
    new TargetState('PY-01859726', 'REJECTED', 'PENDING'),
    new TargetState('PY-01865165', 'REJECTED', 'PENDING'),
    new TargetState('PY-01869482', 'REJECTED', 'RETURN'),
    new TargetState('PY-01870682', 'REJECTED', 'PENDING'),
    new TargetState('PY-01872218', 'REJECTED', 'RETURN'),
    new TargetState('PY-01872289', 'REJECTED', 'PENDING'),
    new TargetState('PY-01872955', 'REJECTED', 'RETURN'),
    new TargetState('PY-01880352', 'REJECTED', 'RETURN'),
    new TargetState('PY-01880378', 'REJECTED', 'RETURN'),
    new TargetState('PY-01880427', 'REJECTED', 'RETURN'),
    new TargetState('PY-01883331', 'REJECTED', 'RETURN'),
    new TargetState('PY-01884599', 'REJECTED', 'RETURN'),
    new TargetState('PY-01884645', 'REJECTED', 'RETURN'),
    new TargetState('PY-01884676', 'REJECTED', 'RETURN'),
    new TargetState('PY-01884692', 'REJECTED', 'RETURN'),
    new TargetState('PY-01887695', 'REJECTED', 'NOT COLLECTED')
};

Map<String, TargetState> targetByName = new Map<String, TargetState>();
for (TargetState t : targets) {
    targetByName.put(t.name, t);
}

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status, SM_Contract__r.Is_Test_Contract__c,
           SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE Name IN :targetByName.keySet()
];

System.debug('=======================================================');
System.debug(' -> LOTE 16 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
Integer skippedNotEligible = 0;
Integer skippedAlreadyOk = 0;

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status == 'Cancelled') {
        System.debug(' -> ***** SALTADO (contrato ya Cancelled, revisar aparte): ' + p.Name);
        skippedNotEligible++;
        continue;
    }
    if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** SALTADO (Test/VIP): ' + p.Name);
        skippedNotEligible++;
        continue;
    }
    if (p.Payment_Status__c.equals(t.paymentStatus) && p.SM_Check_Collection_Status__c.equals(t.collectionStatus)) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        skippedAlreadyOk++;
        continue;
    }

    String tag = 'PRC_AUT: ' + t.collectionStatus + ' //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ')' +
        ' | Payment_Status__c: ' + p.Payment_Status__c + ' -> ' + t.paymentStatus +
        ' | SM_Check_Collection_Status__c: ' + p.SM_Check_Collection_Status__c + ' -> ' + t.collectionStatus +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = t.paymentStatus;
    p.SM_Check_Collection_Status__c = t.collectionStatus;
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> LOTE 16 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 16 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 16 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 16 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 16 -> DRY RUN: no se realizo ningun cambio.');
}
