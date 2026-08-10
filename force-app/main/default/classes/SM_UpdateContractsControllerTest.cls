/**
 * @description       : 
 * @author            : cjimenez@legal-credit.com
 * @group             : 
 * @last modified on  : 12/11/2022
 * @last modified by  : Camilo Jimenez -> cjimenez@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   12-11-2021   cjimenez@legal-credit.com   Initial Version
**/
@IsTest
public with sharing class SM_UpdateContractsControllerTest {
    @TestSetup
    static void makeData(){
        insert new SM_SetupToken__c (SM_Active__c = true ,SM_ExpirationDate__c=System.now(), SM_DurationMinutes__c = 15 , Name ='Token Native');
        insert SM_TestSmartDataFactory.getProccessAutomation();
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert acc;

        Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
        opp.AccountId = acc.Id;
        insert opp;

        //master
        OpportunityLineItem oppLitMaster = SM_TestSmartDataFactory.getOpportunityLineItem();
        oppLitMaster.OpportunityId = opp.Id;
        oppLitMaster.UnitPrice = 1200;
        oppLitMaster.Product_Type__c = SM_OpportunityHelper.contractType.MASTER;
        oppLitMaster.Is_master__c = true;
        insert oppLitMaster;

        oppLitMaster.Product_Type__c = SM_OpportunityHelper.contractType.MASTER;
        update oppLitMaster;

        Process_automation_by_product_family__c paf = new Process_automation_by_product_family__c();
        paf.Name = 'Depend proccess';
        paf.SM_Type_of_contract__c = 'Legal Credit Solution';
        paf.SM_Generates_dispute__c = true;
        paf.Contract_activation_form__c = 'Future activation with conditions';
        paf.Start_assets_in_fee_number__c = 10;
        insert paf;

        Product2 p2Depend = SM_TestSmartDataFactory.getProduct2().clone(false, false, false, false);
        p2Depend.Name = 'Dependent Laptop X200';
        p2Depend.Family = 'Dependent Hardware';
        p2Depend.Process_automation_by_product_family__c = paf.Id;
        insert p2Depend;

        PricebookEntry pbe = SM_TestSmartDataFactory.getPricebookEntry().clone();
        pbe.Product2Id = p2Depend.Id;
        insert pbe;

        Contract ct = SM_TestSmartDataFactory.getContract(acc.id,paf.id);
        ct.Contract_activation_form__c = 'Future activation with conditions';
        ct.Principal_Contract__c = ct.id;
        insert ct;

        Contract ct1 = SM_TestSmartDataFactory.getContract(acc.id,paf.id);
        ct1.Contract_activation_form__c = 'Future activation with conditions';
        ct1.Principal_Contract__c = ct.id;
        insert ct1;

        Contract ct2 = SM_TestSmartDataFactory.getContract(acc.id,paf.id);
        ct2.Contract_activation_form__c = 'Future activation with conditions';
        ct2.Principal_Contract__c = ct.id;
        insert ct2;
        
        SM_Simultaneous_Contract_Updates__c scu = SM_TestSmartDataFactory.getSimultaneousContract(paf.id,'Future activation with conditions');
        insert scu;

    }
    @IsTest
    static void generateContractsOk(){
        Contract ct = [SELECT Id FROM Contract where Principal_Contract__c != NULL LIMIT 1];
        Boolean isSuccess = SM_UpdateContractsController.updateContracts(ct.id);
        System.assertEquals(isSuccess, true, 'Contract Update');
    }
}