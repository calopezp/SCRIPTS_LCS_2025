/*
 * fix_casing_5_marh31_2026.apex
 * -----------------------------
 * 5 payments encontrados al validar el archivo "Check Collections March 31
 * 2026.pdf" (ya indexado antes bajo el nombre viejo con typo "Marh 31") --
 * su SM_Check_Collection_Status__c quedo en la variante legacy en
 * minusculas "Not_collected" en vez de "NOT_COLLECTED". Verificado con
 * SM_Payment__History: ninguno de los 5 llego nunca a ACCEPTED -- estan en
 * REJECTED desde 2026-02-19, sin cambios de fondo, solo normalizacion de
 * mayusculas para que no vuelvan a aparecer como "desajuste" en futuras
 * validaciones (comparacion case-sensitive).
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution).
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-23: "aplica los 5 para que no aparezcan en futuros analisis"

Set<String> targetNames = new Set<String>{
    'PY-01792833', 'PY-01792850', 'PY-01792860', 'PY-01792869', 'PY-01792881'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c,
           SM_Historical_Collection_Status__c,
           SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
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
    if (p.SM_Check_Collection_Status__c != null && p.SM_Check_Collection_Status__c.equals('NOT_COLLECTED')) {
        System.debug(' -> ***** SALTADO (ya normalizado): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: NOT_COLLECTED (normalizacion casing) //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', ' + p.SM_Contract__r.Status + ')' +
        ' | SM_Check_Collection_Status__c: [' + p.SM_Check_Collection_Status__c + '] -> [NOT_COLLECTED]'
    );

    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
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
