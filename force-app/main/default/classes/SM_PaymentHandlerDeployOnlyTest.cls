@IsTest
private with sharing class SM_PaymentHandlerDeployOnlyTest {

    @TestSetup
    static void setupData() {
        insert new SM_Bypasser__c(
            SM_Disable_Validation_Rules__c = false,
            SetupOwnerId = UserInfo.getProfileId()
        );

        insert new SM_SetupToken__c(
            SM_Active__c = true,
            SM_ExpirationDate__c = System.now().addHours(1),
            SM_DurationMinutes__c = 30,
            Name = 'Token Payment Handler Deploy'
        );

        Account accountRecord = SM_TestSmartDataFactory.getPersonAccount();
        accountRecord.PersonEmail = 'payment.handler@test.invalid';
        insert accountRecord;

        ChargentBase__Gateway__c gatewayRecord = SM_TestSmartDataFactory.getGateway();
        insert gatewayRecord;

        SM_Company_setting__c companySetting = SM_TestSmartDataFactory.getCompanySettingPMethod(gatewayRecord.Id);
        companySetting.SM_Late_payment_fee__c = 25;
        companySetting.SM_Days_Collect_Penalty__c = 1;
        companySetting.StatusCreditCardLatePaymentFee__c = 'Stopped';
        insert companySetting;

        APXTConga4__Conga_Solution__c congaSolution = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert congaSolution;

        Process_automation_by_product_family__c processAutomation = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySetting.Id, congaSolution.Id);
        processAutomation.SM_Generates_dispute__c = false;
        insert processAutomation;

        Opportunity opportunityRecord = SM_TestSmartDataFactory.getOpportunity();
        opportunityRecord.AccountId = accountRecord.Id;
        opportunityRecord.SM_Company_Setting__c = companySetting.Id;
        insert opportunityRecord;

        Contract contractRecord = SM_TestSmartDataFactory.getContract(accountRecord.Id, processAutomation.Id);
        contractRecord.SM_Opportunity__c = opportunityRecord.Id;
        contractRecord.SM_Email_to_send_contract__c = 'contract.payment@test.invalid';
        contractRecord.SM_Generates_dispute__c = false;
        insert contractRecord;

        ChargentOrders__ChargentOrder__c chargentOrder = SM_TestSmartDataFactory.getChargentorder(accountRecord.Id, contractRecord, companySetting, 'AC');
        chargentOrder.ChargentOrders__Status__c = 'Initiated';
        chargentOrder.ChargentOrders__Payment_Status__c = 'Recurring';
        chargentOrder.ChargentOrders__Card_Type__c = 'Discover';
        chargentOrder.ChargentOrders__Card_Month_Indicator__c = '01';
        chargentOrder.ChargentOrders__Card_Last_4__c = '9999';
        chargentOrder.ChargentOrders__Card_Year_Indicator__c = '2050';
        chargentOrder.ChargentOrders__Billing_First_Name__c = 'John';
        chargentOrder.ChargentOrders__Tokenization__c = '998877';
        chargentOrder.Contract__c = contractRecord.Id;
        chargentOrder.ChargentOrders__Payment_Start_Date__c = System.today();
        insert chargentOrder;

        ChargentOrders__Transaction__c chargentTransaction = new ChargentOrders__Transaction__c(
            ChargentOrders__Type__c = 'Authorization',
            ChargentOrders__Response_Status__c = 'Approved',
            ChargentOrders__Tokenization__c = '091-29382-298292829229',
            ChargentOrders__Order__c = chargentOrder.Id,
            ChargentOrders__Reason_Code__c = 100,
            Contract__c = contractRecord.Id,
            ChargentOrders__Gateway__c = gatewayRecord.Id
        );
        insert chargentTransaction;
    }

    @IsTest
    static void shouldCreateLatePaymentFeeChargentOrderForRejectedCreditCardPayment() {
        Contract contractRecord = [SELECT Id FROM Contract LIMIT 1];
        ChargentOrders__Transaction__c chargentTransaction = [SELECT Id FROM ChargentOrders__Transaction__c LIMIT 1];
        Id creditCardRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'Credit Card');

        Test.startTest();
            SM_Payment__c rejectedPayment = new SM_Payment__c(
                RecordTypeId = creditCardRecordTypeId,
                SM_Amount__c = 69,
                SM_Contract__c = contractRecord.Id,
                SM_Chargent_Orders_Transaction__c = chargentTransaction.Id,
                Payment_Status__c = SM_PaymentHelper.status.REJECTED,
                SM_Type__c = SM_ACHOrderHelper.paymentType.AC,
                SM_Original_Type__c = 'AC'
            );
            insert rejectedPayment;
        Test.stopTest();

        List<ChargentOrders__ChargentOrder__c> penaltyOrders = [
            SELECT Id, SM_Payment_Type__c, ChargentOrders__Payment_Frequency__c, ChargentOrders__Payment_Status__c,
                   SM_Failed_Payment__c, SM_Penalty_Value__c, SM_Apply_Penalty__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :contractRecord.Id
            AND SM_Payment_Type__c = 'Late payment fee'
        ];

        //calp Aug 2026 :: Chargent app is permanently disabled; no Chargent order should be
        //created for a rejected credit card payment anymore.
        System.assertEquals(0, penaltyOrders.size(), 'Chargent is disabled; no late payment fee order should be created.');
    }

    @IsTest
    static void shouldSetReceiptStatusForRejectedCreditCardPayment() {
        Contract contractRecord = [SELECT Id FROM Contract LIMIT 1];
        ChargentOrders__Transaction__c chargentTransaction = [SELECT Id FROM ChargentOrders__Transaction__c LIMIT 1];
        Id creditCardRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'Credit Card');

        Test.startTest();
            SM_Payment__c rejectedPayment = new SM_Payment__c(
                RecordTypeId = creditCardRecordTypeId,
                SM_Amount__c = 10,
                SM_Contract__c = contractRecord.Id,
                SM_Chargent_Orders_Transaction__c = chargentTransaction.Id,
                Payment_Status__c = SM_PaymentHelper.status.REJECTED,
                SM_Type__c = SM_ACHOrderHelper.paymentType.FEE,
                SM_Original_Type__c = 'Fee'
            );
            insert rejectedPayment;
        Test.stopTest();

        SM_Payment__c insertedPayment = [SELECT Id, SM_Chargent_Orders_Transaction__c FROM SM_Payment__c ORDER BY CreatedDate DESC LIMIT 1];
        System.assertNotEquals(null, insertedPayment.Id, 'Expected rejected credit card payment to be inserted.');
        System.assertNotEquals(null, insertedPayment.SM_Chargent_Orders_Transaction__c, 'Expected payment to remain linked to the Chargent transaction.');
    }
}