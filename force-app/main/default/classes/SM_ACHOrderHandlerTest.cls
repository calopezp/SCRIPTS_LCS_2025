/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 07-24-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   04-25-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
@IsTest
public without sharing class SM_ACHOrderHandlerTest {

    @TestSetup
    static void makeData(){
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert acc;
        Process_automation_by_product_family__c processAutomation = SM_TestSmartDataFactory.getProccessAutomation();
        insert processAutomation;
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, processAutomation.Id);
        insert ct;
        Product2 p2 = SM_TestSmartDataFactory.getProduct2();
        Asset asset = SM_TestSmartDataFactory.getAsset(acc.Id, ct.Id);
        asset.Product2Id = p2.Id;
        insert asset;
        SM_ACH_Order__c achOrder = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        achOrder.SM_Payment_Type__c = 'Subscription';
        achOrder.SM_Next_Transaction_Date__c=System.toDay();
        insert achOrder;
        SM_Asset_Fee__c assetFee = SM_TestSmartDataFactory.getAssetFee(asset.Id);
        assetFee.SM_ACH_Order__c = achOrder.Id;
        assetFee.SM_Type__c = 'Subscription';
        assetFee.SM_Amount__c = 100;
        insert assetFee;
    }

    @IsTest
    static void testACHOrderUpdate(){
        SM_ACH_Order__c achOrder = [SELECT Id FROM SM_ACH_Order__c LIMIT 1];
        Test.startTest();
            achOrder.SM_Fee_to_collect__c = 2;
            update achOrder;
        Test.stopTest();
    }

    @IsTest
    static void testApplyPenaltyToTrue(){
        SM_ACH_Order__c achOrder = [SELECT Id, SM_Total__c, SM_Apply_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        achOrder.SM_Total__c = 69;
        achorder.SM_Penalty_value__c = 25;
        update achOrder;
        Test.startTest();
            achOrder.SM_Apply_penalty__c = true;
            update achOrder;
        Test.stopTest();
        achOrder = [SELECT Id, SM_Total__c, SM_Penalty_date__c, SM_User_who_applies_the_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        System.assertEquals(94, achOrder.SM_Total__c, 'The total value is not the expected.');
        System.assertEquals(System.today(), achOrder.SM_Penalty_date__c, 'The penalty date is not the expected.');
        System.assertEquals(UserInfo.getUserId(), achOrder.SM_User_who_applies_the_penalty__c, 'The user who applies the penalty is not the expected.');
    }

    @IsTest
    static void testApplyPenaltyToFalse(){
        SM_ACH_Order__c achOrder = [SELECT Id, SM_Total__c, SM_Penalty_date__c, SM_Apply_penalty__c, SM_User_who_applies_the_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        achOrder.SM_Total__c = 69;
        achorder.SM_Penalty_value__c = 25;
        achOrder.SM_Apply_penalty__c = true;
        update achOrder;
        achOrder = [SELECT Id, SM_Total__c, SM_Penalty_date__c, SM_Apply_penalty__c, SM_User_who_applies_the_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        System.assertEquals(94, achOrder.SM_Total__c, 'The total value is not the expected.');
        System.assertEquals(System.today(), achOrder.SM_Penalty_date__c, 'The penalty date is not the expected.');
        System.assertEquals(UserInfo.getUserId(), achOrder.SM_User_who_applies_the_penalty__c, 'The user who applies the penalty is not the expected.');
        achOrder = [SELECT Id, SM_Total__c, SM_Penalty_date__c, SM_Apply_penalty__c, SM_User_who_applies_the_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        achOrder.SM_Penalty_date__c = null;
        achOrder.SM_User_who_applies_the_penalty__c = null;
        update achOrder;
        System.assertEquals(94, achOrder.SM_Total__c, 'The total value is not the expected.');
        System.assertEquals(null, achOrder.SM_Penalty_date__c, 'The penalty date is not the expected.');
        System.assertEquals(null, achOrder.SM_User_who_applies_the_penalty__c, 'The user who applies the penalty is not the expected.');
        Test.startTest();
        achOrder.SM_Apply_penalty__c = false;
            update achOrder;
        Test.stopTest();
        achOrder = [SELECT Id, SM_Total__c, SM_Penalty_date__c, SM_Apply_penalty__c, SM_User_who_applies_the_penalty__c FROM SM_ACH_Order__c LIMIT 1];
        System.assertEquals(69, achOrder.SM_Total__c, 'The total value is not the expected.');
        System.assertEquals(System.today(), achOrder.SM_Penalty_date__c, 'The penalty date is not the expected.');
        System.assertEquals(UserInfo.getUserId(), achOrder.SM_User_who_applies_the_penalty__c, 'The user who applies the penalty is not the expected.');
    }
}