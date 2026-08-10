/**
 * SIMULACIÓN (solo lectura) de Crear_Payments_Manual_SM_PaymentBatch.apex
 * -------------------------------------------------------------------------
 * NO hace insert ni update. Corre el mismo query, arma los SM_Payment__c en
 * memoria con el mismo mapeo, y reporta:
 *   - Cuántos ACH Orders matchean el criterio del batch hoy.
 *   - Breakdown por SM_Payment_Type__c.
 *   - Alertas de datos que podrían hacer fallar el insert real (campos nulos
 *     clave: Payment Method, Total, Next Transaction Date).
 *   - Muestra de los primeros 5 Payments que se armarían, con sus valores.
 */

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
    SELECT Id, Name, SM_Payment_Type__c, SM_Charge_Date__c, SM_Payment_Method__c, SM_Next_Transaction_Date__c,
           SM_Total__c, SM_Fee_to_collect__c, SM_Apply_penalty__c, SM_Penalty_value__c, SM_Failed_payment__c,
           SM_Payment_Condition__c, SM_Payment_End_Date__c, SM_Payment_Frequency__c, SM_Quantity_of_scheduled_fees__c,
           SM_Payment_Status__c,
           SM_Contract__c, SM_Contract__r.Name, SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c, SM_Contract__r.SM_Payment_Method__c,
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
];

System.debug('###RESUMEN### Total ACH Orders que matchean el batch hoy (' + dateToProcess + '): ' + achOrders.size());

Map<String, Integer> countByType = new Map<String, Integer>();
Integer nullPaymentMethod = 0;
Integer nullTotal = 0;
Integer nullNextTransactionDate = 0;
Integer nullAchAccountNumber = 0;
Integer nullRoutingNumber = 0;

Id achRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
List<SM_Payment__c> simulatedPayments = new List<SM_Payment__c>();

for (SM_ACH_Order__c achOrder : achOrders) {
    String t = achOrder.SM_Payment_Type__c;
    countByType.put(t, (countByType.containsKey(t) ? countByType.get(t) : 0) + 1);

    if (achOrder.SM_Contract__r.SM_Payment_Method__c == null) nullPaymentMethod++;
    if (achOrder.SM_Total__c == null) nullTotal++;
    if (achOrder.SM_Next_Transaction_Date__c == null) nullNextTransactionDate++;
    if (achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_ACH_Account_Number__c == null) nullAchAccountNumber++;
    if (achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_Routing_Number__c == null) nullRoutingNumber++;

    simulatedPayments.add(new SM_Payment__c(
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

System.debug('###RESUMEN### Breakdown por SM_Payment_Type__c:');
for (String key : countByType.keySet()) {
    System.debug('###RESUMEN###   ' + key + ' -> ' + countByType.get(key));
}

System.debug('###RESUMEN### Alertas de datos (podrían indicar problemas en el insert real):');
System.debug('###RESUMEN###   ACH Orders con Contract.SM_Payment_Method__c = null: ' + nullPaymentMethod);
System.debug('###RESUMEN###   ACH Orders con SM_Total__c = null: ' + nullTotal);
System.debug('###RESUMEN###   ACH Orders con SM_Next_Transaction_Date__c = null: ' + nullNextTransactionDate);
System.debug('###RESUMEN###   ACH Orders con ACH Account Number = null (quedaría en 0): ' + nullAchAccountNumber);
System.debug('###RESUMEN###   ACH Orders con Routing Number = null (quedaría en blanco): ' + nullRoutingNumber);

System.debug('###RESUMEN### Muestra de los primeros 5 Payments que se armarían:');
for (Integer i = 0; i < Math.min(5, simulatedPayments.size()); i++) {
    SM_Payment__c p = simulatedPayments[i];
    SM_ACH_Order__c src = achOrders[i];
    System.debug('###MUESTRA### ACH Order: ' + src.Name + ' (' + src.Id + ') | Contract: ' + src.SM_Contract__r.Name
        + ' | Type: ' + p.SM_Type__c + ' | Amount: ' + p.SM_Amount__c + ' | Payment Date: ' + p.SM_Payment_Date__c
        + ' | Payment Method: ' + p.SM_Payment_Method__c + ' | Fee to collect: ' + p.SM_Fee_to_collect__c
        + ' | Penalty: ' + p.SM_Penalty_value__c + ' | Fee value: ' + p.SM_Fee_value__c);
}

System.debug('###RESUMEN### FIN SIMULACIÓN — no se insertó ni actualizó nada.');
