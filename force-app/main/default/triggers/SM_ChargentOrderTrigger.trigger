/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 07-18-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   05-15-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
trigger SM_ChargentOrderTrigger on ChargentOrders__ChargentOrder__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
       //Call handler class to execute
       SM_ChargentOrderHandler handler = new SM_ChargentOrderHandler('SM_ChargentOrderTrigger');
       handler.run();
}