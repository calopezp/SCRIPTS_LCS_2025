/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 04-08-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   04-08-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
trigger SM_PaymentTrigger on SM_Payment__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_PaymentHandler handler = new SM_PaymentHandler('SM_PaymentTrigger');
    handler.run();
}