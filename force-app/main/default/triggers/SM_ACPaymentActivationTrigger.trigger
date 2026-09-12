/**
 * @description Activates a Contract's AC when a non-ACH (ChargeBee/Credit Card/Cash) AC
 * payment is accepted. See SM_ACPaymentActivationHandler for why this is a separate trigger
 * instead of an addition to SM_PaymentTrigger/SM_PaymentTGR.
 * @author Carlos Alberto Lopez Prada
 */
trigger SM_ACPaymentActivationTrigger on SM_Payment__c (after insert, after update) {
    SM_ACPaymentActivationHandler handler = new SM_ACPaymentActivationHandler('SM_ACPaymentActivationTrigger');
    handler.run();
}
