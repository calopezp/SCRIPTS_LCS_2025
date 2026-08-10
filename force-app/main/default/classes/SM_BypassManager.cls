/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 03-20-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   03-20-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
global without sharing class SM_BypassManager {

    /**
     * Determine if validation rules can skiped
     */
    global static Boolean skipValidationRulesByProfileId() {
        return SM_Bypasser__c.getInstance(UserInfo.getProfileId()).SM_Disable_Validation_Rules__c;
    }

    global static void disableValidationRules(){
        SM_Bypasser__c bypass = SM_Bypasser__c.getInstance(UserInfo.getProfileId());
        if (!bypass.SM_Disable_Validation_Rules__c) {
            System.debug('Executing disableValidationRules: ' + bypass);
            bypass.SM_Disable_Validation_Rules__c = true;
            update bypass;
        }
    }

    global static void enableValidationRules(){
        SM_Bypasser__c bypass = SM_Bypasser__c.getInstance(UserInfo.getProfileId());
        if (bypass.SM_Disable_Validation_Rules__c) {
            System.debug('Executing enableValidationRules: ' + bypass);
            bypass.SM_Disable_Validation_Rules__c = false;
            update bypass;
        }
    }


}