/**
 * @description       : Trigger of Task Object
 * @author            : jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 12-23-2020
 * @last modified by  : jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   12-23-2020   jpachon@legal-credit.com   Initial Version
**/
trigger SM_TaskTrigger on Task (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_TaskHandler handler = new SM_TaskHandler('SM_TaskTrigger');
    handler.run();    
}