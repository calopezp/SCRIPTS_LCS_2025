/**
 * Ejecución manual de SM_PaymentBatch (sin el batch, sin depender de SM_PaymentHandler)
 * -----------------------------------------------------------------------------------
 * Qué hace:
 *   1) Corre exactamente el mismo query que SM_PaymentBatch.start().
 *   2) Arma los SM_Payment__c con el mismo mapeo de campos que SM_PaymentHelper.createPayments().
 *   3) Inserta con SM_TriggerHandler.avoidAllHandlerExcecution = true, para que el
 *      afterInsert de SM_PaymentHandler (updateACHOrderInfo, upsertInvoiceByPayment,
 *      clonePayments, etc.) NO se ejecute -> evita el bug conocido "Argument cannot be null"
 *      y cualquier otra clase de Payment que esté fallando en ese trigger.
 *   4) Como ese afterInsert normalmente avanza el SM_ACH_Order__c (status / próxima fecha),
 *      este script replica esa parte (sin nada de Chargent) para que el ACH Order no quede
 *      "atascado" y se vuelva a procesar en la próxima corrida.
 *
 * OJO / revisar antes de correr en producción:
 *   - Existe un 2do trigger sobre SM_Payment__c: SM_PaymentTGR -> SM_paymentTGR_Handler.
 *     Esa clase SÍ extiende SM_TriggerHandler, así que avoidAllHandlerExcecution también
 *     la bypassea. Además su AfterInsert() está vacío (solo actúa en AfterUpdate, cuando
 *     cambia Payment_Status__c), así que no afecta a este script de todos modos.
 *   - Este script SÍ dispara: checkPaymentToSendChargentReceipt (beforeInsert, solo si el
 *     status del payment está en el label AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT) porque
 *     eso vive en beforeInsert() y beforeInsert también queda bypasseado por el flag, así
 *     que en realidad tampoco se ejecuta. Si necesitas ese efecto (marcar
 *     SM_Receipt_Status__c = 'Pending to Send'), avísame y lo agrego al mapeo manual.
 *   - Corre primero con un LIMIT chico (ya puesto abajo) y revisa el debug log antes de
 *     soltar el universo completo.
 */

// ============================================================
// 1) Mismo query que SM_PaymentBatch.start()
// ============================================================
Set<String> paymentTypes = new Set<String>{
    SM_ACHOrderHelper.paymentType.SUBSCRIPTION,
    SM_ACHOrderHelper.paymentType.AC,
    SM_ACHOrderHelper.paymentType.FEE,
    SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE
};
Set<String> paymentStatusExcluded = new Set<String>{
    SM_ACHOrderHelper.paymentStatus.COMPLETED,
    SM_ACHOrderHelper.paymentStatus.CANCELED,
    SM_ACHOrderHelper.paymentStatus.STOPPED
};
Date dateToProcess = System.today().addDays(1);

List<SM_ACH_Order__c> achOrders = [
    SELECT Id, SM_Payment_Type__c, SM_Charge_Date__c, SM_Payment_Method__c, SM_Next_Transaction_Date__c,
           SM_Total__c, SM_Fee_to_collect__c, SM_Apply_penalty__c, SM_Penalty_value__c, SM_Failed_payment__c,
           SM_Payment_Condition__c, SM_Payment_End_Date__c, SM_Payment_Frequency__c, SM_Quantity_of_scheduled_fees__c,
           SM_Contract__c, SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c, SM_Contract__r.SM_Payment_Method__c,
           SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c,
           SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c,
           SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,
           SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,
           SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c,
           SM_Contract__r.SM_Customer_Cancellation__c
    FROM SM_ACH_Order__c
    WHERE SM_Payment_Type__c IN :paymentTypes
    AND SM_Payment_Status__c NOT IN :paymentStatusExcluded
    AND SM_Next_Transaction_Date__c <= :dateToProcess
    AND SM_Contract__r.SM_Customer_Cancellation__c = false
    LIMIT 50 // <-- sube el número (o quítalo) cuando ya validaste el resultado
];

System.debug('\u2192 === ACH Orders a procesar: ' + achOrders.size());

// ============================================================
// 2) Mismo mapeo de campos que SM_PaymentHelper.createPayments()
// ============================================================
Id achRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
List<SM_Payment__c> paymentsToInsert = new List<SM_Payment__c>();

