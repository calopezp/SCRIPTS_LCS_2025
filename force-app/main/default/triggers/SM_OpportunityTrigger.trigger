/**
 * @description       : Trigger of Lead Object
 * @author            : jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 11-27-2020
 * @last modified by  : jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-27-2020   jpachon@legal-credit.com   Initial Version
**/
trigger SM_OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_OpportunityHandler handler = new SM_OpportunityHandler('SM_OpportunityTrigger');
    handler.run();
}