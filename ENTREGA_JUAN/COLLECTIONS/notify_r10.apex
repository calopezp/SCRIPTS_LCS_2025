/*
 * notify_r10.apex
 * ----------------
 * Envia por correo a clopez@legal-credit.com la lista actual de contratos
 * con al menos un ACH Return codigo R10 (CUSTOMER ADVISES NOT AUTHORIZED) o
 * R11 (ENTRY NOT PER AUTHORIZATION TERMS, misma familia de disputa, agregado
 * 2026-09-23) sin resolver -- el cliente le dijo al banco directamente que
 * no autoriza el cobro o que no cumple los terminos autorizados. Ver
 * SM_ReturnCodeNotifier.cls para la logica completa (que contratos se
 * excluyen, como se detecta si ya se recupero).
 *
 * Nota: esto es distinto del reporte R10 de Check Collection para Comercial
 * (CheckCollectionImport_R10_ClienteSolicitoDevolucion.csv, generado por
 * extract_check_collection.py) -- ese es un CSV por corrida, este es un
 * correo acumulativo del estado actual en Salesforce.
 *
 * Se corre automaticamente al final de run_daily_new_files.sh en modo
 * apply. Tambien se puede correr suelto:
 *   sf apex run -o MONEE -f COLLECTIONS/notify_r10.apex
 */
SM_ReturnCodeNotifier.sendR10Report();
System.debug('\u2192 ' +'OK - reporte de R10 enviado a ' + SM_ReturnCodeNotifier.NOTIFY_EMAIL);
