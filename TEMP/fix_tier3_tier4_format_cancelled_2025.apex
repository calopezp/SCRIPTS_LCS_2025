/*
 * fix_tier3_tier4_format_cancelled_2025.apex
 * ---------------------------------------------
 * Corrige 98 Payments (contratos Cancelled) del mismo analisis de
 * validacion 2025 (TEMP/validacion_payments_contratos_cancelados_2025_2026-09-22.csv):
 *
 *   - Tier 3 (6): Payment_Status__c ya es correcto -- solo normaliza el
 *     casing de SM_Check_Collection_Status__c ("Collected"/"Not_collected"
 *     -> "COLLECTED"/"NOT_COLLECTED", el valor real del picklist). Sin
 *     cambio de significado.
 *   - Tier 4 (92, subset seguro de 110): Payment_Status__c ya es
 *     REJECTED en ambos lados (correcto, el cheque nunca se cobro) --
 *     corrige SM_Check_Collection_Status__c de PENDING a NOT_COLLECTED
 *     porque un reporte semanal posterior, con fecha propia parseable
 *     (ej. "Check Collections Jan 13 2026.pdf", "Reporte Feb 1-17.pdf"),
 *     confirma el resultado final -- mismo patron validado en el fix de
 *     Tier 1 (reporte individual posterior > recap trimestral ambiguo).
 *
 * EXCLUIDOS A PROPOSITO (18 de los 116 originales, NO estan en este
 * script): el subset "NOT_COLLECTED/Not_collected -> PENDING" completo.
 * Su unico soporte era "ResumenOctNovDec2025.pdf" con razon
 * "PASTDUE DATE <fecha futura>" en la MISMA fila que compite con un
 * "PENDING" del mismo archivo/fecha -- ambiguo por diseno (mismo patron
 * de doble entrada que en el Resumen de Tier 1/Tier 2). Ademas 16 de
 * los 18 ya tienen en vivo una fecha MAS RECIENTE que ese reporte y un
 * SM_Return_code__c='R01' poblado -- señal de que un evento real
 * posterior (no indexado) ya toco el registro, igual que el caso
 * PY-01738648/PY-01741839 de Tier 2 que resulto estar mal en la
 * direccion contraria. Revertirlos a PENDING sin mas evidencia repetiria
 * el mismo error. Quedan pendientes de revisión aparte
 * (TEMP/_excluded_18.csv).
 *
 * Sin triggers/handlers (SM_TriggerHandler.avoidAllHandlerExcecution),
 * mismo patron que los fixes anteriores de esta sesion.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-22 tras revisar el preview (98/98 sin saltos, bug de comparacion case-insensitive de Apex corregido con .equals())

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
    new TargetState('PY-01726132', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01729785', 'ACCEPTED', 'COLLECTED'),
    new TargetState('PY-01732677', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01732762', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01739486', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01739559', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01754245', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01754246', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756608', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756611', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756636', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756754', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756763', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756770', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756774', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756781', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756788', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756803', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756812', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756823', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756824', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01756839', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01758029', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01763737', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01763766', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764683', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764684', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764685', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764686', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764687', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764690', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764698', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764699', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01764707', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01765788', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01765920', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01766907', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769206', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769207', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769211', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769215', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769219', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769224', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769225', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769226', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769230', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769231', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769233', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769235', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01769826', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770730', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770732', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770733', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770738', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770741', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770743', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770744', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770745', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770746', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770747', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01770748', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771573', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771576', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771598', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771599', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771635', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771665', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771694', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771727', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771728', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771731', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771737', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771747', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771756', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771764', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771765', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771766', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771769', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771771', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771772', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771781', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771787', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771796', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771799', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771805', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771806', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771813', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771825', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771831', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771838', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771847', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771849', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771854', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771855', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771877', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771889', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01771891', 'REJECTED', 'NOT_COLLECTED'),
    new TargetState('PY-01772319', 'REJECTED', 'NOT_COLLECTED')
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
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> Payments encontrados: ' + payments.size() + ' (esperados: ' + targetByName.size() + ')');
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : payments) {
    TargetState t = targetByName.get(p.Name);
    if (p.SM_Contract__r == null || p.SM_Contract__r.Status != 'Cancelled') {
        System.debug(' -> ***** SALTADO (el contrato ya no esta Cancelled, revisar manualmente): ' + p.Name + ' -> ' + (p.SM_Contract__r != null ? p.SM_Contract__r.Status : '(sin contrato)'));
        continue;
    }
    // OJO: en Apex, == entre Strings es case-INSENSITIVE ('Collected' == 'COLLECTED' -> true).
    // Para los 6 casos de Tier 3 (solo normalizar casing) eso haria que este chequeo los saltara
    // de mas -- se necesita .equals() (case-sensitive de verdad) para detectar que sí hace falta
    // corregir el casing aunque Apex los considere "iguales".
    if (p.Payment_Status__c.equals(t.paymentStatus) && p.SM_Check_Collection_Status__c.equals(t.collectionStatus)) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente, no necesita cambio): ' + p.Name);
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
