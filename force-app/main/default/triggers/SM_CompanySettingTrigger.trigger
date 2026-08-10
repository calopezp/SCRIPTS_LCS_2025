/**
 * @description       : 
 * @author            : diego.jacanamijoy@gmail.com
 * @group             : 
 * @last modified on  : 11-26-2020
 * @last modified by  : diego.jacanamijoy@gmail.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-26-2020   diego.jacanamijoy@gmail.com   Initial Version
**/
trigger SM_CompanySettingTrigger on SM_Company_setting__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    //Call handler class to execute
    SM_CompanySettingHandler companySettingHd = new SM_CompanySettingHandler('SM_CompanySettingTrigger');
    companySettingHd.run();
}