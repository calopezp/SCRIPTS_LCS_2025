/*
 * mark_transmitted_accepted.apex
 * -------------------------------
 * Ejecutar via run_mark_transmitted_accepted.sh (o "SFDX: Execute
 * Anonymous Apex" directo en VS Code).
 *
 * Automatiza la revision manual: busca Payments en estado
 * 'ACH TRANSMITTED' que llevan DAYS_SINCE_TRANSMITTED dias o mas
 * transmitidos y que NUNCA aparecieron en un reporte de Returns ni de
 * Check Collection (SM_Check_Collection_Status__c sigue null -- ver
 * SM_PaymentHandler.cls/SM_ReporteACHFileBatch.cls: nada mas que esos
 * dos procesos toca ese campo). Se asume que el ACH paso sin problema
 * y se marcan ACCEPTED/COLLECTED, con los mismos campos que se
 * registrarian si el banco hubiera confirmado el cobro.
 *
 * PRE-REQUISITO: correr primero el import de Returns/Collection del
 * dia (run_all_imports.sh apply, o run_import_return.sh /
 * run_import_collection.sh) para que cualquier reporte real que SI
 * llego ya este aplicado -- este script solo mira el estado ACTUAL en
 * Salesforce, no escanea PDFs.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo preview, NO actualiza nada.
 *   - Revisa el debug log completo.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo -> aplica el UPDATE real.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
Integer DAYS_SINCE_TRANSMITTED = 15;
// ========================================

Date cutoff = Date.today().addDays(-DAYS_SINCE_TRANSMITTED);

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a actualizar)'));
System.debug(' -> Corte: ACH TRANSMITTED antes de ' + cutoff + ' (' + DAYS_SINCE_TRANSMITTED + ' dia(s) o mas) y sin ningun reporte de Returns/Collection');
System.debug(' -> ======================================================');

// 1) Candidatos: transmitidos hace rato, sin ningun reporte
List<SM_Payment__c> candidates = [
    SELECT Id, Name, SM_ACH_Order__c, SM_Date_ACH_Transmitted__c, SM_Historical_Collection_Status__c
    FROM SM_Payment__c
    WHERE Payment_Status__c = 'ACH TRANSMITTED'
    AND SM_Date_ACH_Transmitted__c <= :cutoff
    AND SM_Check_Collection_Status__c = null
    ORDER BY SM_Date_ACH_Transmitted__c ASC
];

for (SM_Payment__c p : candidates) {
    System.debug('PREVIEW -> ' + p.Name + ' | Transmitido: ' + p.SM_Date_ACH_Transmitted__c + ' -> se marcaria ACCEPTED / SM_Check_Collection_Status__c: COLLECTED hoy');
}

// 2) Agrupar en OLEADAS por SM_ACH_Order__c -- mismo motivo que en
// Returns/Check Collection: SM_PaymentHandler (trigger AfterUpdate) no
// tolera la misma orden ACH dos veces en el mismo DML.
Map<Id, Integer> waveByAchOrder = new Map<Id, Integer>();
Map<Integer, List<SM_Payment__c>> waves = new Map<Integer, List<SM_Payment__c>>();
Integer maxWave = 0;

for (SM_Payment__c p : candidates) {
    Integer wave = 0;
    if (p.SM_ACH_Order__c != null) {
        wave = waveByAchOrder.containsKey(p.SM_ACH_Order__c) ? waveByAchOrder.get(p.SM_ACH_Order__c) + 1 : 0;
        waveByAchOrder.put(p.SM_ACH_Order__c, wave);
    }
    if (wave > maxWave) { maxWave = wave; }
    if (!waves.containsKey(wave)) { waves.put(wave, new List<SM_Payment__c>()); }
    waves.get(wave).add(p);
}

System.debug(' -> ======================================================');
System.debug(' -> Candidatos (ACH TRANSMITTED hace ' + DAYS_SINCE_TRANSMITTED + '+ dia(s), sin reporte): ' + candidates.size());
if (!candidates.isEmpty()) {
    System.debug(' -> Oleadas necesarias por colisiones de orden ACH repetida: ' + (maxWave + 1));
    for (Integer w = 0; w <= maxWave; w++) {
        System.debug(' ->   -> Oleada ' + (w + 1) + ': ' + waves.get(w).size() + ' registro(s)');
    }
}
System.debug(' -> ======================================================');

// 3) Ejecutar el update SOLO si DRY_RUN = false -- una oleada a la vez
if (!DRY_RUN) {
    if (candidates.isEmpty()) {
        System.debug(' -> No hay candidatos para actualizar.');
    } else {
        Date today = Date.today();
        Integer totalOk = 0;
        Integer totalErr = 0;
        for (Integer w = 0; w <= maxWave; w++) {
            List<SM_Payment__c> waveRows = waves.get(w);
            List<SM_Payment__c> waveUpdate = new List<SM_Payment__c>();
            for (SM_Payment__c p : waveRows) {
                // Marca distinta de "PRC_AUT:" para que quede claro en el
                // historico que esto NO vino de un reporte del banco, sino
                // de esta rutina de aceptacion por defecto tras N dias.
                String tag = 'PRC_AUT_' + DAYS_SINCE_TRANSMITTED + 'D_SIN_REPORTE: ACCEPTED //';
                String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
                String newHistorical = tag + previous;
                if (newHistorical.length() > 150) {
                    newHistorical = newHistorical.substring(0, 150);
                }
                waveUpdate.add(new SM_Payment__c(
                    Id = p.Id,
                    Payment_Status__c = 'ACCEPTED',
                    SM_Check_Collection_Date__c = today,
                    SM_Check_Collection__c = true,
                    SM_Check_Collection_Status__c = 'COLLECTED',
                    SM_Historical_Collection_Status__c = newHistorical
                ));
            }
            List<Database.SaveResult> results = Database.update(waveUpdate, false);
            Integer okCount = 0;
            Integer errCount = 0;
            for (Integer i = 0; i < results.size(); i++) {
                Database.SaveResult res = results[i];
                if (res.isSuccess()) {
                    okCount++;
                } else {
                    errCount++;
                    System.debug(
                        'ERROR actualizando ' + waveUpdate[i].Id + ': ' +
                        res.getErrors()[0].getMessage()
                    );
                }
            }
            System.debug(' ->   -> Oleada ' + (w + 1) + ' completada -> Exitos: ' + okCount + ' | Errores: ' + errCount);
            totalOk += okCount;
            totalErr += errCount;
        }
        System.debug(' -> ======================================================');
        System.debug(' -> UPDATE COMPLETADO -> Exitos: ' + totalOk + ' | Errores: ' + totalErr);
        System.debug(' -> ======================================================');
    }
} else {
    System.debug(' -> DRY RUN activo: no se ejecuto ningun UPDATE. Cambia DRY_RUN a false para aplicar los cambios.');
}
