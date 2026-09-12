/**
 * @description       : Trigger Attachment
 * @author            : Camilo j. -> cjimenez@legal-credit.com
 * @group             : 
 * @last modified on  : 10-04-2021
 * @last modified by  : Camilo j. Camilo Jimenez ->  cjimenez@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   10-04-2021   Camilo j. Camilo Jimenez ->  cjimenez@legal-credit.com  Initial Version
**/
trigger SM_AttachmentTrigger on Attachment (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
       //Call handler class to execute
       SM_AttachmentHandler attachmenHd = new SM_AttachmentHandler('SM_AttachmentTrigger');
       attachmenHd.run();

}