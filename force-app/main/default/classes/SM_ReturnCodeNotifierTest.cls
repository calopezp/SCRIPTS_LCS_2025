/**
 * @description Coverage for SM_ReturnCodeNotifier - see that class for why R02 (ACCOUNT
 * CLOSED) returns need their own standing report.
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class SM_ReturnCodeNotifierTest {

    @TestSetup
    static void makeData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        insert acc;
        insert new Contract(
            AccountId = acc.Id,
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Contract', 'Credit Rectification')
        );
    }

    @IsTest
    static void reportsContractWithUnresolvedR02() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c FROM Contract LIMIT 1];
        SM_Payment__c r02Payment = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 79, Payment_Status__c = 'REJECTED', CreatedDate = DateTime.now()
        );
        r02Payment.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ r02Payment }, new List<SM_Payment__c>());
        Test.stopTest();

        System.assert(report.contains(ct.ContractNumber), 'The report should list the contract with the unresolved R02.');
        System.assert(!report.contains('OJO'), 'No accepted payment since the R02, so no recovery flag should show.');
    }

    @IsTest
    static void flagsContractThatRecoveredAfterR02() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c FROM Contract LIMIT 1];
        SM_Payment__c r02Payment = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 79, Payment_Status__c = 'REJECTED', CreatedDate = DateTime.now().addDays(-10)
        );
        r02Payment.SM_Contract__r = ct;
        SM_Payment__c acceptedAfter = new SM_Payment__c(
            SM_Contract__c = ct.Id, CreatedDate = DateTime.now()
        );

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ r02Payment }, new List<SM_Payment__c>{ acceptedAfter });
        Test.stopTest();

        System.assert(report.contains('OJO'), 'A payment accepted after the R02 should surface the recovery flag.');
    }

    @IsTest
    static void skipsCancelledContracts() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c FROM Contract LIMIT 1];
        ct.Status = 'Cancelled';
        SM_Payment__c r02Payment = new SM_Payment__c(SM_Contract__c = ct.Id, SM_Amount__c = 79, CreatedDate = DateTime.now());
        r02Payment.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ r02Payment }, new List<SM_Payment__c>());
        Test.stopTest();

        System.assert(!report.contains(ct.ContractNumber), 'A Cancelled contract is no longer actionable and should be excluded.');
    }

    @IsTest
    static void sendsEmailWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendR02Report();
        Test.stopTest();
        System.assert(true, 'sendR02Report should run end-to-end (live SOQL) without throwing.');
    }
}
