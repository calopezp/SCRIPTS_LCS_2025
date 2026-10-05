/*
 * -FixFechasACH30203.apex
 * --------------------------
 * El update anterior (-ReclasificarPY01916531_AC_a_Fee.apex) dejo
 * SM_Next_Transaction_Date__c en 2026-10-31 (no 2026-11-01 como se pidio
 * originalmente). Causa raiz real (no un bug, comportamiento de produccion
 * existente): SM_ACHOrderHandler.updateNextScheduledPaymentDate() ajusta
 * SIEMPRE la fecha al dia habil mas cercano via
 * SM_Utils.getSuggestedBusinessHour('Monee Business Hour') cuando
 * SM_Next_Transaction_Date__c cambia, y acopla ese campo con
 * SM_Payment_Start_Date__c (los pone iguales) -- no se puede cambiar uno
 * sin que el otro se recalcule tambien, sin bypassear por completo (lo cual
 * saltaria la validacion de dia habil, indeseable).
 *
 * Segundo intento (2026-11-02, sin bypass) tambien colapso a 2026-10-31 --
 * causa real completa: SM_ACHOrderHandler.getPaymentDayFromCtAndSetInACHOrder()
 * FUERZA el dia del mes a SM_Payment_day__c del contrato (=1) sin importar
 * que dia se intente poner, ANTES de que corra el ajuste de dia habil -- asi
 * que cualquier intento sin bypass termina forzado a dia 1 del mes, y como
 * 2026-11-01 es domingo, el ajuste de negocio lo retrocede a 2026-10-31.
 *
 * Confirmado por el usuario 2026-10-05: usar MARTES 2026-11-03 para
 * Next_Transaction_Date, CON bypass total (unica forma de lograr una fecha
 * limpia en noviembre dado el forzado de dia) -- SM_Payment_Start_Date__c
 * se restaura a 2026-10-01 (el valor original, como se pidio en la primera
 * version de este fix). El domingo/martes no afecta la transmision real
 * (-A.ReporteACHFile filtra por Payment_Status__c, no por esta fecha).
 *
 * MODO DE USO: correr primero con DRY_RUN=true.
 */

Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar real

SM_ACH_Order__c o = [
    SELECT Id, Name, SM_Next_Transaction_Date__c, SM_Payment_Start_Date__c
    FROM SM_ACH_Order__c
    WHERE Name = 'ACH-30203'
];

System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Actual -> Next_Transaction_Date: ' + o.SM_Next_Transaction_Date__c + ' | Start_Date: ' + o.SM_Payment_Start_Date__c);
System.debug(' -> PREVIEW -> Next_Transaction_Date: 2026-11-03 (martes) | Start_Date: 2026-10-01 (restaurado) -- CON bypass');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        o.SM_Next_Transaction_Date__c = Date.newInstance(2026, 11, 3);
        o.SM_Payment_Start_Date__c = Date.newInstance(2026, 10, 1);
        update o;
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }

    SM_ACH_Order__c verif = [SELECT SM_Next_Transaction_Date__c, SM_Payment_Start_Date__c FROM SM_ACH_Order__c WHERE Id = :o.Id];
    System.debug(' -> VERIFICADO INMEDIATO -> Next_Transaction_Date: ' + verif.SM_Next_Transaction_Date__c + ' | Start_Date: ' + verif.SM_Payment_Start_Date__c);
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada.');
}
