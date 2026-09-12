/**
 * @description Regression coverage for the SM_PaymentHandler.updateRelatedRecordsByPaymentStatusUpdates
 * NullPointerException fix (2026-09-12): a payment with no SM_ACH_Order__c (ChargeBee/Credit
 * Card/Cash) used to crash the whole transaction when its Payment_Status__c changed to
 * ACCEPTED or REJECTED, because achOrder was dereferenced without a null check. Kept separate
 * from SM_PaymentHandlerTest.cls, which still references a field already removed from
 * SM_Payment__c in the live org and needs its own re-sync.
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class SM_PaymentHandlerNonAchStatusTest {

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

    @IsTest
    static void statusChangeToAcceptedOnNonAchPaymentDoesNotThrow() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = new SM_Payment__c(
            SM_Contract__c = ct.Id,
            SM_Type__c = 'AC',
            Payment_Status__c = 'PENDING',
            SM_Amount__c = 99
        );
        insert payment;

        Test.startTest();
            payment.Payment_Status__c = 'ACCEPTED';
            update payment;
        Test.stopTest();

        SM_Payment__c updated = [SELECT Payment_Status__c FROM SM_Payment__c WHERE Id = :payment.Id];
        System.assertEquals('ACCEPTED', updated.Payment_Status__c, 'The status update should go through without the handler throwing.');
    }

    @IsTest
    static void statusChangeToRejectedOnNonAchPaymentDoesNotThrow() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_Payment__c payment = new SM_Payment__c(
            SM_Contract__c = ct.Id,
            SM_Type__c = 'AC',
            Payment_Status__c = 'PENDING',
            SM_Amount__c = 99
        );
        insert payment;

        Test.startTest();
            payment.Payment_Status__c = 'REJECTED';
            update payment;
        Test.stopTest();

        SM_Payment__c updated = [SELECT Payment_Status__c FROM SM_Payment__c WHERE Id = :payment.Id];
        System.assertEquals('REJECTED', updated.Payment_Status__c, 'The status update should go through without the handler throwing.');
    }
}
