/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 03-26-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   03-25-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
global without sharing class SM_PaymentSchedule implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new SM_PaymentBatch());
    }
}