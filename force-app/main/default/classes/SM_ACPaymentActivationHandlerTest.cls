/**
 * @description Coverage for SM_ACPaymentActivationHandler - see that class for the gap this
 * closes (ChargeBee/Credit Card/Cash AC payments never activated their contract).
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class SM_ACPaymentActivationHandlerTest {

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
        Opportunity opp = SM_TestSmartDataFactory.getOpportunity();
        opp.SM_Company_Setting__c = companySettings.Id;
        insert opp;
    }

    private static Contract newACContract(Decimal totalAc, Boolean split) {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Process_automation_by_product_family__c prdAutoByFamily = [SELECT Id FROM Process_automation_by_product_family__c LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contract ct = SM_TestSmartDataFactory.getContract(acc.Id, prdAutoByFamily.Id);
        ct.SM_Opportunity__c = opp.Id;
        ct.SM_Email_to_send_contract__c = 'test@gmail.com';
        // Real ChargeBee contracts (incl. 00318338, the one this handler was built for) all
        // use the "Credit Rectification" RecordType.
        ct.RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Contract', 'Credit Rectification');
        // A Contract can only ever be INSERTed as Draft (SM_TestSmartDataFactory's default) -
        // any other Status at insert time fails with FAILED_ACTIVATION. Payment Process is
        // only reachable via a follow-up UPDATE, same as SM_ContractHelper.updateContract()
        // does it elsewhere in the app.
        insert ct;

        SM_Payment_Method__c pm = SM_TestSmartDataFactory.getCreditCardPaymentMethod(acc.Id, 'Visa');
        insert pm;

        ct.Status = 'Payment Process';
        ct.SM_Payment_Method__c = pm.Id;
        ct.SM_Payment_methods__c = 'Credit Card';
        ct.SM_Requires_AC_Payment__c = true;
        ct.SM_Total_AC__c = totalAc;
        if (split) {
            ct.SM_AC_Split_Date__c = Date.today().addDays(15);
        }
        update ct;
        return ct;
    }

    private static SM_Payment__c newNonAchAcPayment(Id contractId, String status, Decimal amount) {
        return new SM_Payment__c(
            SM_Contract__c = contractId,
            SM_Type__c = SM_ACHOrderHelper.paymentType.AC,
            Payment_Status__c = status,
            SM_Amount__c = amount
        );
    }

    @IsTest
    static void activatesContractOnAcPaymentAcceptedAtInsert() {
        Contract ct = newACContract(99, false);

        Test.startTest();
            insert newNonAchAcPayment(ct.Id, 'ACCEPTED', 99);
        Test.stopTest();

        Contract updated = [SELECT Status, SM_AC_collected__c, SM_Charged_AC_Amount__c, SM_Payment_Received__c, StartDate, SM_Id_Salesforce_LCS__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Activated', updated.Status, 'Contract should activate once the AC payment is accepted.');
        System.assertEquals(true, updated.SM_AC_collected__c, 'SM_AC_collected__c should be set.');
        System.assertEquals(99, updated.SM_Charged_AC_Amount__c, 'Charged AC amount should equal the payment amount.');
        System.assertEquals(true, updated.SM_Payment_Received__c, 'Payment received should be set.');
        System.assertEquals(Date.today(), updated.StartDate, 'StartDate should move to today on activation.');
        System.assert(updated.SM_Id_Salesforce_LCS__c.startsWith('AUTO: SM_ACPaymentActivationHandler'), 'An automation marker should identify what activated the contract.');
    }

    // NOTE: the symmetrical "insert as PENDING, then update to ACCEPTED" scenario (which
    // SM_ACPaymentActivationHandler.afterUpdate() is written to cover) currently cannot be
    // tested or used in production at all: updating Payment_Status__c on ANY payment without
    // SM_ACH_Order__c to ACCEPTED/REJECTED throws an unrelated, pre-existing
    // NullPointerException in SM_PaymentHandler.updateRelatedRecordsByPaymentStatusUpdates
    // (line 258 dereferences achOrder without a null check) which rolls back the whole
    // transaction - confirmed 2026-09-12 via this same validation. That bug lives in a file
    // this change intentionally does not touch (SM_PaymentHandler is mid-sync for the
    // Chargent cleanup). Every real ChargeBee AC payment observed so far (incl. PY-01890288 /
    // contract 00318338) is created by the integration already ACCEPTED, so afterInsert() -
    // covered by activatesContractOnAcPaymentAcceptedAtInsert above - is what actually runs
    // in production today. See BITACORA_HALLAZGOS_TECNICOS.md for the fix this needs.

    @IsTest
    static void accumulatesSplitAcPaymentsBeforeActivating() {
        Contract ct = newACContract(100, true);

        Test.startTest();
            insert newNonAchAcPayment(ct.Id, 'ACCEPTED', 50);
        Test.stopTest();

        Contract afterFirst = [SELECT Status, SM_AC_collected__c, SM_Charged_AC_Amount__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(50, afterFirst.SM_Charged_AC_Amount__c, 'First half should accumulate.');
        System.assertEquals(false, afterFirst.SM_AC_collected__c, 'Contract should not activate on a partial AC payment.');
        System.assertEquals('Payment Process', afterFirst.Status, 'Contract should stay in Payment Process until the AC total is reached.');

        insert newNonAchAcPayment(ct.Id, 'ACCEPTED', 50);

        Contract afterSecond = [SELECT Status, SM_AC_collected__c, SM_Charged_AC_Amount__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(100, afterSecond.SM_Charged_AC_Amount__c, 'Both halves should accumulate to the AC total.');
        System.assertEquals(true, afterSecond.SM_AC_collected__c, 'Contract should activate once the AC total is reached.');
        System.assertEquals('Activated', afterSecond.Status, 'Contract should be Activated.');
    }

    @IsTest
    static void doesNotReactivateAlreadyCollectedAc() {
        Contract ct = newACContract(99, false);
        ct.SM_AC_collected__c = true;
        ct.Status = 'Activated';
        update ct;

        Test.startTest();
            insert newNonAchAcPayment(ct.Id, 'ACCEPTED', 99);
        Test.stopTest();

        Contract updated = [SELECT SM_Charged_AC_Amount__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(null, updated.SM_Charged_AC_Amount__c, 'A contract whose AC is already collected should not be re-accumulated.');
    }

    @IsTest
    static void ignoresNonAcPaymentTypes() {
        Contract ct = newACContract(99, false);

        Test.startTest();
            insert new SM_Payment__c(
                SM_Contract__c = ct.Id,
                SM_Type__c = SM_ACHOrderHelper.paymentType.FEE,
                Payment_Status__c = 'ACCEPTED',
                SM_Amount__c = 99
            );
        Test.stopTest();

        Contract updated = [SELECT Status, SM_AC_collected__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Payment Process', updated.Status, 'A Fee payment should not activate the AC gate.');
        System.assertEquals(false, updated.SM_AC_collected__c, 'SM_AC_collected__c should remain untouched.');
    }

    @IsTest
    static void doesNotActivateFinalizedContract() {
        Contract ct = newACContract(99, false);
        ct.Status = 'Finalized';
        update ct;

        Test.startTest();
            insert newNonAchAcPayment(ct.Id, 'ACCEPTED', 99);
        Test.stopTest();

        Contract updated = [SELECT Status, SM_AC_collected__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals('Finalized', updated.Status, 'A closed contract should never be reopened by this handler.');
        System.assertEquals(false, updated.SM_AC_collected__c, 'SM_AC_collected__c should remain untouched on a closed contract.');
    }
}
