/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 01-28-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   01-28-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
trigger SM_ContractTrigger on Contract (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_ContractHandler contractHd = new SM_ContractHandler('SM_ContractTrigger');
    contractHd.run();
}