/*
 * fix_286_now_cancelled_chunk0.apex
 * Lote 1: re-aplica el fix (T5/T8) a payments cuyo contrato paso
 * a Cancelled durante el dia (2026-09-22) -- ya validados antes, solo
 * se habian saltado por el chequeo de seguridad de contrato Cancelled.
 * Aqui SI se permite Cancelled a proposito.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-22: re-aplicar a contratos ya Cancelled

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
    new TargetState('PY-01773063', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01773993', 'REJECTED', 'NOT_COLLECTED'),
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
    new TargetState('PY-01805556', 'REJECTED', 'RETURN'),
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
    new TargetState('PY-01857176', 'REJECTED', 'PENDING'),
    new TargetState('PY-01869482', 'REJECTED', 'RETURN'),
    new TargetState('PY-01870682', 'REJECTED', 'PENDING'),
    new TargetState('PY-01872289', 'REJECTED', 'PENDING'),
    new TargetState('PY-01872955', 'REJECTED', 'RETURN'),
    new TargetState('PY-01884676', 'REJECTED', 'RETURN'),
    new TargetState('PY-01774862', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776676', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776677', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01776772', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01780216', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785851', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785903', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01785968', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786002', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786054', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01786068', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01789012', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01791985', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01791998', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01792003', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792798', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792816', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792843', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792901', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01792909', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793841', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01793851', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01793861', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794706', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01794709', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01795676', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798416', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01798580', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798597', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798603', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01798667', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01800759', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804503', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804520', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804543', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804546', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804550', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804561', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01804569', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01804583', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806544', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01806746', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807443', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807463', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807470', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807481', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807484', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807485', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01807486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809188', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809191', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809192', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809196', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01809201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810042', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810069', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01810105', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> LOTE 1 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
Integer skippedNotEligible = 0;
Integer skippedAlreadyOk = 0;

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null) {
        System.debug(' -> ***** SALTADO (sin contrato): ' + p.Name);
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
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', Status ' + p.SM_Contract__r.Status + ')' +
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
System.debug(' -> LOTE 1 -> Saltados (no elegible): ' + skippedNotEligible);
System.debug(' -> LOTE 1 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 1 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 1 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 1 -> DRY RUN: no se realizo ningun cambio.');
}
