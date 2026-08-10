trigger SM_PaymentTGR on SM_Payment__c (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    //Call handler class to execute
    SM_paymentTGR_Handler tgrController = new SM_paymentTGR_Handler('SM_ChargentTransactionTGR');
    tgrController.run();
}