for (SM_ACH_Order__c achOrder : achOrders) {
    paymentsToInsert.add(new SM_Payment__c(
        RecordTypeId = achRecordTypeId,
        SM_Recurring__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION,
        SM_Type__c = achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? achOrder.SM_Payment_Type__c : 'Fee',
        SM_Payment_Method__c = achOrder.SM_Contract__r.SM_Payment_Method__c,
        SM_Contract__c = achOrder.SM_Contract__c,
        SM_Payment_Date__c = achOrder.SM_Next_Transaction_Date__c,
        Payment_Status__c = SM_PaymentHelper.status.ACH_PENDING,
        SM_ACH_Account_Number__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_ACH_Account_Number__c == null ? 0 : Decimal.valueOf(achOrder.SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c),
        SM_ACH_Account_Routing_Number__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_Routing_Number__c == null ? '' : achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c,
        SM_Routing_Number_Check_Digit__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_Routing_Number_Check_Digit__c == null ? null : Integer.valueOf(achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c),
        SM_Fee_to_collect__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? achOrder.SM_Fee_to_collect__c : null,
        SM_ACH_Order__c = achOrder.Id,
        SM_Amount__c = achOrder.SM_Total__c,
        SM_P_IVU_State_Amount__c = achOrder.SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,
        SM_P_IVU_Municipal_Amount__c = achOrder.SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c,
        SM_Penalty_value__c = achOrder.SM_Apply_penalty__c && achOrder.SM_Penalty_value__c > 0 ? achOrder.SM_Penalty_value__c : 0,
        SM_Fee_value__c = achOrder.SM_Apply_penalty__c ? achOrder.SM_Total__c - achOrder.SM_Penalty_value__c : achOrder.SM_Total__c,
        SM_Failed_payment__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE ? achOrder.SM_Failed_payment__c : null,
        SM_Original_Type__c = achOrder.SM_Payment_Type__c <> 'Late payment fee' ? achOrder.SM_Payment_Type__c : null
    ));
}

// ============================================================
// 3) Insertar SIN disparar la lógica del trigger handler
//    (evita el bug de updateACHOrderInfo / cualquier otra clase
//     de Payment que esté fallando en el afterInsert)
// ============================================================
Boolean previousBypassState = SM_TriggerHandler.avoidAllHandlerExcecution;
SM_TriggerHandler.avoidAllHandlerExcecution = true;

List<Database.SaveResult> paymentResults;
try {
    paymentResults = Database.insert(paymentsToInsert, false);
} finally {
    SM_TriggerHandler.avoidAllHandlerExcecution = previousBypassState;
}

Set<Id> achOrderIdsOk = new Set<Id>();
Integer successCount = 0;
for (Integer i = 0; i < paymentResults.size(); i++) {
    Database.SaveResult sr = paymentResults[i];
    SM_ACH_Order__c relatedAchOrder = achOrders[i];
    if (sr.isSuccess()) {
        successCount++;
        achOrderIdsOk.add(relatedAchOrder.Id);
        System.debug('\u2192 OK  -> Payment ' + sr.getId() + ' creado para ACH Order ' + relatedAchOrder.Id);
    } else {
        System.debug('\u2192 FAIL -> ACH Order ' + relatedAchOrder.Id + ' : ' + sr.getErrors());
    }
}
System.debug('\u2192 === Payments creados OK: ' + successCount + ' / ' + paymentsToInsert.size());

// ============================================================
// 4) Avanzar el ACH Order (sin nada de Chargent) para los que sí
//    generaron payment, igual que updateACHOrderInfo() lo hacía
// ============================================================
if (!achOrderIdsOk.isEmpty()) {
    Map<Id, SM_ACH_Order__c> achOrdersToUpdate = new Map<Id, SM_ACH_Order__c>([
        SELECT Id, SM_Payment_Condition__c, SM_Payment_End_Date__c, SM_Payment_Frequency__c,
               SM_Quantity_of_scheduled_fees__c, SM_Payment_Type__c, SM_Fee_to_collect__c,
               SM_Payment_Status__c, SM_Next_Transaction_Date__c,
               (SELECT Id FROM Payments__r)
        FROM SM_ACH_Order__c
        WHERE Id IN :achOrderIdsOk
    ]);

    for (SM_ACH_Order__c achOrder : achOrdersToUpdate.values()) {
        if (achOrder.SM_Payment_Condition__c != SM_ACHOrderHelper.paymentCondition.FIXED_VALUE
            && (System.today() < achOrder.SM_Payment_End_Date__c || achOrder.SM_Payment_End_Date__c == null)) {
            achOrder.SM_Fee_to_collect__c = (achOrder.SM_Fee_to_collect__c == null ? 0 : achOrder.SM_Fee_to_collect__c) + 1;
        }
        Integer qtyOfPayments = achOrder.Payments__r.size();
        if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.ONCE) {
            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
            achOrder.SM_Next_Transaction_Date__c = null;
        } else if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.MONTHLY) {
            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.INITIATED;
            if (achOrder.SM_Quantity_of_scheduled_fees__c > qtyOfPayments) {
                achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
            } else if (achOrder.SM_Quantity_of_scheduled_fees__c == qtyOfPayments) {
                achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                achOrder.SM_Next_Transaction_Date__c = null;
            } else if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION) {
                achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
            }
        }
    }

    List<Database.SaveResult> achUpdateResults = Database.update(achOrdersToUpdate.values(), false);
    Integer achOk = 0;
    for (Database.SaveResult sr : achUpdateResults) {
        if (sr.isSuccess()) {
            achOk++;
        } else {
            System.debug('\u2192 FAIL update ACH Order ' + sr.getId() + ' : ' + sr.getErrors());
        }
    }
    System.debug('\u2192 === ACH Orders actualizados OK: ' + achOk + ' / ' + achUpdateResults.size());
}

System.debug('\u2192 === FIN ===');
