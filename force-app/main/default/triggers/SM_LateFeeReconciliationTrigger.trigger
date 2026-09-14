/**
 * @description Cancels a Stopped "Late payment fee" SM_ACH_Order__c once its originating
 * failed Payment resolves to SM_Check_Collection_Status__c = 'COLLECTED'. See
 * SM_LateFeeReconciliationHandler for why this is a separate trigger instead of an addition
 * to SM_PaymentTrigger/SM_PaymentTGR.
 * @author Carlos Alberto Lopez Prada
 */
trigger SM_LateFeeReconciliationTrigger on SM_Payment__c (after update) {
    SM_LateFeeReconciliationHandler handler = new SM_LateFeeReconciliationHandler('SM_LateFeeReconciliationTrigger');
    handler.run();
}
