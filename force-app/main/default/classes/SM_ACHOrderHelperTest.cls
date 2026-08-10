/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 07-24-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   03-27-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
@IsTest
public without sharing class SM_ACHOrderHelperTest {


    @TestSetup
    static void makeData(){
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert new List<Account>{acc};
        SM_Company_setting__c companySettings = SM_TestSmartDataFactory.getCompanySetting();
        insert new List<SM_Company_setting__c>{companySettings};
        APXTConga4__Conga_Solution__c congaSolution = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert new List<APXTConga4__Conga_Solution__c>{congaSolution};
        Process_automation_by_product_family__c prdAutoByFamily = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettings.Id, congaSolution.Id);
        insert new List<Process_automation_by_product_family__c>{prdAutoByFamily};
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, prdAutoByFamily.Id);
        insert new List<Contract>{ct};
        SM_ACH_Order__c achOrd = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        achOrd.SM_Next_Transaction_Date__c = System.today();
        achOrd.SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.AC;
        achOrd.SM_Payment_Frequency__c = SM_ACHOrderHelper.paymentFrequency.ONCE;
        insert new List<SM_ACH_Order__c>{achOrd};
    }

    @IsTest
    static void testDoNothing(){
        Test.startTest();
        String paymentType = SM_ACHOrderHelper.paymentType.SUBSCRIPTION;
        Test.stopTest();
    }

    @IsTest
    static void testGetACHOrdersByIds(){
        SM_ACH_Order__c achOrder = [SELECT Id FROM SM_ACH_Order__c LIMIT 1];
        Map<String, SM_ACH_Order__c> achOrders;
        Test.startTest();
        achOrders = SM_ACHOrderHelper.getACHOrdersByIds(new Set<String>{achOrder.Id});
        Test.stopTest();
        System.assertEquals(1, achOrders.size(), 'The result is not the expected.');
    }
}