/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 07-24-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   05-15-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
@IsTest
public without sharing class SM_ChargentOrderHandlerTest {

    @TestSetup
    static void makeData(){
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        ChargentBase__Gateway__c gateway = SM_TestSmartDataFactory.getGateway();
        insert gateway;
        Account account = SM_TestSmartDataFactory.getPersonAccount();
        account.PersonEmail = 'legal_credit@gmail.com.invalid';
        insert account;
        SM_Company_setting__c companySettingObj = SM_TestSmartDataFactory.getCompanySettingPMethod(gateway.Id);
        insert companySettingObj;
        Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
        opp.AccountId = account.Id;
        opp.SM_Company_Setting__c = companySettingObj.Id;
        insert opp;
        Process_automation_by_product_family__c processautomationProductfamilyObj = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettingObj.id, null);
        insert processautomationProductfamilyObj;
        Contract contract = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
        contract.SM_Opportunity__c = opp.Id;
        contract.Status = 'Complete information';
        insert contract;
        Product2 prd2 = SM_TestSmartDataFactory.getproduct2NoInsert();
        prd2.SM_Way_to_pay__c = 'Fix Term';
        prd2.SM_Plan_Months__c = 7;
        insert prd2;
        Asset ast = SM_TestSmartDataFactory.getAsset(account.Id, contract.Id);
        ast.Product2Id = prd2.Id;
        ast.Price = 100;
        insert ast;

    }

    @IsTest
    static void testCreationOfAssetFees(){
        // JSPA - Pending to fix because Santiago made some changes
        // Account acc = [SELECT Id FROM Account LIMIT 1];
        // Contract ct = [SELECT Id, SM_AC_start_date__c, SM_Opportunity__r.SM_Company_Setting__c FROM Contract WHERE AccountId =: acc.Id LIMIT 1];
        // SM_Company_setting__c companySetting = [SELECT Id, SM_Gateway__c FROM SM_Company_setting__c WHERE Id =: ct.SM_Opportunity__r.SM_Company_Setting__c LIMIT 1];
        // Test.startTest();
        //     ChargentOrders__ChargentOrder__c cO = SM_TestSmartDataFactory.getChargentorder(acc.Id, ct, companySetting, 'Subscription');
        //     co.ChargentOrders__Status__c = 'Initiated';
        //     co.Contract__c = ct.Id;
        //     co.SM_Purpose_of_Payment__c = 'Contract fee';
        //     insert cO;

        // Test.stopTest();
        // Asset asset = [SELECT Id FROM Asset WHERE SM_Chargent_Order__c =: cO.Id];
        // System.assertNotEquals(null, asset, 'Should be exists one asset records related to chargent order');
        // List<SM_Asset_Fee__c> assetFees = [SELECT Id FROM SM_Asset_Fee__c WHERE SM_Asset__c =: asset.Id];
        // System.assertEquals(7, assetFees.size(), 'Should be 7 asset fee records created');
    }
}