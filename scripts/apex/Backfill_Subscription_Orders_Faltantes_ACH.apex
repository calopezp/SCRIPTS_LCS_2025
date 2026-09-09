/*
 * Backfill_Subscription_Orders_Faltantes_ACH.apex
 * --------------------------------------------------
 * Mismo root cause que Backfill_AC_Orders_Faltantes_ACH.apex: la version
 * activa del orchestrator (CONTRACT_10_After_Save_Orchestrator) no llamaba
 * al subflow que crea la orden ACH de tipo "Subscription" cuando un
 * contrato pasa a Activated. A diferencia de CONTRACT_Create_ACH_AC_Order
 * (creado 2026-08-26), CONTRACT_Create_ACH_Subscription_Order YA estaba
 * Active desde 2026-08-12 (v1, Juan Duarte) -- el problema nunca fue el
 * subflow, fue que el orchestrator dejo de invocarlo (visto en la v4 activa
 * hasta 2026-09-09, que no tiene el subflow "Create_Subscription_Order").
 * Se corrigio al activar la v5 del orchestrator el 2026-09-09.
 *
 * Este script reproduce el nodo "Create_ACH_Subscription_Order" del flow
 * CONTRACT_Create_ACH_Subscription_Order para contratos que hoy cumplen
 * todas las condiciones de "If_Exists_Contract" (Activated, AC ya cobrado,
 * requiere RC/Subscription, etc.) pero no tienen ninguna orden Subscription.
 *
 * A diferencia del backfill de AC Orders, aqui NO se acota por fecha de
 * creacion del contrato -- el hueco viene de antes del 26-ago (se detectaron
 * contratos Activated desde 2026-07-23 sin su orden Subscription), asi que
 * se deja el filtro abierto y se revisa el preview con cuidado antes de
 * aplicar.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo preview, NO inserta nada.
 *   - Revisa el debug log completo (contratos + montos que se van a crear).
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo -> aplica el INSERT real.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = false; // <-- cambiar a false para ejecutar el insert real
// ========================================

System.debug('→  -> ======================================================');
System.debug('→  -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a insertar)'));
System.debug('→  -> ======================================================');

// 1) Mismos criterios que If_Exists_Contract en CONTRACT_Create_ACH_Subscription_Order,
//    mas el filtro de que no exista ya una orden Subscription no Completed/Canceled
//    (equivalente a Get_Subs_ACH_Order + If_Needs_to_Create_ACH_Order).
List<Contract> candidates = [
    SELECT Id, ContractNumber, Account.Name, Status, CreatedDate, SM_Start_date__c,
           SM_Net_Monthly_offer__c, SM_Payment_Method__c, SM_Email_to_send_contract__c
    FROM Contract
    WHERE SM_Payment_methods__c = 'ACH'
    AND Status = 'Activated'
    AND SM_AC_collected__c = true
    AND SM_Requires_RC_Payment__c = true
    AND Contract_Type__c != 'Dependent'
    AND Is_Test_Contract__c = false
    AND Is_VIP_Contract__c = false
    AND SM_Full_Payment__c = false
    AND SM_Customer_Cancellation__c = false
    AND SM_Billing_status__c != 'PAYMENT COMPLETED'
    // Cualquier orden Subscription ya existente (de cualquier estado)
    // descarta el contrato -- no duplicar.
    AND Id NOT IN (
        SELECT SM_Contract__c FROM SM_ACH_Order__c
        WHERE SM_Payment_Type__c = 'Subscription'
    )
    ORDER BY CreatedDate ASC
];

System.debug('→  -> Contratos candidatos (sin orden Subscription): ' + candidates.size());

// 2) Armar las ordenes a crear -- misma logica que Create_ACH_Subscription_Order.
List<SM_ACH_Order__c> ordersToInsert = new List<SM_ACH_Order__c>();

for (Contract c : candidates) {
    System.debug('→ PREVIEW -> ' + c.ContractNumber + ' (' + c.Account.Name + ') ｜ Start date=' + c.SM_Start_date__c
        + ' ｜ Monto mensual=' + c.SM_Net_Monthly_offer__c);

    ordersToInsert.add(new SM_ACH_Order__c(
        SM_Apply_penalty__c = false,
        SM_Billing_Email__c = c.SM_Email_to_send_contract__c,
        SM_Contract__c = c.Id,
        SM_Fee_to_collect__c = 1,
        SM_Next_Transaction_Date__c = c.SM_Start_date__c,
        SM_Payment_Condition__c = 'Fixed value',
        SM_Payment_Count__c = 1,
        SM_Payment_Frequency__c = 'Monthly',
        SM_Payment_Method__c = c.SM_Payment_Method__c,
        SM_Payment_Start_Date__c = c.SM_Start_date__c,
        SM_Payment_Status__c = 'Pending',
        SM_Payment_Type__c = 'Subscription',
        SM_Penalty_value__c = 0,
        SM_Total__c = c.SM_Net_Monthly_offer__c
    ));
}

System.debug('→  -> ======================================================');
System.debug('→  -> Ordenes Subscription a crear: ' + ordersToInsert.size());
System.debug('→  -> ======================================================');

// 3) Ejecutar el insert SOLO si DRY_RUN = false
if (!DRY_RUN) {
    if (ordersToInsert.isEmpty()) {
        System.debug('→  -> No hay ordenes para crear.');
    } else {
        List<Database.SaveResult> results = Database.insert(ordersToInsert, false);
        Integer okCount = 0;
        Integer errCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult res = results[i];
            if (res.isSuccess()) {
                okCount++;
                System.debug('→  ->   -> OK ' + res.getId() + ' (Contract ' + ordersToInsert[i].SM_Contract__c + ')');
            } else {
                errCount++;
                System.debug('ERROR creando orden para Contract ' + ordersToInsert[i].SM_Contract__c + ': '
                    + res.getErrors()[0].getMessage());
            }
        }
        System.debug('→  -> ======================================================');
        System.debug('→  -> INSERT COMPLETADO -> Exitos: ' + okCount + ' ｜ Errores: ' + errCount);
        System.debug('→  -> ======================================================');
    }
} else {
    System.debug('→  -> DRY RUN activo: no se inserto ninguna orden. Cambia DRY_RUN a false para aplicar los cambios.');
}
