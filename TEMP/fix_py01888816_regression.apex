/*
 * fix_py01888816_regression.apex
 * --------------------------------
 * PY-01888816 (Contrato 00317953, Cancelled) quedo bloqueado por el guard
 * de regresion de update_check_collection.apex/update_ach_returns.apex el
 * 2026-09-18: su historico venia de PRC_AUT_FIX_CANCELLED_CONTRACT_ORDER
 * (fix_stuck_cancelled_contracts.apex, 2026-09-16), no del timeout de
 * 15/20 dias -- asi que NO califica para la excepcion que deja a un
 * reporte real corregir un ACCEPTED/COLLECTED, y se quedo en ACCEPTED sin
 * los campos de control del reporte real.
 *
 * Dos reportes distintos tienen data para este pago:
 *   - Returns, fecha interna 2026-08-27: RETURN / R11 / "CUST ADVISES INCORRECT"
 *   - Check Collection, fecha interna 2026-09-15: PENDING / R11 CHECK TRUNC E
 * Regla de negocio del pipeline ("gana el mas reciente, empate ->
 * Collection"): 2026-09-15 > 2026-08-27, gana Collection -- mismo target
 * que ya se aplico a los 3 pagos hermanos (PY-01888808/831/987).
 *
 * El ACH Order (ACH-28544) ya quedo 'Completed' por
 * fix_stuck_cancelled_contracts.apex el 2026-09-16 -- SM_PaymentHandler
 * reintentaria tocar esa orden en cualquier cambio de Payment_Status__c en
 * un contrato Cancelled (bug conocido, no se toca aqui, ver ese mismo
 * script), asi que este update tambien bypassea los handlers para no
 * revertir ese fix por accidente.
 *
 * Corre primero con DRY_RUN = true -> solo preview, NO actualiza nada.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-18 tras revisar el preview

SM_Payment__c p = [
    SELECT Id, Name, Payment_Status__c, SM_Check_Collection__c, SM_Check_Collection_Date__c,
           SM_Check_Collection_Status__c, SM_Return_code__c, SM_Historical_Collection_Status__c
    FROM SM_Payment__c
    WHERE Name = 'PY-01888816'
    LIMIT 1
];

String tag = 'PRC_AUT: PENDING //';
String previous = p.SM_Historical_Collection_Status__c == null ? '' : p.SM_Historical_Collection_Status__c;
String newHistorical = tag + previous;
if (newHistorical.length() > 150) {
    newHistorical = newHistorical.substring(0, 150);
}

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL'));
System.debug(' -> ACTUAL -> Payment_Status: ' + p.Payment_Status__c + ' | Check_Collection_Status: ' + p.SM_Check_Collection_Status__c + ' | Return_code: ' + p.SM_Return_code__c);
System.debug(' -> NUEVO  -> Payment_Status: REJECTED | Check_Collection_Status: PENDING | Return_code: R11 | Check_Collection_Date: 2026-09-15');
System.debug(' -> Historico nuevo -> ' + newHistorical);
System.debug('=======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    p.Payment_Status__c = 'REJECTED';
    p.SM_Check_Collection_Date__c = Date.valueOf('2026-09-15');
    p.SM_Check_Collection__c = true;
    p.SM_Check_Collection_Status__c = 'PENDING';
    p.SM_Check_Collection_Return_Reason__c = 'R11';
    p.SM_Return_code__c = 'R11';
    p.SM_Historical_Collection_Status__c = newHistorical;
    update p;
    SM_TriggerHandler.avoidAllHandlerExcecution = false;
    System.debug(' -> UPDATE COMPLETADO.');
} else {
    System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para aplicar.');
}
