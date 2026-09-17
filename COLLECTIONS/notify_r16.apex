/*
 * notify_r16.apex
 * ----------------
 * Envia por correo a clopez@legal-credit.com la lista actual de contratos
 * con al menos un ACH Return codigo R16 (ACCOUNT FROZEN) sin resolver --
 * usualmente una orden legal/judicial, fuera del control del cliente. Ver
 * SM_ReturnCodeNotifier.cls para la logica completa.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_r16.apex
 */
SM_ReturnCodeNotifier.sendR16Report();
System.debug('\u2192 ' +'OK - reporte de R16 enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
