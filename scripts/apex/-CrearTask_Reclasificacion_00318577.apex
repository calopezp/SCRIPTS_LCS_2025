/*
 * -CrearTask_Reclasificacion_00318577.apex
 * -------------------------------------------
 * Task de seguimiento para la reclasificacion de PY-01916531 (AC -> Fee,
 * abona la 1ra RC de octubre) y el ajuste de SM_Next_Transaction_Date__c de
 * la Subscription Order ACH-30203 (movida a martes 2026-11-03) -- ver
 * CLAUDE.md 2.2. Primera aplicacion de la regla permanente confirmada
 * 2026-10-05: toda accion "fuera del proceso normal" deja un Task, siempre
 * con confirmacion del usuario.
 *
 * MODO DE USO: correr primero con DRY_RUN=true.
 */

Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar real
String TASK_SUBJECT = 'TIADM - RECLASIFICACION AC->FEE (COBRO DUPLICADO)';
Id TASK_RECORD_TYPE_ID = '0121U00000085XiQAI';
Id TASK_OWNER_ID = '0051U000007bbx5QAA'; // Carlos Lopez

Contract c = [SELECT Id, ContractNumber FROM Contract WHERE ContractNumber = '00318577'];

String description = 'AUTO: RECLASIFICACION_AC_FEE - PY-01916531 (2do payment del cobro duplicado) reclasificado ' +
    'de AC a Fee para abonar la 1ra RC de octubre. Subscription ACH-30203 movida de 2026-10-01 a 2026-11-03 ' +
    '(martes, salta octubre ya cubierto). Ver CLAUDE.md seccion 2.2.';
description = description.left(255);

System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> PREVIEW Task -> Contrato: ' + c.ContractNumber + ' | Subject: ' + TASK_SUBJECT);
System.debug(' -> Description: ' + description);

if (!DRY_RUN) {
    Task t = new Task(
        Subject      = TASK_SUBJECT,
        WhatId       = c.Id,
        OwnerId      = TASK_OWNER_ID,
        RecordTypeId = TASK_RECORD_TYPE_ID,
        ActivityDate = Date.today(),
        Description  = description
    );
    insert t;
    System.debug(' -> Task creado: ' + t.Id);
} else {
    System.debug(' -> DRY RUN activo: no se creo nada.');
}
