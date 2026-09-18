/*
 * notify_invalid_account.apex
 * -----------------------------
 * Envia por correo a clopez@legal-credit.com la lista actual de contratos
 * con al menos un ACH Return codigo R04 (numero de cuenta invalido) o R13
 * (routing number invalido) sin resolver -- mismo problema de fondo (el
 * dato bancario esta mal capturado), un solo reporte combinado. Ver
 * SM_ReturnCodeNotifier.cls para la logica completa.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_invalid_account.apex
 */
SM_ReturnCodeNotifier.sendInvalidAccountReport();
System.debug('\u2192 ' +'OK - reporte de R04/R13 enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
