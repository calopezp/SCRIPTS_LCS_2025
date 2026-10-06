/*
 * notify_regresion_2026-10-06.apex
 * ----------------------------------
 * Envio manual, puntual: el guard de regresion de update_check_collection.apex
 * bloqueo 2 casos en la corrida de hoy (2026-10-06) ANTES de que el codigo
 * tuviera el envio de correo automatico (agregado hoy mismo, despues de esta
 * corrida). Se manda a mano para no perder el aviso de estos 2 casos.
 *
 * PY-01902689 (00318474) y PY-01907147 (00318063): ambos ya ACCEPTED/COLLECTED
 * via el piloto de contracargo R10/R11 (2026-10-05), un reporte de Check
 * Collection posterior los quiso devolver a transito -- bloqueados, sin
 * aplicar nada. Mismo patron "R10/R11 reportado como Pending despues del
 * propio return" (ver CLAUDE.md seccion 2.2 / TAREAS_PENDIENTES.md).
 */

String body = 'El reporte de Check Collection de hoy (2026-10-06) intento revertir 2 pago(s) ' +
    'que ya estaban ACCEPTED/COLLECTED (via el piloto de contracargo R10/R11 de ayer) de vuelta ' +
    'a RETURN/NOT COLLECTED -- el guard de regresion los bloqueo, NO se aplico nada.\n\n' +
    'Pagos: PY-01902689, PY-01907147\n' +
    'Contratos a revisar manualmente: 00318474, 00318063\n\n' +
    'Es el mismo patron "R10/R11 reportado como Pending despues del propio return" ya documentado ' +
    '(PY-01902689 es el caso original detectado ayer; PY-01907147 es un 2do caso real, confirma que ' +
    'no es aislado) -- ver CLAUDE.md seccion 2.2 / TAREAS_PENDIENTES.md. Revisar caso por caso con el ' +
    'banco, no se aplica nada automatico.\n\n' +
    '(Nota: a partir de hoy, update_check_collection.apex y update_ach_returns.apex mandan este ' +
    'correo [IMPORTANTE] automaticamente cuando el guard de regresion bloquea algo -- este envio es ' +
    'puntual, solo para cubrir estos 2 casos de la corrida de hoy que paso antes del cambio.)';

Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new String[]{ SM_ReturnCodeNotifier.NOTIFY_EMAIL });
mail.setSubject('[IMPORTANTE] Check Collection intento revertir 2 pago(s) ya cobrado(s) -- 2026-10-06');
mail.setPlainTextBody(body);
Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });

System.debug('-> Correo [IMPORTANTE] puntual enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
