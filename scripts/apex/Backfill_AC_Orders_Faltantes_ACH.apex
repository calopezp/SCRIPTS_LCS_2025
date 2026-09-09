/*
 * Backfill_AC_Orders_Faltantes_ACH.apex
 * --------------------------------------
 * Contexto: CONTRACT_10_After_Save_Orchestrator (Contract, RecordAfterSave)
 * llego a tener una version 5 (Draft) creada 2026-08-26 que agregaba las
 * llamadas a CONTRACT_Create_ACH_AC_Order / CONTRACT_Create_ACH_Subscription_Order,
 * pero esa version nunca se activo -- la produccion siguio corriendo la v4
 * (sin esos subflows) hasta que se activo la v5 el 2026-09-09. Resultado:
 * ningun contrato ACH que llego a "Payment Process"/"Activated" entre esas
 * dos fechas recibio su SM_ACH_Order__c (SM_Payment_Type__c = 'AC') de forma
 * automatica.
 *
 * Este script reproduce EXACTAMENTE la logica del nodo "Create_ACH_AC_Order"
 * (y "Create_ACH_AC_Order_Split_Fee" si aplica SM_AC_Split_Date__c) del flow
 * CONTRACT_Create_ACH_AC_Order para los contratos que hoy cumplen todas sus
 * condiciones de entrada pero no tienen ninguna orden AC activa/pendiente.
 *
 * El filtro de contratos es el mismo "If_Exists_Contract" del flow (14
 * condiciones), asi que es seguro re-ejecutar este script en cualquier
 * momento: solo va a encontrar contratos que el flow tambien habria
 * procesado y que siguen sin su orden.
 *
 * MODO DE USO:
 *   - Corre primero con DRY_RUN = true  -> solo preview, NO inserta nada.
 *   - Revisa el debug log completo (contratos + montos que se van a crear).
 *   - Si todo esta correcto, cambia DRY_RUN a false y corre de nuevo -> aplica el INSERT real.
 */

// ============ CONFIGURACION ============
Boolean DRY_RUN = true; // <-- cambiar a false para ejecutar el insert real
// Ventana real del bug: CONTRACT_Create_ACH_AC_Order (v1) se creo el
// 2026-08-26 pero la v5 del orchestrator que lo invoca no se activo hasta
// el 2026-09-09. Fuera de esta ventana NO se debe tocar nada -- contratos
// mas viejos sin orden AC son una situacion historica distinta, no este bug.
DateTime OUTAGE_START = DateTime.newInstanceGmt(2026, 8, 26, 0, 0, 0);
DateTime OUTAGE_END = DateTime.newInstanceGmt(2026, 9, 9, 9, 3, 0);
// ========================================

System.debug('→  -> ======================================================');
System.debug('→  -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a insertar)'));
System.debug('→  -> ======================================================');

// 1) Mismos 14 criterios que If_Exists_Contract en CONTRACT_Create_ACH_AC_Order,
//    mas el filtro de que no exista ya una orden AC no Completed/Canceled
//    (equivalente a Get_AC_ACH_Order + If_Needs_to_Create_ACH_Order).
List<Contract> candidates = [
    SELECT Id, ContractNumber, Account.Name, Status, CreatedDate, SM_Net_AC__c, SM_AC_start_date__c,
           SM_AC_Split_Date__c, SM_Payment_Method__c, SM_Email_to_send_contract__c
    FROM Contract
    WHERE SM_Payment_methods__c = 'ACH'
    AND Status IN ('Payment Process', 'Activated')
    AND SM_Requires_AC_Payment__c = true
    AND SM_Net_AC__c != null
    AND SM_AC_start_date__c != null
    AND Contract_Type__c != 'Dependent'
    AND Is_Test_Contract__c = false
    AND Is_VIP_Contract__c = false
    AND SM_Full_Payment__c = false
    AND SM_Customer_Cancellation__c = false
    AND SM_Billing_status__c != 'PAYMENT COMPLETED'
    AND CB_Subscription__c = null
    AND CreatedDate >= :OUTAGE_START
    AND CreatedDate <= :OUTAGE_END
    // Cualquier orden AC ya existente (de cualquier estado) descarta el
    // contrato -- no queremos duplicar una orden que ya existe, sea cual
    // sea su estado actual.
    AND Id NOT IN (
        SELECT SM_Contract__c FROM SM_ACH_Order__c
        WHERE SM_Payment_Type__c = 'AC'
    )
    ORDER BY CreatedDate ASC
];

