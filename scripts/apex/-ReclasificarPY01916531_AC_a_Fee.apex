/*
 * -ReclasificarPY01916531_AC_a_Fee.apex
 * -----------------------------------------
 * Contrato 00318577 -- el 2do payment creado por el cobro ACH duplicado
 * confirmado (PY-01916531, ver CLAUDE.md 2.2 y Task 'TIADM - COBRO
 * DUPLICADO CONFIRMADO') se reclasifica de AC a Fee para abonar la 1ra RC
 * (mes de octubre), ya que el monto coincide exacto ($99 = SM_Monthly_offer__c)
 * y el contrato ya esta Activated. Pedido explicito del usuario 2026-10-05.
 *
 * Validado contra 3 Fee payments reales del pipeline (PY-01915498,
 * PY-01909525, PY-01909514): todos tienen SM_Original_Type__c='Subscription'
 * y su SM_ACH_Order__c apunta a la orden tipo Subscription, nunca a la AC --
 * por eso este cambio tambien actualiza Original_Type y relinkea el ACH
 * Order, no solo el Type. Invoice__c se deja SIN TOCAR (sigue apuntando a la
 * invoice de la AC) -- no se encontro un mecanismo seguro para generarle una
 * invoice propia de RC sin disparar triggers, y no es necesario para que el
 * abono funcione.
 *
 * Tambien mueve SM_Next_Transaction_Date__c de la Subscription Order
 * (ACH-30203) de 2026-10-01 a 2026-11-01 (salta octubre, ya cubierto) --
 * SM_Payment_Start_Date__c se deja SIN TOCAR (confirmado por el usuario).
 *
 * MODO DE USO: correr primero con DRY_RUN=true (preview, no escribe nada).
 */

Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar real

SM_Payment__c p = [
    SELECT Id, Name, SM_Type__c, SM_Original_Type__c, SM_ACH_Order__c, Payment_Status__c
    FROM SM_Payment__c
    WHERE Name = 'PY-01916531'
];

SM_ACH_Order__c subOrder = [
    SELECT Id, Name, SM_Payment_Type__c, SM_Next_Transaction_Date__c
    FROM SM_ACH_Order__c
    WHERE Name = 'ACH-30203'
];

System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN' : 'EJECUCION REAL'));
System.debug(' -> Payment actual: ' + p.Name + ' | Type: ' + p.SM_Type__c + ' | OriginalType: ' + p.SM_Original_Type__c +
    ' | ACH Order: ' + p.SM_ACH_Order__c);
System.debug(' -> PREVIEW Payment -> Type: Fee | OriginalType: Subscription | ACH Order: ' + subOrder.Id + ' (' + subOrder.Name + ')');
System.debug(' -> Subscription Order actual: ' + subOrder.Name + ' | Next_Transaction_Date: ' + subOrder.SM_Next_Transaction_Date__c);
System.debug(' -> PREVIEW Subscription Order -> Next_Transaction_Date: 2026-11-01');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    try {
        p.SM_Type__c = 'Fee';
        p.SM_Original_Type__c = 'Subscription';
        p.SM_ACH_Order__c = subOrder.Id;
        update p;
        System.debug(' -> Payment actualizado: ' + p.Name);
    } finally {
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }

    subOrder.SM_Next_Transaction_Date__c = Date.newInstance(2026, 11, 1);
    update subOrder;
    System.debug(' -> Subscription Order actualizada: ' + subOrder.Name + ' -> Next_Transaction_Date = 2026-11-01');

    System.debug(' -> COMPLETADO.');
} else {
    System.debug(' -> DRY RUN activo: no se escribio nada. Cambia DRY_RUN a false para aplicar.');
}
