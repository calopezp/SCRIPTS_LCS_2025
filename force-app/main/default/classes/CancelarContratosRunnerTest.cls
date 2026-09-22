/**
 * @description Coverage for CancelarContratosRunner - see that class for the business rules
 * and the gotchas (callout/DML ordering, dependent picklist, per-contract request date) this
 * exercises.
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class CancelarContratosRunnerTest {

    private static final Date REQUEST_DATE = Date.newInstance(2026, 6, 10);

    @TestSetup
    static void makeData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert acc;
        SM_Company_setting__c companySettings = SM_TestSmartDataFactory.getCompanySetting();
        insert companySettings;
        APXTConga4__Conga_Solution__c congaSolution = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
        insert congaSolution;
        Process_automation_by_product_family__c prdAutoByFamily = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettings.Id, congaSolution.Id);
        insert prdAutoByFamily;
    }

    private static Contract insertBaseContract() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Process_automation_by_product_family__c prd = [SELECT Id FROM Process_automation_by_product_family__c LIMIT 1];
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, prd.Id);
        ct.RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Contract', 'Credit Rectification');
        insert ct;
        return ct;
    }

    private static Contract newAchContract() {
        Contract ct = insertBaseContract();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SM_Bank__c bank = new SM_Bank__c(Name = 'Test Bank', SM_Routing_Number__c = '111111111');
        insert bank;
        SM_Payment_Method__c pm = SM_TestSmartDataFactory.getACHPaymentMethod(acc.Id, 'Test Bank');
        pm.SM_Bank__c = bank.Id;
        insert pm;
        ct.Status = 'Payment Process';
        ct.SM_Payment_Method__c = pm.Id;
        ct.SM_Payment_methods__c = 'ACH';
        update ct;
        return [SELECT Id, ContractNumber, Status FROM Contract WHERE Id = :ct.Id];
    }

    private static Contract newChargebeeContract(String subscriptionStatus) {
        Contract ct = insertBaseContract();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        chargebeeapps__CB_Subscription__c sub = new chargebeeapps__CB_Subscription__c(
            Name = 'SUBTEST' + ct.Id,
            chargebeeapps__Company__c = acc.Id,
            chargebeeapps__Subscription_status__c = subscriptionStatus
        );
        insert sub;
        SM_Payment_Method__c pm = SM_TestSmartDataFactory.getCreditCardPaymentMethod(acc.Id, 'Visa');
        insert pm;
        ct.Status = 'Payment Process';
        ct.SM_Payment_Method__c = pm.Id;
        ct.SM_Payment_methods__c = 'Credit Card';
        ct.CB_Subscription__c = sub.Id;
        update ct;
        return [SELECT Id, ContractNumber, Status, CB_Subscription__c FROM Contract WHERE Id = :ct.Id];
    }

    private static chargebeeapps__CB_Invoice__c newInvoice(Id contractId, String invoiceId, String status) {
        return new chargebeeapps__CB_Invoice__c(
            Contract__c = contractId,
            chargebeeapps__InvoiceID__c = invoiceId,
            chargebeeapps__CB_Invoice_Id__c = invoiceId,
            chargebeeapps__Status__c = status
        );
    }

    private static SM_Payment__c newAchPayment(Id contractId, String paymentStatus, String collectionStatus) {
        return new SM_Payment__c(
            SM_Contract__c = contractId,
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH'),
            Payment_Status__c = paymentStatus,
            SM_Check_Collection_Status__c = collectionStatus,
            SM_Amount__c = 50
        );
    }

    private static CancelarContratosRunner.CancelRequest requestFor(String contractNumber, String reason) {
        return new CancelarContratosRunner.CancelRequest(contractNumber, reason, REQUEST_DATE);
    }

    // Mocks a fixed status code for every callout in the transaction - good enough here
    // because a failing void() always short-circuits before cancel_for_items is attempted.
    private class ChargebeeMock implements HttpCalloutMock {
        private final Integer statusCode;
        ChargebeeMock(Integer code) { statusCode = code; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(statusCode == 200 ? '{"invoice":{"status":"voided"}}' : '{"message":"error"}');
            return res;
        }
    }

    @IsTest
    static void achContractCancelsWhenNoBlockingPayments() {
        Contract ct = newAchContract();
        SM_ACH_Order__c newOrder = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        newOrder.SM_Next_Transaction_Date__c = Date.today();
        insert newOrder;
        SM_ACH_Order__c order = [SELECT Id, SM_Payment_Status__c FROM SM_ACH_Order__c WHERE SM_Contract__c = :ct.Id];
        order.SM_Payment_Status__c = 'Pending';
        update order;

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        System.assertEquals(1, outcome.size(), 'One result row for the one ACH contract.');
        System.assertEquals(true, outcome[0].success, 'Should succeed with no blocking payments.');
        System.assertEquals('CANCELLED', outcome[0].action, 'Action should report CANCELLED.');

        Contract updated = [SELECT Status, SM_Reason_for_cancellation__c, SM_Customer_Cancellation__c, SM_Cancellation_Date__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Cancelled', updated.Status, 'Contract should be Cancelled.');
        System.assertEquals('Does not comply with payments', updated.SM_Reason_for_cancellation__c,
            'Reason should be set via the 2-phase DML fix (Status then Reason).');
        System.assertEquals(true, updated.SM_Customer_Cancellation__c, 'Customer cancellation flag should be set.');
        System.assertEquals(REQUEST_DATE, updated.SM_Cancellation_Date__c,
            'SM_Cancellation_Date__c must be the requested date from the CSV, not Date.today().');

        SM_ACH_Order__c updatedOrder = [SELECT SM_Payment_Status__c FROM SM_ACH_Order__c WHERE Id = :order.Id];
        System.assertEquals('Canceled', updatedOrder.SM_Payment_Status__c, 'ACH order should be Canceled.');

        Task t = [SELECT Subject, Description FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals('Customer Service-Effective Cancellation', t.Subject, 'Task should be created.');
        System.assert(t.Description.contains('ELba Mantilla'), 'Known reason should map to its historical Task text.');
    }

    @IsTest
    static void achContractSkippedWhenPaymentBlocking() {
        Contract ct = newAchContract();
        insert newAchPayment(ct.Id, 'REJECTED', 'PENDING');

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        System.assertEquals(false, outcome[0].success, 'Should be blocked by the unresolved payment.');
        System.assertEquals('SKIP', outcome[0].action, 'Action should report SKIP.');

        Contract updated = [SELECT Status FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Payment Process', updated.Status, 'Contract must NOT be cancelled while a payment is unresolved.');
    }

    @IsTest
    static void achContractCancelsWithNotCollectedSpaceVariant() {
        // Regression test: SM_Check_Collection_Status__c is free text, and legacy data has
        // 'NOT COLLECTED' (with a space) instead of the standard 'NOT_COLLECTED'. Both must be
        // treated as resolved/allowed.
        Contract ct = newAchContract();
        insert newAchPayment(ct.Id, 'REJECTED', 'NOT COLLECTED');

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        System.assertEquals(true, outcome[0].success, '"NOT COLLECTED" (with space) must be treated as resolved.');

        Contract updated = [SELECT Status FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Cancelled', updated.Status, 'Contract should be Cancelled despite the space variant.');
    }

    @IsTest
    static void chargebeeContractCancelsOnSuccessfulApiCalls() {
        Contract ct = newChargebeeContract('ACTIVE');
        insert newInvoice(ct.Id, 'INV0001', 'PAYMENT_DUE');

        Test.setMock(HttpCalloutMock.class, new ChargebeeMock(200));

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        System.assertEquals(true, outcome[0].success, 'Should succeed when Chargebee accepts both callouts.');
        System.assertEquals('CHARGEBEE_CANCELLED', outcome[0].action, 'Action should report CHARGEBEE_CANCELLED.');

        Contract updated = [SELECT Status, SM_Reason_for_cancellation__c, SM_Cancellation_Date__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Cancelled', updated.Status, 'Contract should be Cancelled.');
        System.assertEquals('Does not comply with payments', updated.SM_Reason_for_cancellation__c, 'Reason should be set.');
        System.assertEquals(REQUEST_DATE, updated.SM_Cancellation_Date__c,
            'SM_Cancellation_Date__c must be the requested date from the CSV, not Date.today().');

        chargebeeapps__CB_Invoice__c inv = [SELECT chargebeeapps__Status__c FROM chargebeeapps__CB_Invoice__c WHERE Contract__c = :ct.Id];
        System.assertEquals('VOIDED', inv.chargebeeapps__Status__c, 'Invoice should be marked VOIDED locally.');
    }

    @IsTest
    static void chargebeeContractStaysOpenOnApiError() {
        Contract ct = newChargebeeContract('ACTIVE');
        insert newInvoice(ct.Id, 'INV0002', 'PAYMENT_DUE');

        Test.setMock(HttpCalloutMock.class, new ChargebeeMock(400));

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        System.assertEquals(false, outcome[0].success, 'Should NOT succeed when Chargebee rejects the void call.');
        System.assertEquals('PARTIAL/PENDING', outcome[0].action, 'Action should report PARTIAL/PENDING.');

        Contract updated = [SELECT Status FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Payment Process', updated.Status,
            'Contract must never be marked Cancelled when the Chargebee API call failed.');
    }

    @IsTest
    static void unknownReasonFallsBackToGenericTaskText() {
        Contract ct = newAchContract();

        CancelarContratosRunner.CancelRequest req = requestFor(ct.ContractNumber, 'Some brand new reason');

        Test.startTest();
        CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, false);
        Test.stopTest();

        Task t = [SELECT Description FROM Task WHERE WhatId = :ct.Id];
        System.assertEquals('Cancelación solicitada — Some brand new reason', t.Description,
            'An unmapped reason should fall back to the generic Task text instead of failing.');
    }

    @IsTest
    static void dryRunMakesNoCalloutsOrChanges() {
        Contract achCt = newAchContract();
        Contract cbCt = newChargebeeContract('ACTIVE');
        insert newInvoice(cbCt.Id, 'INV0003', 'PAYMENT_DUE');

        List<CancelarContratosRunner.CancelRequest> requests = new List<CancelarContratosRunner.CancelRequest>{
            requestFor(achCt.ContractNumber, 'Does not comply with payments'),
            requestFor(cbCt.ContractNumber, 'Does not comply with payments')
        };

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome = CancelarContratosRunner.run(requests, true);
        System.assertEquals(0, Limits.getCallouts(), 'Dry run must never call out to Chargebee.');
        Test.stopTest();

        System.assertEquals(2, outcome.size(), 'One row per contract.');
        for (CancelarContratosRunner.ResultRow r : outcome) {
            System.assertEquals(true, r.success, 'Dry run rows report what WOULD happen, not a failure.');
            System.assert(r.action.startsWith('DRY_RUN'), 'Action should be a DRY_RUN variant.');
        }

        Contract achAfter = [SELECT Status FROM Contract WHERE Id = :achCt.Id];
        Contract cbAfter  = [SELECT Status FROM Contract WHERE Id = :cbCt.Id];
        System.assertEquals('Payment Process', achAfter.Status, 'Dry run must not change the ACH contract.');
        System.assertEquals('Payment Process', cbAfter.Status, 'Dry run must not change the Chargebee contract.');
    }

    @IsTest
    static void reportsNotFoundForUnknownContractNumber() {
        CancelarContratosRunner.CancelRequest req = requestFor('00000000', 'Does not comply with payments');

        Test.startTest();
        List<CancelarContratosRunner.ResultRow> outcome =
            CancelarContratosRunner.run(new List<CancelarContratosRunner.CancelRequest>{ req }, true);
        Test.stopTest();

        System.assertEquals(1, outcome.size(), 'One row reporting the missing contract.');
        System.assertEquals('NOT_FOUND', outcome[0].action, 'Action should report NOT_FOUND.');
        System.assertEquals(false, outcome[0].success, 'NOT_FOUND is not a success.');
    }
}
