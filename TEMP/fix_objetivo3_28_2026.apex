/*
 * fix_objetivo3_28_2026.apex
 * -----------------------------
 * Aplica los 28 hallazgos solidos de la validacion "Objetivo 3" (ACH 2026,
 * SOLO REPORTE Y VALIDACION -> ahora confirmado por Carlos para aplicar):
 *
 *  - 26 payments en PENDING/RETURN que un reporte de Check Collection ya
 *    confirma como COLLECTED, sin aplicar (25 normales + PY-01773073, que
 *    estaba en NOT_COLLECTED y un reporte de enero 2026 lo revierte a
 *    cobrado).
 *  - PY-01901116: PENDING -> NOT_COLLECTED (reporte confirma no cobrado).
 *  - PY-01895410: caso R10 -- ya estaba ACCEPTED/COLLECTED de forma
 *    genuina (confirmado por historial), pero un R10 real y POSTERIOR
 *    (contracargo/disputa del cliente) lo revierte a NOT_COLLECTED. Regla
 *    confirmada por Carlos 2026-09-23: R10 siempre gana, sin importar el
 *    estado anterior. Ver CLAUDE.md 2.2 y BITACORA_HALLAZGOS_TECNICOS.md.
 *
 * Fechas de re-verificacion en vivo (2026-09-23): los 28 payments siguen
 * exactamente en el estado "actual" esperado, ninguno es Test/VIP, ninguno
 * cambio desde el analisis del 2026-09-22.
 *
 * Sin triggers/handlers de Apex (SM_TriggerHandler.avoidAllHandlerExcecution) --
 * OJO: esto NO bloquea el Flow nativo PAYMENT_Accumulate_AC_On_Contract
 * (solo bloquea el framework de triggers Apex). Para los AC que pasan a
 * ACCEPTED con SM_AC_collected__c=false en el contrato (PY-01900438,
 * PY-01900439), es exactamente el comportamiento esperado del Flow --
 * confirma un cobro real, no un side-effect no deseado. Para PY-01895410
 * el Flow NO aplica (solo dispara cuando el NUEVO valor es ACCEPTED, y
 * aqui vamos en direccion contraria).
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado 2026-09-23: "ok,, realiza la actualizacion," -- preview 28/28 validado

Map<String, String> targetPaymentStatus = new Map<String, String>{
    'PY-01902575' => 'ACCEPTED', 'PY-01902582' => 'ACCEPTED', 'PY-01902590' => 'ACCEPTED',
    'PY-01902594' => 'ACCEPTED', 'PY-01902615' => 'ACCEPTED', 'PY-01773073' => 'ACCEPTED',
    'PY-01902629' => 'ACCEPTED', 'PY-01890504' => 'ACCEPTED', 'PY-01901108' => 'ACCEPTED',
    'PY-01899134' => 'ACCEPTED', 'PY-01899192' => 'ACCEPTED', 'PY-01902648' => 'ACCEPTED',
    'PY-01902659' => 'ACCEPTED', 'PY-01902664' => 'ACCEPTED', 'PY-01902673' => 'ACCEPTED',
    'PY-01890517' => 'ACCEPTED', 'PY-01890532' => 'ACCEPTED', 'PY-01902678' => 'ACCEPTED',
    'PY-01902701' => 'ACCEPTED', 'PY-01901123' => 'ACCEPTED', 'PY-01899922' => 'ACCEPTED',
    'PY-01900438' => 'ACCEPTED', 'PY-01900439' => 'ACCEPTED', 'PY-01889253' => 'ACCEPTED',
    'PY-01894041' => 'ACCEPTED', 'PY-01902700' => 'ACCEPTED',
    'PY-01901116' => 'REJECTED',
    'PY-01895410' => 'REJECTED'
};

Map<String, String> targetCCS = new Map<String, String>{
    'PY-01902575' => 'COLLECTED', 'PY-01902582' => 'COLLECTED', 'PY-01902590' => 'COLLECTED',
    'PY-01902594' => 'COLLECTED', 'PY-01902615' => 'COLLECTED', 'PY-01773073' => 'COLLECTED',
    'PY-01902629' => 'COLLECTED', 'PY-01890504' => 'COLLECTED', 'PY-01901108' => 'COLLECTED',
    'PY-01899134' => 'COLLECTED', 'PY-01899192' => 'COLLECTED', 'PY-01902648' => 'COLLECTED',
    'PY-01902659' => 'COLLECTED', 'PY-01902664' => 'COLLECTED', 'PY-01902673' => 'COLLECTED',
    'PY-01890517' => 'COLLECTED', 'PY-01890532' => 'COLLECTED', 'PY-01902678' => 'COLLECTED',
    'PY-01902701' => 'COLLECTED', 'PY-01901123' => 'COLLECTED', 'PY-01899922' => 'COLLECTED',
    'PY-01900438' => 'COLLECTED', 'PY-01900439' => 'COLLECTED', 'PY-01889253' => 'COLLECTED',
    'PY-01894041' => 'COLLECTED', 'PY-01902700' => 'COLLECTED',
    'PY-01901116' => 'NOT_COLLECTED',
    'PY-01895410' => 'NOT_COLLECTED'
};

Map<String, Date> targetCollectionDate = new Map<String, Date>{
    'PY-01773073' => Date.newInstance(2026, 1, 7),
    'PY-01889253' => Date.newInstance(2026, 8, 31),
    'PY-01890504' => Date.newInstance(2026, 9, 1),
    'PY-01890517' => Date.newInstance(2026, 9, 1),
    'PY-01890532' => Date.newInstance(2026, 9, 2),
    'PY-01894041' => Date.newInstance(2026, 9, 3),
    'PY-01895410' => Date.newInstance(2026, 9, 4),
    'PY-01899134' => Date.newInstance(2026, 9, 9),
    'PY-01899192' => Date.newInstance(2026, 9, 9),
    'PY-01899922' => Date.newInstance(2026, 9, 11),
    'PY-01900438' => Date.newInstance(2026, 9, 14),
    'PY-01900439' => Date.newInstance(2026, 9, 14),
    'PY-01901108' => Date.newInstance(2026, 9, 15),
    'PY-01901116' => Date.newInstance(2026, 9, 15),
    'PY-01901123' => Date.newInstance(2026, 9, 15),
    'PY-01902575' => Date.newInstance(2026, 9, 16),
    'PY-01902582' => Date.newInstance(2026, 9, 16),
    'PY-01902590' => Date.newInstance(2026, 9, 16),
    'PY-01902594' => Date.newInstance(2026, 9, 16),
    'PY-01902615' => Date.newInstance(2026, 9, 16),
    'PY-01902629' => Date.newInstance(2026, 9, 16),
    'PY-01902648' => Date.newInstance(2026, 9, 16),
    'PY-01902659' => Date.newInstance(2026, 9, 16),
    'PY-01902664' => Date.newInstance(2026, 9, 16),
    'PY-01902673' => Date.newInstance(2026, 9, 16),
    'PY-01902678' => Date.newInstance(2026, 9, 16),
    'PY-01902700' => Date.newInstance(2026, 9, 16),
    'PY-01902701' => Date.newInstance(2026, 9, 16)
};

Set<String> targetNames = targetPaymentStatus.keySet();

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
    if (p.SM_Contract__r == null) {
        System.debug(' -> ***** SALTADO (sin contrato): ' + p.Name);
        continue;
    }
    if (p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) {
        System.debug(' -> ***** SALTADO (Test/VIP): ' + p.Name);
        continue;
    }

    String newPs = targetPaymentStatus.get(p.Name);
    String newCcs = targetCCS.get(p.Name);

    if (p.Payment_Status__c == newPs && p.SM_Check_Collection_Status__c == newCcs) {
        System.debug(' -> ***** SALTADO (ya coincide exactamente): ' + p.Name);
        continue;
    }

    String tag = 'PRC_AUT: ' + newCcs + ' //';
    String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
    String newHistorical = tag + previous;
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    SM_Payment__c upd = new SM_Payment__c(
        Id = p.Id,
        Payment_Status__c = newPs,
        SM_Check_Collection_Status__c = newCcs,
        SM_Check_Collection__c = true,
        SM_Check_Collection_Date__c = targetCollectionDate.get(p.Name),
        SM_Historical_Collection_Status__c = newHistorical
    );
    if (p.Name == 'PY-01895410') {
        upd.SM_Return_code__c = 'R10';
    }

    System.debug(
        'PREVIEW -> ' + p.Name + ' (Contrato ' + p.SM_Contract__r.ContractNumber + ', ' + p.SM_Contract__r.Status + ')' +
        ' | ' + p.Payment_Status__c + '/' + p.SM_Check_Collection_Status__c + ' -> ' + newPs + '/' + newCcs +
        ' | Fecha coleccion -> ' + targetCollectionDate.get(p.Name) +
        (p.Name == 'PY-01895410' ? ' | Return code -> R10' : '') +
        ' | Historico -> [' + newHistorical + ']'
    );

    toUpdate.add(upd);
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
