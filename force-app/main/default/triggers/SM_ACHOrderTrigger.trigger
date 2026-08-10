/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 04-25-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   04-25-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
trigger SM_ACHOrderTrigger on SM_ACH_Order__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_ACHOrderHandler handler = new SM_ACHOrderHandler('SM_ACHOrderTrigger');
    handler.run();
}