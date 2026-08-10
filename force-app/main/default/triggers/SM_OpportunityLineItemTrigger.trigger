trigger SM_OpportunityLineItemTrigger on OpportunityLineItem (before insert, before update, before delete, after insert, after update, after delete, after undelete) {

     //Call handler class to execute
     SM_OpportunityLineItemHandler handler = new SM_OpportunityLineItemHandler('SM_OpportunityLineTrigger');
     handler.run();


}