/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-10-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   06-10-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
@IsTest
public without sharing class SM_AttachmentHandlerTest {

    @TestSetup
    static void makeData(){
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert new List<Account>{acc};
        SM_Company_setting__c companySettings = SM_TestSmartDataFactory.getCompanySetting();
        companySettings.SM_Abbreviated_Company__c = 'LCS';
        insert new List<SM_Company_setting__c>{companySettings};
        APXTConga4__Conga_Solution__c congaSolution = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert new List<APXTConga4__Conga_Solution__c>{congaSolution};
        Process_automation_by_product_family__c prdAutoByFamily = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettings.Id, congaSolution.Id);
        insert new List<Process_automation_by_product_family__c>{prdAutoByFamily};
        Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
        opp.SM_Company_Setting__c = companySettings.Id;
        insert opp;
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, prdAutoByFamily.Id);
        ct.SM_Email_to_send_contract__c = 'test@gmail.com';
        ct.SM_Opportunity__c = opp.Id;
        insert new List<Contract>{ct};
        echosign_dev1__SIGN_Agreement__c agreement = SM_TestSmartDataFactory.getAgreement();
        agreement.echosign_dev1__Contract__c = ct.Id;
		insert agreement;
    }

    @IsTest
    static void testUploadFileToS3(){

        echosign_dev1__SIGN_Agreement__c agreement = [SELECT id,echosign_dev1__Contract__c,echosign_dev1__Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Abbreviated_Company__c
        ,echosign_dev1__Contract__r.SM_Opportunity__c,echosign_dev1__Contract__r.SM_Opportunity__r.SM_Company_Setting__c
        FROM echosign_dev1__SIGN_Agreement__c];
        System.debug('agreement: ' + agreement);
        Test.startTest();
            Attachment at = SM_TestSmartDataFactory.getAttachment(agreement.Id);
            at.Name = at.Name + ' - signed';
            insert at;
        Test.stopTest();

    }
}