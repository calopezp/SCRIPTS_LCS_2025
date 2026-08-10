/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 07-24-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   03-27-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
@IsTest
public without sharing class SM_PaymentBatchTest {

    private static final String CRON_EXP = '0 0 0 31 12 ? 2030';

    @TestSetup
    static void makeData(){
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert new List<Account>{acc};
        SM_Company_setting__c companySettings = SM_TestSmartDataFactory.getCompanySetting();
        insert new List<SM_Company_setting__c>{companySettings};
        APXTConga4__Conga_Solution__c congaSolution = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert new List<APXTConga4__Conga_Solution__c>{congaSolution};
        Process_automation_by_product_family__c prdAutoByFamily = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettings.Id, congaSolution.Id);
        insert new List<Process_automation_by_product_family__c>{prdAutoByFamily};
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, prdAutoByFamily.Id);
        SM_Bank__c bank = new SM_Bank__c(Name = 'BANCO POPULAR');
        insert bank;
        SM_Payment_Method__c pymenMethod = SM_TestSmartDataFactory.getACHPaymentMethod(acc.Id, 'BANCO POPULAR');
        pymenMethod.SM_Bank__c = bank.Id;
        insert pymenMethod;
        ct.SM_Payment_Method__c = pymenMethod.id;
        insert new List<Contract>{ct};
        SM_ACH_Order__c achOrd = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        achOrd.SM_Next_Transaction_Date__c = System.today();
        achOrd.SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.SUBSCRIPTION;
        insert new List<SM_ACH_Order__c>{achOrd};
    }

    @IsTest
    static void testPaymentSchedule(){
        Test.startTest();
        String jobId = System.schedule('PaymentSchedule_Test', CRON_EXP, new SM_PaymentSchedule());
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
        System.assertEquals(0, ct.TimesTriggered);
        System.assertEquals('2030-12-31 00:00:00', String.valueOf(ct.NextFireTime));
        Test.stopTest();
    }

    @IsTest
    static void testPaymentBatch(){
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        ct.Status = SM_ContractHelper.status.ACTIVATED;
        SM_BypassManager.disableValidationRules();
        update ct;
        SM_BypassManager.enableValidationRules();
        Test.startTest();
        Database.executeBatch(new SM_PaymentBatch());
        Test.stopTest();
        List<SM_Payment__c> payments = [SELECT Id FROM SM_Payment__c];
        //System.assertEquals(1, payments.size(), 'The payment records quantity is not the expected');
    }
}