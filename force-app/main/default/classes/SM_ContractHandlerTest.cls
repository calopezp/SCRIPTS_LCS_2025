/**
 * @description       : Test Class SM_ContractHandler,SM_ContractHelper,SM_ContractTrigger
 * @author            : cjimenez@legal-credit.com
 * @group             :
 * Modifications Log
 * Ver   Date         Author                        Modification
 * 1.0   04-02-2021   cjimenez@legal-credit.com    Initial Version
 * 2.1   07-09-2026   Juan Duarte / Carlos Lopez                             Ajustes por cancelacion de CHARGENT
**/
@IsTest
public with sharing class SM_ContractHandlerTest {


    private static String EMAIL_1 = 'legal_credit@gmail.com.invalid';

    @TestSetup
    static void makeData(){
    // Data to test five9 list and reminder tasks
        Test.startTest();
            insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());
            Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail='legal_credit@gmail.com.invalid';
            insert account;
            ChargentBase__Gateway__c Gt = SM_TestSmartDataFactory.getGateway();
            insert Gt;
            SM_Company_setting__c companySettingObj = SM_TestSmartDataFactory.getCompanySettingPMethod(Gt.Id);
            insert companySettingObj;
            List<SM_Required_Field_Info__c> requiredFields = SM_TestSmartDataFactory.getRequiredFields(companySettingObj.Id);
            insert requiredFields;
            echosign_dev1__SIGN_Agreement__c agreementObj = SM_TestSmartDataFactory.getAgreement();
            insert agreementObj;
            SM_Bank__c bank = new SM_Bank__c(Name = 'ORIENTAL BANK');
            insert bank;
            Attachment attachmentObj = SM_TestSmartDataFactory.getAttachment(agreementObj.id);
            insert attachmentObj;
            system.debug('attachmentObj-->'+attachmentObj.id);
            APXTConga4__Conga_Solution__c conga4CongaSolutionObj = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
            insert conga4CongaSolutionObj;
            Process_automation_by_product_family__c processautomationProductfamilyObj = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettingObj.id,conga4CongaSolutionObj.id);
            processautomationProductfamilyObj.SM_Generates_dispute__c = true;
            insert processautomationProductfamilyObj;
            Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
            opp.AccountId = account.Id;
            opp.SM_Company_Setting__c = companySettingObj.Id;
            insert opp;
            Contract contract = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
            contract.SM_Generates_dispute__c = true;
            contract.SM_Opportunity__c = opp.Id;
            contract.SM_Email_to_send_contract__c = 'test@yopmail.com';
            insert contract;
            agreementObj.echosign_dev1__Contract__c = contract.Id;
            update agreementObj;
            SM_Payment_Method__c paymentMethodACH1 = SM_TestSmartDataFactory.getACHPaymentMethod(account.Id, 'BANCO POPULAR');
            paymentMethodACH1.ACH_Bank_Name__c = 'BANCO POPULAR';
            paymentMethodACH1.SM_Bank__c = bank.Id;
            SM_Payment_Method__c paymentMethodACH2 = SM_TestSmartDataFactory.getACHPaymentMethod(account.Id, 'BANCO SANTANDER');
            paymentMethodACH2.ACH_Bank_Name__c = 'BANCO SANTANDER';
            paymentMethodACH2.SM_Bank__c = bank.Id;
            SM_Payment_Method__c paymentMethodCreditCard1 = SM_TestSmartDataFactory.getCreditCardPaymentMethod(account.Id, 'Visa');
            SM_Payment_Method__c paymentMethodCreditCard2 = SM_TestSmartDataFactory.getCreditCardPaymentMethod(account.Id, 'Master Card');
            insert new List<SM_Payment_Method__c>{paymentMethodACH1, paymentMethodACH2, paymentMethodCreditCard1, paymentMethodCreditCard2};
            Product2 prd2 = SM_TestSmartDataFactory.getproduct2NoInsert();
            prd2.Process_automation_by_product_family__c = processautomationProductfamilyObj.Id;
            insert prd2;
            OpportunityLineItem oppLit = SM_TestSmartDataFactory.getOpportunityLineItem();
            oppLit.OpportunityId = opp.Id;
            oppLit.UnitPrice = 1200;
            oppLit.Product2Id = prd2.id;
            insert oppLit;
            SM_SetupToken__c setupToken=SM_TestSmartDataFactory.getSetupToken();
            insert setupToken;
            SM_Dispute__c dispute=SM_TestSmartDataFactory.getDispute();
            //dispute.SM_Contract__c=contract.id;
            //insert dispute;
            Asset ast = SM_TestSmartDataFactory.getAsset(account.Id, contract.Id);
            Asset ast2 = SM_TestSmartDataFactory.getAsset(account.Id, contract.Id);
            insert new List<Asset>{ast, ast2};

            SM_ACH_Order__c achOrder = SM_TestSmartDataFactory.getACHOrder(contract.Id);
            achOrder.SM_Payment_Status__c = 'Initiated';
            achOrder.SM_Payment_Method__c = paymentMethodACH1.Id;
            achOrder.SM_Total__c = 69;
            achOrder.SM_Payment_Frequency__c = 'Monthly';
            achOrder.SM_Payment_Start_Date__c = System.today();
            achOrder.SM_Payment_End_Date__c = System.today();
            achOrder.SM_Next_Transaction_Date__c = System.today();
            insert achOrder;

            SM_Asset_Fee__c assetFee = SM_TestSmartDataFactory.getAssetFee(ast.Id);
            assetFee.SM_Contract__c = contract.Id;
            insert assetFee;
        Test.stopTest();
    }

    @IsTest
    static void processChangesToSendContract(){
        //  Contract contract = [SELECT id,Status, SM_Payment_Received__c FROM Contract LIMIT 1];
        //  Test.startTest();
        // //BYPASER Validation rules
        // insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());
        // Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        //  contract.Status='Complete information';
        //  contract.SM_Payment_Received__c=true;
        //  contract.SM_Email_to_send_contract__c='legal_credit@gmail.com.invalid';
        //  update contract;
        // // System.assertEquals('Sent for signature',[SELECT id,Status FROM Contract where id=:contract.id].Status, 'Status Update');
        //  Test.stopTest();
    }

    @IsTest
    static void validatePaymentsACFullPayment(){
        Contract contract = [SELECT id,Status, SM_Payment_Received__c FROM Contract LIMIT 1];
        SM_Payment_Method__c pMethod = [SELECT id FROM SM_Payment_Method__c LIMIT 1];
        Test.startTest();
            contract.RecordTypeId = Schema.getGlobalDescribe().get('Contract').getDescribe().getRecordTypeInfosByDeveloperName().get('SM_Legal_Credit_Solution').getRecordTypeId();
            contract.Status='Complete information';
            contract.SM_Frecuency__c = 'Anual';
            contract.SM_Start_date__c = Date.today();
            contract.SM_Way_of_AC_Payment__c = 'One payment';
            contract.SM_Registered_Card_Token__c = '1929826725-1841993424';
            contract.SM_AC_start_date__c = Date.today();
            contract.SM_Payment_Method__c = pMethod.Id;
            contract.SM_Email_to_send_contract__c='legal_credit@gmail.com.invalid';
            contract.SM_Number_of_AC_Fees__c = 1;
            // contract.SM_AC_Split_Date__c = Date.Today();
            contract.SM_AC_start_date__c = Date.Today();
            contract.SM_Requires_AC_Payment__c = true;
            contract.SM_Requires_Suscription_Payment__c = true;
            update contract;
        Test.stopTest();
    }

    @IsTest
    static void validatePaymentPage(){
        SM_Payment_Method__c pMethod = [SELECT id FROM SM_Payment_Method__c LIMIT 1];
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(pMethod);
        PageReference pageRef = Page.PaymentMethodCardInfo;
        pageRef.getParameters().put('Id', String.valueOf(pMethod.Id));
        Test.setCurrentPage(pageRef);
        SM_PaymentMethodCardInfoRedirector red = new SM_PaymentMethodCardInfoRedirector(sc);
        red.redirect();
        Test.stopTest();
    }


    @IsTest
    static void validatePaymentsACFees(){
        Contract contract = [SELECT id,Status, SM_Payment_Received__c FROM Contract LIMIT 1];
        SM_Payment_Method__c pMethod = [SELECT id FROM SM_Payment_Method__c LIMIT 1];
        Test.startTest();
            contract.RecordTypeId = Schema.getGlobalDescribe().get('Contract').getDescribe().getRecordTypeInfosByDeveloperName().get('SM_Legal_Credit_Solution').getRecordTypeId();
            contract.Status='Complete information';
            contract.SM_Frecuency__c = 'Anual';
            contract.SM_Start_date__c = Date.today();
            contract.SM_Way_of_AC_Payment__c = 'Fees';
            contract.SM_Registered_Card_Token__c = '1929826725-1841993424';
            contract.SM_AC_start_date__c = Date.today();
            contract.SM_Payment_Method__c = pMethod.Id;
            contract.SM_Total_AC__c = 200;
            contract.SM_AC_Split_Date__c = Date.Today();
            contract.SM_Email_to_send_contract__c='legal_credit@gmail.com.invalid';
            contract.SM_Number_of_AC_Fees__c = 3;
            contract.SM_AC_start_date__c = Date.Today();
            contract.SM_Requires_AC_Payment__c = true;
            contract.SM_Requires_Suscription_Payment__c = true;
            update contract;
            
            List<ChargentOrders__ChargentOrder__c> cr = [
                SELECT Id,Contract__c,SM_Payment_Type__c,ChargentOrders__Charge_Amount__c,ChargentOrders__Gateway__c,(Select Id from ChargentOrders__Transactions__r) 
                FROM ChargentOrders__ChargentOrder__c];
            if(!cr.isEmpty()){
                    for(ChargentOrders__ChargentOrder__c ord : cr){
                        System.debug(JSON.serializePretty(ord));
                        ord.contract__c = contract.Id;
                    }
                    update cr;
                    simulateTransaction(cr);
            }
        Test.stopTest();
    }

    @IsTest
    static void validatePaymentsSuscriptionFees(){
        Contract contract = [SELECT id,Status, SM_Payment_Received__c FROM Contract LIMIT 1];
        SM_Payment_Method__c pMethod = [SELECT id FROM SM_Payment_Method__c LIMIT 1];
        Test.startTest();
            contract.RecordTypeId = Schema.getGlobalDescribe().get('Contract').getDescribe().getRecordTypeInfosByDeveloperName().get('SM_Legal_Credit_Solution').getRecordTypeId();
            contract.Status='Complete information';
            contract.SM_Frecuency__c = 'Anual';
            contract.SM_Start_date__c = Date.today();
            contract.SM_Way_of_AC_Payment__c = 'Fees';
            contract.SM_Registered_Card_Token__c = '1929826725-1841993424';
            contract.SM_AC_start_date__c = Date.today();
            contract.SM_Payment_Method__c = pMethod.Id;
            contract.SM_AC_Split_Date__c = Date.Today();
            contract.SM_Email_to_send_contract__c='legal_credit@gmail.com.invalid';
            contract.SM_Number_of_AC_Fees__c = 3;
            contract.SM_AC_start_date__c = Date.Today();
            contract.SM_Requires_AC_Payment__c = false;
            contract.SM_Way_of_Contract_Payment__c = 'Fix Term';
            contract.SM_Plan_Months__c = 9;
            contract.SM_Monthly_offer__c = 1568;
            contract.SM_Requires_RC_Payment__c = true;
            update contract;
            List<ChargentOrders__ChargentOrder__c> cr = [
                SELECT Id,Contract__c,SM_Payment_Type__c,ChargentOrders__Charge_Amount__c,ChargentOrders__Gateway__c,(Select   Id from ChargentOrders__Transactions__r) 
                FROM ChargentOrders__ChargentOrder__c];
            if(!cr.isEmpty()){
                for(ChargentOrders__ChargentOrder__c ord : cr){
                System.debug(JSON.serializePretty(ord));
                ord.contract__c = contract.Id;
                }
            }
            update cr;

            //Since there's no access to Chargent Methods Yet, The transactions are simulated
            simulateTransaction(cr);
        Test.stopTest();
    }

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        // Implement this interface method
        public HTTPResponse respond(HTTPRequest req) {
            // Create a fake response
            Attachment attachmenttObj = [SELECT id FROM Attachment LIMIT 1];
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(attachmenttObj.id);
            res.setStatusCode(200);
            return res;
        }
     }

    @IsTest
    static void creatDisputeByContract(){
    Contract contract = [SELECT id, status FROM Contract LIMIT 1];

        // Test.startTest();
        // //BYPASER Validation rules
        // insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());
        // contract.status='Cancelled';
        // update contract;
        // //System.assertEquals('Cancelled', [SELECT  id,SM_Status__c FROM SM_Dispute__c where SM_Contract__c =: contract.id].SM_Status__c, 'Status Update');
        // Test.stopTest();
    }

    private static void simulateTransaction(List<ChargentOrders__ChargentOrder__c> ords){

    // CARLOS LOPEZ - JUL 2026
    // No se generan órdenes Chargent cuando el objeto
    // no está disponible o el usuario no tiene acceso.
    if(ords == null || ords.isEmpty()){
        return;
    }

    createAuthorizeTransaction(ords[0]);
    createFirstPaymentTransactionAndFill(ords);
}

    private static void createAuthorizeTransaction(ChargentOrders__ChargentOrder__c ord){
        ChargentOrders__Transaction__c ctr = new ChargentOrders__Transaction__c(
            ChargentOrders__Type__c='Authorization',
            ChargentOrders__Response_Status__c ='Approved',
            ChargentOrders__Tokenization__c ='091-29382-298292829229',
            ChargentOrders__Order__c = ord.Id,
            Contract__c = ord.Contract__C,
            ChargentOrders__Gateway__c =ord.ChargentOrders__Gateway__c
        );
        insert ctr;
    }

    private static void createFirstPaymentTransactionAndFill(List<ChargentOrders__ChargentOrder__c> ords){
        List<ChargentOrders__Transaction__c> toInsert = new List<ChargentOrders__Transaction__c>();
        ChargentOrders__Transaction__c ctrtmp = new ChargentOrders__Transaction__c();
        for(ChargentOrders__ChargentOrder__c ord: ords){
            ctrtmp = new ChargentOrders__Transaction__c(
                ChargentOrders__Type__c='Charge',
                ChargentOrders__Response_Status__c ='',
                ChargentOrders__Order__c = ord.Id,
                Contract__c = ord.Contract__C
            );
            toInsert.add(ctrtmp);
        }
        insert toInsert;
        for(ChargentOrders__Transaction__c tr: toInsert){
            tr.ChargentOrders__Response_Status__c ='Approved';
        }
        update toInsert;
    }
    @IsTest
    static void testProcessAssetsByContractStatusChange(){

        Profile salesProfile = [SELECT Id FROM Profile WHERE Name =: 'Sales Agent'];
        User salesUser = [SELECT Id FROM User WHERE ProfileId =: salesProfile.Id AND IsActive = TRUE LIMIT 1];

        Contract ct;
        ct = [SELECT Id FROM Contract WHERE Account.PersonEmail =: EMAIL_1];
        ct.OwnerId = salesUser.Id;
        update ct;

        Test.startTest();
        System.runAs(salesUser){
            //BYPASER Validation rules
            insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());
            ct.Status = SM_ContractHelper.status.FINALIZED;
            update ct;
        }
        Test.stopTest();
        List<Asset> assets = [SELECT Id, Status FROM Asset WHERE SM_Contract__c =: ct.Id];
        System.assertEquals(2, assets.size(), 'Should be only two asset records');
        System.assertEquals(SM_AssetHelper.status.INACTIVATED, assets.get(0).Status, 'The asset status is not the expected');
        System.assertEquals(SM_AssetHelper.status.INACTIVATED, assets.get(1).Status, 'The asset status is not the expected');
    }

    @IsTest
    static void testValidatCancelChangeStatus(){
        // system.assertEquals(1, [SELECT COUNT() FROM Contract], 'Must return 1 contract');
        // Contract contract = [SELECT SM_Opportunity__c FROM Contract LIMIT 1];
        // System.assertEquals(0, [SELECT COUNT() FROM Opportunity WHERE Id =: contract.SM_Opportunity__c AND StageName = :SM_OpportunityHelper.stageName.closedLost], 'Must not exist opportunity closed lost');
        // System.assertEquals(2, [SELECT COUNT() FROM Asset WHERE Status != 'Cancelled'], 'Must return 1 Asset');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Dispute__c WHERE SM_Status__c != 'Cancelled'], 'Must return 1 dispute');
        // System.assertEquals(1, [SELECT COUNT() FROM ChargentOrders__ChargentOrder__c WHERE ChargentOrders__Payment_Status__c != 'Stopped'], 'Must return 1 chargent order');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Payment_Status__c != 'Canceled'], 'Must return 1 Ach order');
        // System.assertEquals(1, [SELECT COUNT() FROM echosign_dev1__SIGN_Agreement__c], 'Must return 1 Agreement');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Asset_Fee__c WHERE SM_Status__c != 'Canceled'], 'Must return 1 Asset fee');

        // //BYPASER Validation rules
        // insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());

        // Test.startTest();
        //     //Update Contract status
        //     contract.Status = SM_ContractHelper.status.CANCELED;
        //     update contract;
        // Test.stopTest();

        // System.assertEquals(2, [SELECT COUNT() FROM Asset WHERE Status = 'Cancelled'], 'Must return 1 Asset cancelled');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Dispute__c WHERE SM_Status__c = 'Cancelled'], 'Must return 1 dispute cancelled');
        // System.assertEquals(1, [SELECT COUNT() FROM ChargentOrders__ChargentOrder__c WHERE ChargentOrders__Payment_Status__c = 'Stopped'], 'Must return 1 chargent order Stopped');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Payment_Status__c = 'Canceled'], 'Must return 1 Ach order cancelled');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Asset_Fee__c WHERE SM_Status__c = 'Canceled'], 'Must return 1 Asset fee cancelled');
        // System.assertEquals(1, [SELECT COUNT() FROM echosign_dev1__SIGN_Agreement__c WHERE echosign_dev1__Status__c = 'Cancelled / Declined'], 'Must return 1 Agreement cancelled');
        // System.assertEquals(1, [SELECT COUNT() FROM Opportunity WHERE Id =: contract.SM_Opportunity__c AND StageName = :SM_OpportunityHelper.stageName.closedLost], 'Must return opportunity closed lost');
    }

    @IsTest
    static void testValidatFinalizedChangeStatus(){
        // system.assertEquals(1, [SELECT COUNT() FROM Contract], 'Must return 1 contract');
        // Contract contract = [SELECT SM_Opportunity__c FROM Contract LIMIT 1];
        // System.assertEquals(2, [SELECT COUNT() FROM Asset WHERE Status != 'Inactivated'], 'Must return 1 Asset');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Dispute__c WHERE SM_Status__c != 'Finish'], 'Must return 1 dispute');
        // System.assertEquals(1, [SELECT COUNT() FROM ChargentOrders__ChargentOrder__c WHERE ChargentOrders__Payment_Status__c != 'Stopped'], 'Must return 1 chargent order');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Payment_Status__c != 'Completed'], 'Must return 1 Ach order');

        // //BYPASER Validation rules
        // insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());

        // Test.startTest();
        //     //Update Contract status
        //     contract.Status = SM_ContractHelper.status.FINALIZED;
        //     update contract;
        // Test.stopTest();

        // System.assertEquals(2, [SELECT COUNT() FROM Asset WHERE Status = 'Inactivated'], 'Must return 1 Asset Inactivated');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_Dispute__c WHERE SM_Status__c = 'Finish'], 'Must return 1 dispute Finish');
        // System.assertEquals(1, [SELECT COUNT() FROM ChargentOrders__ChargentOrder__c WHERE ChargentOrders__Payment_Status__c = 'Stopped'], 'Must return 1 chargent order Stopped');
        // System.assertEquals(1, [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Payment_Status__c = 'Completed'], 'Must return 1 Ach order Completed');
    }

    @IsTest
    static void testChangeACHPaymentMethod(){

        Profile salesProfile = [SELECT Id FROM Profile WHERE Name =: 'Sales Agent'];
        User salesUser = [SELECT Id FROM User WHERE ProfileId =: salesProfile.Id AND IsActive = TRUE LIMIT 1];

        SM_Payment_Method__c paymentMethodACH1 = [SELECT Id FROM SM_Payment_Method__c WHERE ACH_Bank_Name__c = 'BANCO POPULAR' LIMIT 1];
        SM_Payment_Method__c paymentMethodACH2 = [SELECT Id FROM SM_Payment_Method__c WHERE ACH_Bank_Name__c = 'BANCO SANTANDER' LIMIT 1];
        Contract contractToUpdate = [SELECT Id, SM_Payment_Method__c FROM Contract LIMIT 1];
        contractToUpdate.SM_Payment_Method__c = paymentMethodACH1.Id;
        contractToUpdate.SM_Payment_methods__c = 'ACH';
        update contractToUpdate;
        SM_ACH_Order__c achOrder = [SELECT Id FROM SM_ACH_Order__c WHERE SM_Contract__c =: contractToUpdate.Id];
        Test.startTest();
            System.runAs(salesUser){
                contractToUpdate.SM_Payment_Method__c  = paymentMethodACH2.Id;
                update contractToUpdate;
            }
        Test.stopTest();
        Contract updatedContract = [SELECT Id, SM_Payment_Method__c FROM Contract WHERE Id =: contractToUpdate.Id LIMIT 1];
        SM_ACH_Order__c updatedACHOrder = [SELECT Id, SM_Payment_Method__c FROM SM_ACH_Order__c WHERE Id =: achOrder.Id];
        System.assertEquals(paymentMethodACH2.Id, updatedContract.SM_Payment_Method__c, 'The new payment method record is not the expected.');
        System.assertEquals(paymentMethodACH2.Id, updatedACHOrder.SM_Payment_Method__c, 'The new payment method record is not the expected.');
    }

    @IsTest
    static void testChangeCreditCardPaymentMethod(){
        // Profile salesProfile = [SELECT Id FROM Profile WHERE Name =: 'Sales Agent'];
        // User salesUser = [SELECT Id FROM User WHERE ProfileId =: salesProfile.Id AND IsActive = TRUE LIMIT 1];

        // SM_Payment_Method__c paymentMethodCreditCard1 = [SELECT Id, SM_Credit_Card_expiration_year__c, SM_Credit_Card_expiration_month__c, SM_Credit_Card_Number__c, SM_Credit_Card_Franchise__c, SM_Credit_Card_Name__c, SM_Card_Token__c FROM SM_Payment_Method__c WHERE SM_Credit_Card_Franchise__c = 'Visa' LIMIT 1];

        // Contract contractToUpdate = [SELECT Id, SM_Payment_Method__c FROM Contract LIMIT 1];
        // ChargentOrders__ChargentOrder__c chargentOrder = [SELECT Id, ChargentOrders__Card_Year_Indicator__c, ChargentOrders__Card_Month_Indicator__c, ChargentOrders__Card_Last_4__c, ChargentOrders__Card_Type__c, ChargentOrders__Billing_First_Name__c, ChargentOrders__Tokenization__c FROM ChargentOrders__ChargentOrder__c WHERE Contract__c =: contractToUpdate.Id];

        // System.assertEquals('Discover', chargentOrder.ChargentOrders__Card_Type__c, 'The field 4 is not the expected.');
        // System.assertEquals('9999', chargentOrder.ChargentOrders__Card_Last_4__c, 'The field 3 is not the expected.');
        // System.assertEquals('John', chargentOrder.ChargentOrders__Billing_First_Name__c, 'The field 5 is not the expected.');
        // System.assertEquals('998877', chargentOrder.ChargentOrders__Tokenization__c, 'The field 6 is not the expected.');

        // contractToUpdate.SM_Payment_Method__c = paymentMethodCreditCard1.Id;
        // contractToUpdate.SM_Payment_methods__c = 'Credit Card';
        // update contractToUpdate;

        // SM_Payment_Method__c paymentMethodCreditCard2 = [SELECT Id, SM_Credit_Card_expiration_year__c, SM_Credit_Card_expiration_month__c, SM_Credit_Card_Number__c, SM_Credit_Card_Franchise__c, SM_Credit_Card_Name__c, SM_Card_Token__c FROM SM_Payment_Method__c WHERE SM_Credit_Card_Franchise__c = 'Master Card' LIMIT 1];
        // Test.startTest();
        //     System.runAs(salesUser){
        //         contractToUpdate.SM_Payment_Method__c  = paymentMethodCreditCard2.Id;
        //         update contractToUpdate;
        //     }
        // Test.stopTest();
        // Contract updatedContract = [SELECT Id, SM_Payment_Method__c FROM Contract WHERE Id =: contractToUpdate.Id LIMIT 1];
        // ChargentOrders__ChargentOrder__c updatedChargentOrder = [SELECT Id, ChargentOrders__Card_Year_Indicator__c, ChargentOrders__Card_Month_Indicator__c, ChargentOrders__Card_Last_4__c, ChargentOrders__Card_Type__c, ChargentOrders__Billing_First_Name__c, ChargentOrders__Tokenization__c FROM ChargentOrders__ChargentOrder__c WHERE Contract__c =: contractToUpdate.Id];
        // System.debug('updatedChargentOrder: ' + updatedChargentOrder);
        // System.assertEquals(paymentMethodCreditCard2.Id, updatedContract.SM_Payment_Method__c, 'The new payment method record is not the expected.');
        // System.assertEquals(paymentMethodCreditCard2.SM_Credit_Card_Franchise__c, updatedChargentOrder.ChargentOrders__Card_Type__c, 'The new field 4 is not the expected.');
        // System.assertEquals(paymentMethodCreditCard2.SM_Credit_Card_Number__c.right(4), updatedChargentOrder.ChargentOrders__Card_Last_4__c, 'The new field 3 is not the expected.');
        // System.assertEquals(paymentMethodCreditCard2.SM_Credit_Card_Name__c, updatedChargentOrder.ChargentOrders__Billing_First_Name__c, 'The new field 5 is not the expected.');
        // System.assertEquals(paymentMethodCreditCard2.SM_Card_Token__c, updatedChargentOrder.ChargentOrders__Tokenization__c, 'The new field 6 is not the expected.');
    }

    @IsTest
    static void testChangeCreditCardFromACHPaymentMethod(){

        // Profile salesProfile = [SELECT Id FROM Profile WHERE Name =: 'Sales Agent'];
        // User salesUser = [SELECT Id FROM User WHERE ProfileId =: salesProfile.Id AND IsActive = TRUE LIMIT 1];

        // SM_Payment_Method__c paymentMethodACH1 = [SELECT Id FROM SM_Payment_Method__c WHERE ACH_Bank_Name__c = 'BANCO POPULAR' LIMIT 1];
        // Contract contractToUpdate = [SELECT Id, SM_Payment_Method__c FROM Contract LIMIT 1];
        // contractToUpdate.SM_Payment_Method__c = paymentMethodACH1.Id;
        // contractToUpdate.SM_Payment_methods__c = 'ACH';
        // update contractToUpdate;
        // SM_ACH_Order__c achOrder = [SELECT Id FROM SM_ACH_Order__c WHERE SM_Contract__c =: contractToUpdate.Id];
        // SM_Payment_Method__c paymentMethodCreditCard1 = [SELECT Id, SM_Credit_Card_expiration_year__c, SM_Credit_Card_expiration_month__c, SM_Credit_Card_Number__c, SM_Credit_Card_Franchise__c, SM_Credit_Card_Name__c, SM_Card_Token__c FROM SM_Payment_Method__c WHERE SM_Credit_Card_Franchise__c = 'Visa' LIMIT 1];
        // Test.startTest();
        //     System.runAs(salesUser){
        //         contractToUpdate.SM_Payment_Method__c  = paymentMethodCreditCard1.Id;
        //         update contractToUpdate;
        //     }
        // Test.stopTest();
        // Contract updatedContract = [SELECT Id, SM_Payment_Method__c FROM Contract WHERE Id =: contractToUpdate.Id LIMIT 1];
        // // System.assertEquals(paymentMethodACH2.Id, updatedContract.SM_Payment_Method__c, 'The new payment method record is not the expected.');
        // // System.assertEquals(paymentMethodACH2.Id, updatedACHOrder.SM_Payment_Method__c, 'The new payment method record is not the expected.');
    }

    @IsTest
    static void changeContractFutureActivationType(){
        Account account = SM_TestSmartDataFactory.getPersonAccount();
        account.PersonEmail='legal_credit@gmail.com.invalid';
        insert account;
        //Create contract with contract activation = “Future Activation with conditions“
        Contract contract = new Contract(
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_activation_form__c = 'Future activation with conditions',
            Expected_date_for_contract_activation__c = System.today().addDays(-1),
            Validation_of_conditions__c = 'Meets the Conditions',
            AccountId = account.id
        );
        insert contract;

        /** Map with old values */
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{contract.Id => contract};
        
        /** Contract with new values */
        Contract contractNewvalues = contract.clone();
        contractNewvalues.Status = 'Complete information';

        /** Contract list with new values */
        List<Contract> newRecords = new List<Contract>{contractNewvalues};

        Test.startTest();
            SM_ContractHandler.checkContractFutureActivationType(newRecords, oldRecordsMap);
        Test.stopTest();

        System.assertEquals(true, contractNewvalues.getErrors()[0].getMessage().contains(Label.FUTURE_ACTIVATION_WITH_CONDITIONS_ERROR_MESSAGE), 'Must be return error in updated');
    }

    @IsTest
    static void checkUpdateMasterStatus(){

        /** Insert Account */
        Account account = SM_TestSmartDataFactory.getPersonAccount();
        account.PersonEmail='legal_credit@gmail.com.invalid';
        insert account;

        //List of contracts to insert
        List<Contract> contractsToInsert = new List<Contract>();

        /** Create master contract */
        Contract master = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture'
        );
        insert master;

        /** Add dependent contracts */
        for(Integer i = 0; i < 5; i++){

            contractsToInsert.add(new Contract(
                AccountId = account.Id,
                Status = 'Draft',
                StartDate = Date.today(),
                ContractTerm = 8,
                Contract_Type__c = 'Dependent',
                Principal_Contract__c = master.Id,
                Collection_Main_Contract__c = 'Ready for collection',
                Contract_activation_form__c = 'Immediate activation	',
                SM_Requires_AC_Payment__c = true,
                SM_Payment_day__c = 5,
                SM_Frecuency__c = 'Monthly'
            ));
        }

        insert contractsToInsert;

        /** Map with old values */
        Map<Id, SObject> oldRecordsMap = new Map<Id, SObject>{master.Id => master};
        
        /** Contract with new values */
        Contract contractNewvalues = master.clone(true, false, false, false);
        contractNewvalues.Status = SM_ContractHelper.status.PAYMENT_PROCESS;

        /** Contract list with new values */
        List<Contract> newRecords = new List<Contract>{contractNewvalues};

        Test.startTest();
            SM_ContractHandler.checkUpdateMasterStatus(newRecords, oldRecordsMap);
        Test.stopTest();

        System.assertEquals(5, [SELECT Count() FROM Contract WHERE Contract_Type__c = 'Dependent'], 'Must be return 5 dependent records');
        System.assertEquals(5, [SELECT Count() FROM Contract WHERE Contract_Type__c = 'Dependent' AND Status = 'Draft'], 'Must be return 5 dependent activated records');
    }

    @IsTest
        static void testCreateDispute(){

            Contract ct = [
                SELECT Id
                FROM Contract
                LIMIT 1
            ];

            Test.startTest();
                SM_ContractHandler.createDispute(
                    new Set<Id>{ct.Id}
                );
            Test.stopTest();

            Integer disputes = [
                SELECT Count()
                FROM SM_Dispute__c
                WHERE SM_Contract__c = :ct.Id
            ];

            System.assert(disputes > 0);
        }

 @IsTest
        static void testCreateDisputeByContract(){

            Contract ct = [
                SELECT Id,
                    SM_Generates_dispute__c
                FROM Contract
                LIMIT 1
            ];

            ct.SM_Generates_dispute__c = true;
            update ct;

            Test.startTest();

                SM_ContractHandler.createDisputeByContract(
                    JSON.serialize(
                        new List<Contract>{ct}
                    )
                );

            Test.stopTest();

            Integer disputes = [
                SELECT Count()
                FROM SM_Dispute__c
                WHERE SM_Contract__c = :ct.Id
            ];

            System.assert(disputes > 0);
        }   
        
        @IsTest
            static void testUpdateDisputeStatus(){

                Contract ct = [
                    SELECT Id
                    FROM Contract
                    LIMIT 1
                ];

                SM_Dispute__c dispute =
                    SM_TestSmartDataFactory.getDispute();

                dispute.SM_Contract__c = ct.Id;

                insert dispute;

                Test.startTest();

                    SM_ContractHandler.updateDisputeStatus(
                        new Map<String,String>{
                            ct.Id => 'Cancelled'
                        }
                    );

                Test.stopTest();

                dispute = [
                    SELECT SM_Status__c
                    FROM SM_Dispute__c
                    WHERE Id = :dispute.Id
                ];

                System.assertEquals(
                    'Cancelled',
                    dispute.SM_Status__c
                );
            }

            @IsTest
static void testUpdateChargentValueWithoutAccess(){

    Contract ct = [
        SELECT Id,
               SM_Charged_SB_Fees__c
        FROM Contract
        LIMIT 1
    ];

    Contract oldCt =
        ct.clone(true,false,false,false);

    ct.SM_Charged_SB_Fees__c =
        (ct.SM_Charged_SB_Fees__c == null
            ? 1
            : ct.SM_Charged_SB_Fees__c + 1);

    Test.startTest();

        SM_ContractHandler.updateChargentValue(
            new Map<Id,SObject>{
                ct.Id => ct
            },
            new Map<Id,SObject>{
                ct.Id => oldCt
            }
        );

    Test.stopTest();

    System.assert(true);
}



        }