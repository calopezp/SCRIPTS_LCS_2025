/*
 * notify_r02.apex
 * ----------------
 * Envia por correo a clopez@legal-credit.com la lista actual de contratos
 * con al menos un ACH Return codigo R02 (ACCOUNT CLOSED) sin resolver.
 *
 * A diferencia de NSF (fondos insuficientes), R02 significa que la cuenta
 * bancaria del metodo de pago ya no existe -- reintentar no sirve de nada,
 * hace falta que el cliente actualice su metodo de pago. Ver
 * SM_ReturnCodeNotifier.cls para la logica completa (que contratos se
 * excluyen, como se detecta si ya se recupero).
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_r02.apex
 */
SM_ReturnCodeNotifier.sendR02Report();
System.debug('\u2192 ' +'OK - reporte de R02 enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
