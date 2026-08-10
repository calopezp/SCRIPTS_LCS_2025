/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 22/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   03-27-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
@IsTest
public without sharing class SM_PaymentHelperTest {

    @TestSetup
    static void makeData(){
        
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());

        Account account = SM_TestSmartDataFactory.getPersonAccount();
        account.PersonEmail='legal_credit@gmail.com.invalid';
        insert account;
        ChargentBase__Gateway__c Gt = SM_TestSmartDataFactory.getGateway();
        insert Gt;
        SM_Company_setting__c companySettingObj = SM_TestSmartDataFactory.getCompanySettingPMethod(Gt.Id);
        companySettingObj.SM_Abbreviated_Company__c = 'LCS';
        insert companySettingObj;
        APXTConga4__Conga_Solution__c conga4CongaSolutionObj = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert conga4CongaSolutionObj;
        Process_automation_by_product_family__c processautomationProductfamilyObj = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettingObj.id,conga4CongaSolutionObj.id);
        processautomationProductfamilyObj.SM_Generates_dispute__c = true;
        insert processautomationProductfamilyObj;
        Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
        opp.SM_Company_Setting__c = companySettingObj.Id;
        insert opp;
        Contract contract = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
        contract.SM_Email_to_send_contract__c = 'test@yopmail.com';
        contract.SM_Opportunity__c = opp.Id;
        insert contract;
        SM_Payment__c payment  = SM_TestSmartDataFactory.getPayment(contract.Id);
        insert payment;
    }

    @IsTest
    static void testDoNothing(){
        Test.startTest();
        String status = SM_PaymentHelper.status.ACCEPTED;
        Test.stopTest();
    }

    @IsTest
    static void testSendPaymentReceipt(){
        Contract ct = [SELECT Id FROM Contract];
        Test.startTest();
            SM_Payment__c payment  = SM_TestSmartDataFactory.getPayment(ct.Id);
            payment.Payment_Status__c = 'ACCEPTED';
            insert payment;
            //calp Aug 2026 :: direct call to cover the @Future sendPaymentReceipts path,
            //which isn't reached by any trigger in this test.
            SM_PaymentHelper.sendPaymentReceipts('[]');
        Test.stopTest();
    }

    @IsTest
    static void setFeeToCollectFromFailetPaymentACHOk() {

        /** Insert Account */
        Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail='legal_credit@gmail.com.invalid';
            insert account;

        /** Create master contract */
        Contract master = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 45.68
        );
        insert master;

        /** Create payment to master */
        SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Contract__c = master.Id,
            SM_Amount__c = 35,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 2,
            Payment_Status__c = 'ACH PENDING'
        );
        insert masterPayment;

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE,
            SM_Next_Transaction_Date__c = System.toDay(),
            SM_Penalty_date__c = System.toDay().addDays(4),
            SM_Payment_Start_Date__c = System.toDay().addDays(2),
            SM_Apply_penalty__c = true,
            SM_Reason_to_approve_exoneration__c = 'Family Emergency',
            SM_Failed_Payment__c = masterPayment.Id
        );

        Test.startTest();
            SM_PaymentHelper.setFeeToCollectFromFailetPayment(new List<SObject>{achOrder});
        Test.stopTest();

        System.assertEquals(2, achOrder.SM_Fee_to_collect__c, 'SM_Fee_to_collect__c don´t updated');
    }

    @IsTest
    static void setFeeToCollectFromFailetPaymentChargentOk() {

        /** Insert Account */
        Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail='legal_credit@gmail.com.invalid';
            insert account;

        /** Create master contract */
        Contract master = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 45.68
        );
        insert master;

        /** Create payment to master */
        SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Contract__c = master.Id,
            SM_Amount__c = 35,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 3,
            Payment_Status__c = 'ACH PENDING'
        );
        insert masterPayment;

        /** Create chargent */
        ChargentOrders__ChargentOrder__c chargent = new ChargentOrders__ChargentOrder__c(
            ChargentOrders__Payment_Frequency__c = 'Once',
            ChargentOrders__Payment_Method__c = 'Credit Card',
            ChargentOrders__Tokenization__c = '1929826725-1841993424',
            SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE,
            Contract__c = master.Id,
            SM_Failed_Payment__c = masterPayment.Id
        );
        insert chargent;

        Test.startTest();
            SM_PaymentHelper.setFeeToCollectFromFailetPayment(new List<SObject>{chargent});
        Test.stopTest();

        System.assertEquals(3, chargent.SM_Fee_to_collect__c, 'SM_Fee_to_collect__c don´t updated');
    }

    @IsTest
    static void testBuildSingleMessageAndEmailAttachment(){
        SM_PaymentHelper.EmailWrapper wrapper = new SM_PaymentHelper.EmailWrapper(
            'test@yopmail.com',
            'Payment receipt',
            'Body',
            'Contract',
            'receipt.pdf',
            'a0A000000000001',
            'Contract',
            '800000000000001',
            true,
            'LCS'
        );
        wrapper.documentBlob = Blob.valueOf('Test PDF');

        Test.startTest();
            Messaging.SingleEmailMessage message = SM_PaymentHelper.buildSingleMessage(wrapper);
        Test.stopTest();

        System.assertEquals('test@yopmail.com', message.getToAddresses()[0], 'To address should be set');
        System.assertEquals('Payment receipt', message.getSubject(), 'Subject should be set');
        System.assertEquals('Body', message.getPlainTextBody(), 'Plain text body should be set');
        System.assertEquals('Body', message.getHtmlBody(), 'HTML body should be set');
        System.assertEquals(true, message.getSaveAsActivity(), 'Save as activity should be enabled');
        System.assert(String.valueOf(message.getWhatId()).startsWith(wrapper.sourceObjectId), 'WhatId should be set');

        List<Messaging.EmailFileAttachment> attachments = message.getFileAttachments();
        System.assertEquals(1, attachments.size(), 'One attachment should be added');
        System.assertEquals('receipt.pdf', attachments[0].getFileName(), 'Attachment filename should be preserved');
    }

    @IsTest
    static void testGetBlobFromPDFAndSetEmailAttachment(){
        SM_PaymentHelper.EmailWrapper wrapper = new SM_PaymentHelper.EmailWrapper(
            'test@yopmail.com',
            'Payment receipt',
            'Body',
            'Contract',
            'receipt.pdf',
            'a0A000000000001',
            'Contract',
            '800000000000001',
            true,
            'LCS'
        );
        wrapper.documentBlob = Blob.valueOf('Test PDF');

        Test.startTest();
            Blob contractPdf = SM_PaymentHelper.getBlobFromPDF('001000000000001', 'Contract');
            Blob unsupportedPdf = SM_PaymentHelper.getBlobFromPDF('001000000000001', 'Other');
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            SM_PaymentHelper.setEmailAttachment(message, wrapper);
        Test.stopTest();

        System.assertNotEquals(null, contractPdf, 'A PDF should be returned for Contract source');
        System.assertEquals(Blob.valueOf('Unit test'), contractPdf, 'The test PDF content should be provided');
        System.assertEquals(null, unsupportedPdf, 'Unsupported source should return null');
        System.assertEquals(1, message.getFileAttachments().size(), 'One attachment should be added');
    }

    @IsTest
    static void testCreatePaymentsAndCreatePayment(){
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_ACH_Order__c achOrder = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        achOrder.SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.SUBSCRIPTION;
        achOrder.SM_Total__c = 100;
        achOrder.SM_Fee_to_collect__c = 10;
        achOrder.SM_Penalty_value__c = 5;
        achOrder.SM_Apply_penalty__c = true;
        achOrder.SM_Next_Transaction_Date__c = Date.today();
        insert achOrder;

        SM_ACH_Order__c queriedOrder = [
            SELECT Id, SM_Payment_Type__c, SM_Total__c, SM_Fee_to_collect__c, SM_Penalty_value__c, SM_Apply_penalty__c,
                   SM_Next_Transaction_Date__c, SM_Contract__c,
                   SM_Contract__r.SM_Payment_Method__c,
                   SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c,
                   SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c,
                   SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c,
                   SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,
                   SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c
            FROM SM_ACH_Order__c
            WHERE Id = :achOrder.Id
        ];

        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        Test.startTest();
            List<SM_Payment__c> payments = SM_PaymentHelper.createPayments(new List<SM_ACH_Order__c>{queriedOrder});
            SM_Payment__c createdPayment = SM_PaymentHelper.createPayment(queriedOrder.Id);
        Test.stopTest();
        SM_TriggerHandler.avoidAllHandlerExcecution = false;

        System.assertEquals(1, payments.size(), 'One payment should be created');
        System.assertEquals(SM_PaymentHelper.status.ACH_PENDING, payments[0].Payment_Status__c, 'Payment status should be ACH pending');
        System.assertEquals(true, payments[0].SM_Recurring__c, 'Subscription payment should be marked recurring');
        System.assertEquals('Fee', payments[0].SM_Type__c, 'Subscription payment type should be Fee');
        System.assertNotEquals(null, createdPayment, 'createPayment should return a payment');
        System.assertEquals(SM_PaymentHelper.status.ACH_PENDING, createdPayment.Payment_Status__c, 'Created payment should have ACH pending status');
    }

    @IsTest
    static void testCreatePaymentBlockedForCustomerCancellation(){
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        ct.SM_Customer_Cancellation__c = true;
        update ct;

        SM_ACH_Order__c achOrder = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        achOrder.SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.SUBSCRIPTION;
        achOrder.SM_Total__c = 100;
        achOrder.SM_Fee_to_collect__c = 10;
        achOrder.SM_Penalty_value__c = 5;
        achOrder.SM_Apply_penalty__c = true;
        achOrder.SM_Next_Transaction_Date__c = Date.today();
        insert achOrder;

        Boolean exceptionThrown = false;

        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        Test.startTest();
            try {
                SM_PaymentHelper.createPayment(achOrder.Id);
            } catch (AuraHandledException e) {
                exceptionThrown = true;
            }
        Test.stopTest();
        SM_TriggerHandler.avoidAllHandlerExcecution = false;

        System.assertEquals(true, exceptionThrown, 'createPayment should block generation when the contract is under Customer Cancellation');
        System.assertEquals(0, [SELECT COUNT() FROM SM_Payment__c WHERE SM_ACH_Order__c = :achOrder.Id], 'No payment should be created while the contract is under Customer Cancellation');
    }

    @IsTest
    static void testGetPaymentWrappers(){
        SM_Payment__c payment = [SELECT Id FROM SM_Payment__c LIMIT 1];

        Test.startTest();
            List<SM_PaymentHelper.PaymentWrapper> wrappers = SM_PaymentHelper.getPaymentWrappers(new Set<Id>{payment.Id});
        Test.stopTest();

        System.assertEquals(1, wrappers.size(), 'One wrapper should be generated');
        System.assertEquals(payment.Id, wrappers[0].payment.Id, 'Wrapper should contain the queried payment');
        System.assertNotEquals(null, wrappers[0].achOrChargentObj, 'Wrapper should contain a related object instance');
    }

    @IsTest
    static void testUpdateFeeToCollectForChargent(){
        SM_Payment__c payment = [SELECT Id, Installment_number__c FROM SM_Payment__c LIMIT 1];
        payment.Installment_number__c = 7;
        update payment;

        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        ChargentOrders__ChargentOrder__c chargent = new ChargentOrders__ChargentOrder__c(
            Contract__c = ct.Id,
            SM_Failed_Payment__c = payment.Id,
            SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE
        );
        insert chargent;

        //calp Aug 2026 :: capture the value right after insert (other automation on the
        //ChargentOrder object may set it) instead of assuming null.
        Decimal feeToCollectBeforeCall = [SELECT SM_Fee_to_collect__c FROM ChargentOrders__ChargentOrder__c WHERE Id = :chargent.Id].SM_Fee_to_collect__c;

        Test.startTest();
            SM_PaymentHelper.updateFeeToCollect(new Set<String>{chargent.Id});
        Test.stopTest();

        //calp Aug 2026 :: Chargent app is permanently disabled; updateFeeToCollect() no-ops now,
        //so the Chargent order's SM_Fee_to_collect__c should stay exactly as it was before the call.
        ChargentOrders__ChargentOrder__c updatedChargent = [SELECT SM_Fee_to_collect__c FROM ChargentOrders__ChargentOrder__c WHERE Id = :chargent.Id];
        System.assertEquals(feeToCollectBeforeCall, updatedChargent.SM_Fee_to_collect__c, 'Chargent is disabled; fee to collect should not be updated');
    }

    @IsTest
    static void testUpdatePaymentStatus(){
        // Test.startTest();
        //     SM_Payment__c payment = [SELECT Id FROM SM_Payment__c];
        //     payment.Payment_Status__c = SM_PaymentHelper.status.ACH_TRANSMITTED;
        //     update payment;
        //     payment.Payment_Status__c = SM_PaymentHelper.status.ACCEPTED;
        //     update payment;
        //     payment.Payment_Status__c = SM_PaymentHelper.status.REJECTED;
        //     update payment;
        // Test.stopTest();
    }
}