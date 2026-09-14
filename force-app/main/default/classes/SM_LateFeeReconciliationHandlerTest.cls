/**
 * @description Coverage for SM_LateFeeReconciliationHandler - see that class for the gap this
 * closes (Late Payment Fee orders left Stopped forever once the original rejected payment is
 * later confirmed COLLECTED by the bank).
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class SM_LateFeeReconciliationHandlerTest {

    @TestSetup
    static void makeData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert acc;
        Contract ct = new Contract(
            AccountId = acc.Id,
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Contract', 'Credit Rectification')
        );
        insert ct;
    }

    private static SM_Payment__c newRejectedPayment(Id contractId) {
        SM_Payment__c payment = new SM_Payment__c(
            SM_Contract__c = contractId,
            SM_Type__c = 'Fee',
            Payment_Status__c = 'REJECTED',
            SM_Check_Collection_Status__c = 'PENDING',
            SM_Amount__c = 69
        );
        insert payment;
        return payment;
    }

    private static SM_ACH_Order__c newStoppedLateFee(Id contractId, Id failedPaymentId) {
        SM_ACH_Order__c lateFee = SM_TestSmartDataFactory.getACHOrder(contractId);
        lateFee.SM_Payment_Type__c = 'Late payment fee';
        lateFee.SM_Payment_Status__c = 'Stopped';
        lateFee.SM_Failed_payment__c = failedPaymentId;
        // SM_ACHOrderHandler.insertNextScheduledPaymentDate (pre-existing, unrelated bug -
        // see SM_ACHOrderTrigger BeforeInsert) dereferences SM_Next_Transaction_Date__c
        // unconditionally on every insert, so it must be populated here.
        lateFee.SM_Next_Transaction_Date__c = Date.today();
        insert lateFee;
        return lateFee;
    }

    @IsTest
    static void cancelsStoppedLateFeeWhenOriginalPaymentBecomesCollected() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = newRejectedPayment(ct.Id);
        SM_ACH_Order__c lateFee = newStoppedLateFee(ct.Id, payment.Id);

        Test.startTest();
            payment.SM_Check_Collection_Status__c = 'COLLECTED';
            payment.Payment_Status__c = 'ACCEPTED';
            update payment;
        Test.stopTest();

        SM_ACH_Order__c updated = [SELECT SM_Payment_Status__c, SM_Next_Transaction_Date__c, SM_Id_Salesforce_LCS__c FROM SM_ACH_Order__c WHERE Id = :lateFee.Id];
        System.assertEquals('Canceled', updated.SM_Payment_Status__c, 'The Late Payment Fee should be canceled once the original payment is confirmed COLLECTED.');
        System.assertEquals(null, updated.SM_Next_Transaction_Date__c, 'The next transaction date should be cleared so the daily batch never picks it up.');
        System.assert(updated.SM_Id_Salesforce_LCS__c.contains('Cancelado por pago de Cobro original'), 'A note explaining the cancellation should be recorded.');
    }

    @IsTest
    static void preservesExistingNoteWhenCancelling() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = newRejectedPayment(ct.Id);
        SM_ACH_Order__c lateFee = newStoppedLateFee(ct.Id, payment.Id);
        lateFee.SM_Id_Salesforce_LCS__c = 'PREVIOUS_NOTE';
        update lateFee;

        Test.startTest();
            payment.SM_Check_Collection_Status__c = 'COLLECTED';
            update payment;
        Test.stopTest();

        SM_ACH_Order__c updated = [SELECT SM_Id_Salesforce_LCS__c FROM SM_ACH_Order__c WHERE Id = :lateFee.Id];
        System.assert(updated.SM_Id_Salesforce_LCS__c.contains('PREVIOUS_NOTE'), 'The pre-existing note should be preserved, not overwritten.');
        System.assert(updated.SM_Id_Salesforce_LCS__c.contains('Cancelado por pago de Cobro original'), 'The new cancellation note should also be present.');
    }

    @IsTest
    static void doesNotTouchLateFeeWhenPaymentIsNotCollected() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = newRejectedPayment(ct.Id);
        SM_ACH_Order__c lateFee = newStoppedLateFee(ct.Id, payment.Id);

        Test.startTest();
            payment.SM_Check_Collection_Status__c = 'RETURN';
            update payment;
        Test.stopTest();

        SM_ACH_Order__c updated = [SELECT SM_Payment_Status__c FROM SM_ACH_Order__c WHERE Id = :lateFee.Id];
        System.assertEquals('Stopped', updated.SM_Payment_Status__c, 'A non-final collection status should never touch the Late Payment Fee.');
    }

    @IsTest
    static void ignoresLateFeeAlreadyOutOfStopped() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = newRejectedPayment(ct.Id);
        SM_ACH_Order__c lateFee = newStoppedLateFee(ct.Id, payment.Id);
        lateFee.SM_Payment_Status__c = 'Completed';
        update lateFee;

        Test.startTest();
            payment.SM_Check_Collection_Status__c = 'COLLECTED';
            update payment;
        Test.stopTest();

        SM_ACH_Order__c updated = [SELECT SM_Payment_Status__c, SM_Id_Salesforce_LCS__c FROM SM_ACH_Order__c WHERE Id = :lateFee.Id];
        System.assertEquals('Completed', updated.SM_Payment_Status__c, 'A Late Payment Fee already out of Stopped should never be touched by this handler.');
        System.assertEquals(null, updated.SM_Id_Salesforce_LCS__c, 'No note should be written for an order this handler did not act on.');
    }
}