System.debug('→  -> Contratos candidatos (sin orden AC): ' + candidates.size());

// 2) Armar las ordenes a crear -- misma logica que Create_ACH_AC_Order /
//    Create_ACH_AC_Order_Split_Fee, incluyendo AC_Order_Amount
//    (Net_AC completo si no hay split, mitad y mitad si si hay).
List<SM_ACH_Order__c> ordersToInsert = new List<SM_ACH_Order__c>();

for (Contract c : candidates) {
    Boolean hasSplit = c.SM_AC_Split_Date__c != null;
    Decimal amount = hasSplit ? (c.SM_Net_AC__c / 2) : c.SM_Net_AC__c;

    System.debug('→ PREVIEW -> ' + c.ContractNumber + ' (' + c.Account.Name + ') ｜ Status=' + c.Status
        + ' ｜ AC start=' + c.SM_AC_start_date__c + ' ｜ Split=' + c.SM_AC_Split_Date__c
        + ' ｜ Monto orden principal=' + amount.setScale(2));

    ordersToInsert.add(new SM_ACH_Order__c(
        SM_Apply_penalty__c = false,
        SM_Billing_Email__c = c.SM_Email_to_send_contract__c,
        SM_Contract__c = c.Id,
        SM_Fee_to_collect__c = 1,
        SM_Next_Transaction_Date__c = c.SM_AC_start_date__c,
        SM_Payment_Condition__c = 'Fixed value',
        SM_Payment_Count__c = 1,
        SM_Payment_End_Date__c = c.SM_AC_start_date__c,
        SM_Payment_Frequency__c = 'Once',
        SM_Payment_Method__c = c.SM_Payment_Method__c,
        SM_Payment_Start_Date__c = c.SM_AC_start_date__c,
        SM_Payment_Status__c = 'Pending',
        SM_Payment_Type__c = 'AC',
        SM_Penalty_value__c = 0,
        SM_Total__c = amount.setScale(2)
    ));

    if (hasSplit) {
        Decimal splitAmount = c.SM_Net_AC__c / 2;
        System.debug('→ PREVIEW -> ' + c.ContractNumber + ' tiene Split Date -> segunda orden AC ｜ Split date='
            + c.SM_AC_Split_Date__c + ' ｜ Monto=' + splitAmount.setScale(2));

        ordersToInsert.add(new SM_ACH_Order__c(
            SM_Apply_penalty__c = false,
            SM_Billing_Email__c = c.SM_Email_to_send_contract__c,
            SM_Contract__c = c.Id,
            SM_Fee_to_collect__c = 1,
            SM_Next_Transaction_Date__c = c.SM_AC_Split_Date__c,
            SM_Payment_Condition__c = 'Fixed value',
            SM_Payment_Count__c = 1,
            SM_Payment_End_Date__c = c.SM_AC_Split_Date__c,
            SM_Payment_Frequency__c = 'Once',
            SM_Payment_Method__c = c.SM_Payment_Method__c,
            SM_Payment_Start_Date__c = c.SM_AC_Split_Date__c,
            SM_Payment_Status__c = 'Pending',
            SM_Payment_Type__c = 'AC',
            SM_Penalty_value__c = 0,
            SM_Total__c = splitAmount.setScale(2)
        ));
    }
}

System.debug('→  -> ======================================================');
System.debug('→  -> Ordenes AC a crear: ' + ordersToInsert.size() + ' (para ' + candidates.size() + ' contrato(s))');
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
