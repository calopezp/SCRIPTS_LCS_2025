/*
 * notify_r07.apex
 * ----------------
 * Envia por correo a clopez@legal-credit.com la lista actual de contratos
 * con al menos un ACH Return codigo R07 (AUTHORIZATION REVOKED BY CUSTOMER)
 * sin resolver -- a diferencia de R10 (disputa de un cargo puntual), R07
 * es una revocacion permanente de la autorizacion, hace falta una
 * autorizacion nueva antes de volver a cobrar. Ver SM_ReturnCodeNotifier.cls
 * para la logica completa.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_r07.apex
 */
SM_ReturnCodeNotifier.sendR07Report();
System.debug('OK - reporte de R07 enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
