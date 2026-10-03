/*
 * -ApplyBankReferenceBackfill.apex
 * ---------------------------------
 * Backfill PUNTUAL (no recurrente) de SM_Bank_Reference_Number__c para los
 * ultimos 3 meses -- confirmado explicitamente por el usuario 2026-10-03:
 * "SIN CAMBIAR ESTADO U ALGUN OTRO DATO DEL PAYMENT".
 *
 * Este script SOLO toca SM_Bank_Reference_Number__c. Nunca lee ni escribe
 * Payment_Status__c ni ningun otro campo del Payment -- confirmado contra
 * SM_PaymentHandler.cls que TODOS sus efectos secundarios (clonar a
 * dependientes, cancelar ACH Order, enviar recibo, etc.) estan
 * condicionados a que Payment_Status__c cambie (SM_Utils.isChangedField),
 * asi que un update que deja ese campo intacto no dispara ninguno.
 *
 * PRE-REQUISITO:
 *   1. Generar el CSV: python COLLECTIONS/backfill_bank_reference_number.py
 *   2. Copiarlo a: force-app/main/default/staticresources/BankReferenceBackfill.csv
 *   3. Deploy: sf project deploy start -m StaticResource:BankReferenceBackfill
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo.
 *
 * Se salta cualquier fila cuyo Payment ya tenga ese EXACTO valor (evita
 * updates vacios). Si el Payment ya tiene un valor DISTINTO (ej. porque
 * el pipeline diario normal ya lo toco despues de que se genero este CSV),
 * se COMPLEMENTA igual que en update_ach_returns.apex/update_check_collection.apex
 * -- nunca se pisa.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el update real
String STATIC_RESOURCE_NAME = 'BankReferenceBackfill';
Integer BANK_REF_MAX_LENGTH = 120;
// ========================================

System.debug(' -> ======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a actualizar)'));
System.debug(' -> ======================================================');

StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = :STATIC_RESOURCE_NAME LIMIT 1];
String csvBody = sr.Body.toString();

List<String> lines = csvBody.split('\r\n');
if (lines.size() == 1) {
    lines = csvBody.split('\n');
}

Map<String, String> tagsByPayment = new Map<String, String>();
for (Integer i = 1; i < lines.size(); i++) {
    if (String.isBlank(lines[i])) { continue; }
    List<String> cols = lines[i].split(',');
    if (cols.size() < 2) { continue; }
    tagsByPayment.put(cols[0].trim(), cols[1].trim());
}

System.debug(' -> Payments en el CSV: ' + tagsByPayment.size());

Map<String, SM_Payment__c> paymentByName = new Map<String, SM_Payment__c>();
for (SM_Payment__c p : [
    SELECT Id, Name, SM_Bank_Reference_Number__c
    FROM SM_Payment__c
    WHERE Name IN :tagsByPayment.keySet()
]) {
    paymentByName.put(p.Name, p);
}

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();
List<String> notFound = new List<String>();
Integer alreadyUpToDate = 0;
Integer complemented = 0;

for (String paymentName : tagsByPayment.keySet()) {
    SM_Payment__c match = paymentByName.get(paymentName);
    if (match == null) {
        notFound.add(paymentName);
        continue;
    }

    String csvValue = tagsByPayment.get(paymentName);
    String currentValue = match.SM_Bank_Reference_Number__c;

    if (currentValue == csvValue) {
        alreadyUpToDate++;
        continue;
    }

    String newValue;
    if (String.isBlank(currentValue)) {
        newValue = csvValue;
    } else {
        // Ya tiene algo (el pipeline diario normal ya lo toco despues de
        // generado el CSV) -- complementar con cualquier tag del CSV que
        // todavia no este, nunca pisar.
        List<String> currentTags = currentValue.split('\\|');
        List<String> csvTags = csvValue.split('\\|');
        String combined = currentValue;
        for (String t : csvTags) {
            String trimmed = t.trim();
            if (!combined.contains(trimmed)) {
                combined += ' | ' + trimmed;
            }
        }
        if (combined == currentValue) {
            alreadyUpToDate++;
            continue; // todos los tags del CSV ya estaban incluidos
        }
        newValue = combined.length() > BANK_REF_MAX_LENGTH
            ? combined.substring(combined.length() - BANK_REF_MAX_LENGTH)
            : combined;
        complemented++;
    }

    toUpdate.add(new SM_Payment__c(Id = match.Id, SM_Bank_Reference_Number__c = newValue));

    if (toUpdate.size() <= 20) {
        System.debug('PREVIEW -> ' + paymentName + ' | actual: [' + currentValue + '] -> nuevo: [' + newValue + ']');
    }
}

System.debug(' -> ======================================================');
System.debug(' -> Payments SIN match en Salesforce: ' + notFound.size());
System.debug(' -> Ya tenian exactamente este valor (se omiten): ' + alreadyUpToDate);
System.debug(' -> Complementados (ya tenian OTRO valor distinto): ' + complemented);
System.debug(' -> Pendientes de aplicar en esta corrida: ' + toUpdate.size());
System.debug(' -> (preview arriba limitado a los primeros 20 -- el resto se aplica igual)');
System.debug(' -> ======================================================');

if (!DRY_RUN) {
    if (toUpdate.isEmpty()) {
        System.debug(' -> No hay registros pendientes de aplicar.');
    } else {
        // Solo SM_Bank_Reference_Number__c va en cada SObject -- ningun otro
        // campo (incluido Payment_Status__c) se toca en este update.
        List<Database.SaveResult> results = Database.update(toUpdate, false);
        Integer okCount = 0;
        Integer errCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                okCount++;
            } else {
                errCount++;
                System.debug('ERROR actualizando ' + toUpdate[i].Id + ': ' + results[i].getErrors()[0].getMessage());
            }
        }
        System.debug(' -> ======================================================');
        System.debug(' -> UPDATE COMPLETADO -> Exitos: ' + okCount + ' | Errores: ' + errCount);
        System.debug(' -> ======================================================');
    }
} else {
    System.debug(' -> DRY RUN activo: no se ejecuto ningun UPDATE. Cambia DRY_RUN a false para aplicar los cambios.');
}
