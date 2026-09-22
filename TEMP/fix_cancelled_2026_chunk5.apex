/*
 * fix_cancelled_2026_t1_t2_chunk5.apex
 * Lote 6 del fix combinado T1+T2 (solo contratos Cancelled).
 * Ver fix_cancelled_2026_t1_t2.apex (version sin chunkear, referencia
 * de contexto completo) -- se dividio en lotes de 100 porque
 * el script completo excedia el limite de tamano de Anonymous Apex
 * ("Script too large").
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (800/800 sin saltos)

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
    new TargetState('PY-01826311', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01826313', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01826314', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01828949', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829088', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829089', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829091', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829092', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829093', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829096', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829098', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01829100', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830267', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01830310', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832750', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832751', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832752', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832753', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832755', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832756', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832757', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832758', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832759', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832761', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832762', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832764', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832765', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832766', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832767', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832768', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832769', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832771', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832772', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832773', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832774', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832775', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832776', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832777', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832778', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832780', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832781', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832782', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01832783', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01833159', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834058', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834084', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834102', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834109', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834111', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834120', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834123', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834136', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834137', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834138', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834139', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834140', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834141', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834146', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834158', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834160', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834163', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834165', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834168', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834179', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834180', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834181', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834199', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834205', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834208', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01834209', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01835544', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836838', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836988', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836991', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01836996', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01837005', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01837201', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838212', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838213', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838216', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838226', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838230', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838232', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01838236', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840484', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840725', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01840730', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841616', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841628', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841663', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841670', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841673', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841674', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01841677', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842083', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842108', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842110', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842142', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842148', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01842150', 'REJECTED', 'NOT_COLLECTED')
};

Map<String, TargetState> targetByName = new Map<String, TargetState>();
for (TargetState t : targets) {
    targetByName.put(t.name, t);
}

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status
    FROM SM_Payment__c
    WHERE Name IN :targetByName.keySet()
];

System.debug('=======================================================');
System.debug(' -> LOTE 6 -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
Integer skippedNotCancelled = 0;
Integer skippedAlreadyOk = 0;

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled): ' + p.Name + ' -> ' + (p.SM_Contract__r != null ? p.SM_Contract__r.Status : '(sin contrato)'));
        skippedNotCancelled++;
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
        ' | SM_Check_Collection_Date__c (sin cambio): ' + p.SM_Check_Collection_Date__c +
        ' | Historico -> [' + newHistorical + ']'
    );

    p.Payment_Status__c = t.paymentStatus;
    p.SM_Check_Collection_Status__c = t.collectionStatus;
    p.SM_Check_Collection__c = true;
    p.SM_Historical_Collection_Status__c = newHistorical;
    toUpdate.add(p);
}

System.debug('=======================================================');
System.debug(' -> LOTE 6 -> Saltados (no Cancelled): ' + skippedNotCancelled);
System.debug(' -> LOTE 6 -> Saltados (ya coincidian): ' + skippedAlreadyOk);
System.debug(' -> LOTE 6 -> Total a actualizar: ' + toUpdate.size());
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
    System.debug(' -> LOTE 6 -> UPDATE COMPLETADO. Exitosos: ' + okCount + ' / ' + toUpdate.size());
} else {
    System.debug(' -> LOTE 6 -> DRY RUN: no se realizo ningun cambio.');
}
