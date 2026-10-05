/*
 * notify_duplicate_real_charge.apex
 * -----------------------------------
 * Alerta diaria: un SM_Payment__c con 2+ tags en SM_Bank_Reference_Number__c
 * (ej. "RTN:xxx | RTN:yyy") es INDICIO de que el banco proceso 2
 * transacciones reales distintas para el mismo payment -- pero OJO, NO es
 * por si sola confirmacion suficiente (corregido 2026-10-05, ver caso
 * PY-01902590 en TAREAS_PENDIENTES.md/Cerrado recientemente): el extractor
 * de PDF (extract_check_collection.py) documenta que cuando el campo DRAWEE
 * NAME de una fila ya viene como "PY-xxxxx" en vez de un nombre real de
 * cliente, el CHECK NUMBER de esa fila NO es confiable -- puede generar 2+
 * tags distintos en SM_Bank_Reference_Number__c sin que haya 2 transacciones
 * reales. La UNICA confirmacion suficiente para tratar un caso como cobro
 * duplicado real (y crear un 2do payment) es que el mismo payment aparezca
 * en 2 archivos ACH_<fecha>.csv DISTINTOS en
 * ACH_REPORTADOS/index/transmission_index.csv -- igual que se confirmo para
 * PY-01907641/PY-01907642 (ver abajo). Sin esa confirmacion de transmision,
 * un caso marcado por este script queda solo como candidato a revisar, no
 * como duplicado confirmado.
 *
 * Nace del caso real 2026-10-04: PY-01907641/00318012 y PY-01907642/00318146
 * (lote transmitido 2 veces por el bug de -A, ver CLAUDE.md seccion 2.2) se
 * encontraron a mano revisando el contrato, no por ninguna alerta -- este
 * script cierra ese hueco para cualquier caso futuro, no solo ese lote.
 *
 * NO corrige nada solo -- cada caso necesita criterio (crear un 2do payment
 * SOLO si ademas hay confirmacion en transmission_index.csv de que se
 * transmitio 2 veces, o un contracargo si una es un R10/R11, u otra cosa).
 * Solo reporta. Idempotente: excluye payments que ya tienen la nota "MANUAL:
 * Backfill cobro ACH duplicado" o "MANUAL: Contracargo" en
 * SM_Id_Salesforce_LCS__c (ya se resolvieron, ver
 * -ApplyBankReferenceBackfill.apex / scripts/apex/-CrearPaymentDuplicado_*.apex
 * / scripts/apex/-CONTRACARGO_ACH_R10_R11.apex), o que ya tienen un
 * SM_Payment__c REFUNDED apuntandoles via SM_Payments_refunded__c.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo apply
 * (junto a los otros 6 correos de SM_ReturnCodeNotifier). Tambien se puede
 * correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_duplicate_real_charge.apex
 */

String NOTIFY_EMAIL = 'clopez@legal-credit.com';
Boolean DRY_RUN = true; // <-- cambiar a false para enviar el correo real

List<SM_Payment__c> rawCandidatos = [
    SELECT Id, Name, SM_Contract__r.ContractNumber, SM_Amount__c, SM_Bank_Reference_Number__c,
           Payment_Status__c, SM_Check_Collection_Status__c, SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE SM_Bank_Reference_Number__c LIKE '%|%'
];

