// ============================================================
//  Normaliza SM_Check_Collection_Status__c: 'NOT COLLECTED' (con
//  espacio, dato legado de antes de que extract_check_collection.py
//  normalizara al escribir) -> 'NOT_COLLECTED' (guion bajo, el valor
//  que usa el resto del código/reportes desde entonces).
//
//  SM_Check_Collection_Status__c es texto libre, no picklist -- no
//  hay riesgo de "bad value for restricted picklist field" aquí.
//
//  Verificado antes de correr:
//   - 212 registros afectados (SELECT COUNT(Id), 2026-09-21).
//   - Ningún handler activo dispara lógica al pasar a 'NOT_COLLECTED'
//     (SM_LateFeeReconciliationHandler solo reacciona a 'COLLECTED').
//
//  Autor: Carlos Lopez / Claude Code — SEPTIEMBRE 2026
// ============================================================

Boolean modoDryRun = false; // true = solo cuenta/lista, no actualiza nada

List<SM_Payment__c> toFix = [
    SELECT Id, Name, SM_Check_Collection_Status__c
    FROM   SM_Payment__c
    WHERE  SM_Check_Collection_Status__c = 'NOT COLLECTED'
];

System.debug('-> Payments a normalizar: ' + toFix.size());

if (modoDryRun) {
    for (SM_Payment__c p : toFix) {
        System.debug('-> [DRY RUN] ' + p.Name + ': "NOT COLLECTED" -> "NOT_COLLECTED"');
    }
} else {
    for (SM_Payment__c p : toFix) {
        p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
    }
    Database.SaveResult[] saves = Database.update(toFix, false);
    Integer ok = 0, fail = 0;
    for (Integer i = 0; i < saves.size(); i++) {
        if (saves[i].isSuccess()) {
            ok++;
        } else {
            fail++;
            System.debug('-> ERROR normalizando ' + toFix[i].Name + ': ' + saves[i].getErrors());
        }
    }
    System.debug('-> Normalizados OK: ' + ok + '   Fallidos: ' + fail);
}
