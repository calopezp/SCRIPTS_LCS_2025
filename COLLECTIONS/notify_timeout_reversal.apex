/*
 * notify_timeout_reversal.apex
 * -----------------------------
 * Envia por correo a clopez@legal-credit.com la lista actual de pagos que
 * mark_transmitted_accepted.apex marco ACCEPTED/COLLECTED por timeout (sin
 * reporte del banco en 15/20 dias) y que un reporte REAL de Returns/
 * Collection, llegado despues, contradijo (Payment_Status__c = REJECTED, o
 * SM_Check_Collection_Status__c = RETURN/NOT COLLECTED/PENDING). Ver
 * SM_ReturnCodeNotifier.sendTimeoutReversalReport() para la logica completa
 * (por que existe, como se detecta desde SM_Historical_Collection_Status__c).
 *
 * Hallazgo real 2026-09-18: PY-01888808/PY-01888831/PY-01888987, los 3
 * marcados "PRC_AUT_15D_SIN_REPORTE" y luego confirmados por el banco como
 * otra cosa -- sin este correo no habia forma rapida de notar el patron.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_timeout_reversal.apex
 */
SM_ReturnCodeNotifier.sendTimeoutReversalReport();
System.debug('→ ' +'OK - reporte de reversiones por timeout enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