// Un payment normal que se devolvio UNA vez y luego se recobro tiene
// exactamente 1 tag "RTN:" + 1 tag "COL:" -- eso es el ciclo de vida
// normal de cualquier NSF resuelto, NO evidencia de doble cobro. La señal
// real (confirmada con PY-01907641/PY-01907642, ambos con 2 "RTN:"
// distintos) es 2+ VALORES DISTINTOS del MISMO prefijo (2+ "RTN:" o 2+
// "COL:" con numero real diferente) -- eso solo pasa cuando hubo 2 eventos
// reales separados del mismo tipo.
//
// OJO: el mismo numero puede aparecer escrito distinto segun que script lo
// escribio (ej. "COL:1860337" del backfill vs "COL:00001860337" del
// pipeline diario, mismo Check Number con/sin ceros a la izquierda) -- se
// normaliza quitando ceros a la izquierda antes de comparar, si no cualquier
// payment asi se cuenta como falso duplicado.
List<SM_Payment__c> candidatos = new List<SM_Payment__c>();
for (SM_Payment__c p : rawCandidatos) {
    Map<String, Set<String>> valoresNormalizadosByPrefix = new Map<String, Set<String>>();
    for (String tag : p.SM_Bank_Reference_Number__c.split('\\|')) {
        String trimmed = tag.trim();
        Integer colonIdx = trimmed.indexOf(':');
        if (colonIdx <= 0) { continue; }
        String prefix = trimmed.substring(0, colonIdx);
        String valorRaw = trimmed.substring(colonIdx + 1).trim();
        String valorNormalizado = valorRaw.replaceFirst('^0+', '');
        if (String.isBlank(valorNormalizado)) { valorNormalizado = '0'; }
        if (!valoresNormalizadosByPrefix.containsKey(prefix)) {
            valoresNormalizadosByPrefix.put(prefix, new Set<String>());
        }
        valoresNormalizadosByPrefix.get(prefix).add(valorNormalizado);
    }
    Boolean mismoTipoValorDistinto = false;
    for (Set<String> valores : valoresNormalizadosByPrefix.values()) {
        if (valores.size() >= 2) { mismoTipoValorDistinto = true; break; }
    }
    if (mismoTipoValorDistinto) {
        candidatos.add(p);
    }
}

Set<Id> idsConRefundYaCreado = new Set<Id>();
if (!candidatos.isEmpty()) {
    for (SM_Payment__c refund : [
        SELECT SM_Payments_refunded__c
        FROM SM_Payment__c
        WHERE SM_Payments_refunded__c IN :candidatos
        AND Payment_Status__c = 'REFUNDED'
    ]) {
        idsConRefundYaCreado.add(refund.SM_Payments_refunded__c);
    }
}

List<SM_Payment__c> pendientes = new List<SM_Payment__c>();
for (SM_Payment__c p : candidatos) {
    String nota = p.SM_Id_Salesforce_LCS__c == null ? '' : p.SM_Id_Salesforce_LCS__c;
    Boolean yaResuelto = nota.contains('MANUAL: Backfill cobro ACH duplicado')
        || nota.contains('MANUAL: Se creo payment duplicado')
        || nota.contains('MANUAL: Contracargo')
        || idsConRefundYaCreado.contains(p.Id);
    if (!yaResuelto) {
        pendientes.add(p);
    }
}

System.debug('→ Payments con 2+ trace/check numbers reales: ' + candidatos.size() +
    ' | Ya resueltos: ' + (candidatos.size() - pendientes.size()) +
    ' | Pendientes de revisar: ' + pendientes.size());

if (pendientes.isEmpty()) {
    System.debug('→ Sin novedades -- no se envia correo.');
} else {
    String body = 'Payments con evidencia REAL de 2 transacciones bancarias distintas ' +
        '(2+ trace/check numbers en SM_Bank_Reference_Number__c), pendientes de revisar:\n\n';
    for (SM_Payment__c p : pendientes) {
        body += p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ') -- $' + p.SM_Amount__c +
            ' -- ' + p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c +
            ' -- ' + p.SM_Bank_Reference_Number__c + '\n';
    }
    body += '\nCada caso necesita revision manual: puede ser un cobro doble real (crear un 2do ' +
        'SM_Payment__c, ver scripts/apex/-CrearPaymentDuplicado_PY01907641.apex como referencia) o ' +
        'un contracargo R10/R11 (ver scripts/apex/-CONTRACARGO_ACH_R10_R11.apex) u otra situacion.';

    for (SM_Payment__c p : pendientes) {
        System.debug('PREVIEW -> ' + p.Name + ' (' + p.SM_Contract__r.ContractNumber + ') -- $' + p.SM_Amount__c +
            ' -- ' + p.SM_Bank_Reference_Number__c);
    }
    if (!DRY_RUN) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject('[ALERTA] Payments con cobro real duplicado (2+ trace numbers) - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
        System.debug('→ Correo enviado a ' + NOTIFY_EMAIL + ' -- ' + pendientes.size() + ' payment(s) pendientes.');
    } else {
        System.debug('→ DRY RUN activo: no se envio correo. Cambia DRY_RUN a false para enviarlo de verdad.');
    }
}
