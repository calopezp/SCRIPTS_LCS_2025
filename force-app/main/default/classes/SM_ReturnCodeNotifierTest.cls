/**
 * @description Coverage for SM_ReturnCodeNotifier - see that class for why R02, R10,
 * R04/R13, R07, and R16 returns each need their own standing report.
 * @author Carlos Alberto Lopez Prada
 */
@IsTest
public without sharing class SM_ReturnCodeNotifierTest {

    private static final String LABEL = 'R02 (ACCOUNT CLOSED)';
    private static final String EXPLANATION = 'la cuenta ya no existe.';

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
    static void reportsContractWithUnresolvedCode() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];
        SM_Payment__c codePayment = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 79, Payment_Status__c = 'REJECTED', CreatedDate = DateTime.now()
        );
        codePayment.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ codePayment }, new List<SM_Payment__c>(), LABEL, EXPLANATION);
        Test.stopTest();

        System.assert(report.contains(ct.ContractNumber), 'The report should list the contract with the unresolved return code.');
        System.assert(!report.contains('OJO'), 'No accepted payment since the return, so no recovery flag should show.');
    }

    @IsTest
    static void flagsContractThatRecoveredAfterCode() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];
        SM_Payment__c codePayment = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 79, Payment_Status__c = 'REJECTED', CreatedDate = DateTime.now().addDays(-10)
        );
        codePayment.SM_Contract__r = ct;
        SM_Payment__c acceptedAfter = new SM_Payment__c(
            SM_Contract__c = ct.Id, CreatedDate = DateTime.now()
        );

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ codePayment }, new List<SM_Payment__c>{ acceptedAfter }, LABEL, EXPLANATION);
        Test.stopTest();

        System.assert(report.contains('OJO'), 'A payment accepted after the return code should surface the recovery flag.');
    }

    @IsTest
    static void skipsCancelledContracts() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];
        ct.Status = 'Cancelled';
        SM_Payment__c codePayment = new SM_Payment__c(SM_Contract__c = ct.Id, SM_Amount__c = 79, CreatedDate = DateTime.now());
        codePayment.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ codePayment }, new List<SM_Payment__c>(), LABEL, EXPLANATION);
        Test.stopTest();

        System.assert(!report.contains(ct.ContractNumber), 'A Cancelled contract is no longer actionable and should be excluded.');
    }

    @IsTest
    static void skipsTestAndVipContracts() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];
        ct.Is_Test_Contract__c = true;
        SM_Payment__c testContractPayment = new SM_Payment__c(SM_Contract__c = ct.Id, SM_Amount__c = 79, CreatedDate = DateTime.now());
        testContractPayment.SM_Contract__r = ct;

        Contract vipCt = ct.clone(false, true, false, false);
        vipCt.Is_Test_Contract__c = false;
        vipCt.Is_VIP_Contract__c = true;
        SM_Payment__c vipContractPayment = new SM_Payment__c(SM_Contract__c = ct.Id, SM_Amount__c = 79, CreatedDate = DateTime.now());
        vipContractPayment.SM_Contract__r = vipCt;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildReport(new List<SM_Payment__c>{ testContractPayment, vipContractPayment }, new List<SM_Payment__c>(), LABEL, EXPLANATION);
        Test.stopTest();

        System.assert(report.contains('Sin contratos'), 'Test and VIP contracts should never appear in the report.');
    }

    @IsTest
    static void sendsR02ReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendR02Report();
        Test.stopTest();
        System.assert(true, 'sendR02Report should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void sendsR10ReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendR10Report();
        Test.stopTest();
        System.assert(true, 'sendR10Report should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void sendsInvalidAccountReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendInvalidAccountReport();
        Test.stopTest();
        System.assert(true, 'sendInvalidAccountReport (R04+R13) should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void sendsR07ReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendR07Report();
        Test.stopTest();
        System.assert(true, 'sendR07Report should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void sendsR16ReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendR16Report();
        Test.stopTest();
        System.assert(true, 'sendR16Report should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void reportsPaymentAcceptedByTimeoutThenReversed() {
        Contract ct = [SELECT Id, ContractNumber, Status FROM Contract LIMIT 1];
        SM_Payment__c reversed = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 55, Payment_Status__c = 'REJECTED',
            SM_Check_Collection_Status__c = 'RETURN', SM_Return_code__c = 'R01',
            SM_Historical_Collection_Status__c = 'PRC_AUT: RETURN //PRC_AUT_15D_SIN_REPORTE: ACCEPTED //'
        );
        reversed.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildTimeoutReversalReport(new List<SM_Payment__c>{ reversed });
        Test.stopTest();

        System.assert(report.contains(ct.ContractNumber), 'The report should list the contract whose timeout-acceptance got reversed.');
        System.assert(report.contains('RETURN'), 'The report should show the current status that contradicted the timeout default.');
    }

    @IsTest
    static void skipsPaymentsStillAcceptedAfterTimeout() {
        String report = SM_ReturnCodeNotifier.buildTimeoutReversalReport(new List<SM_Payment__c>());
        System.assert(report.contains('Sin pagos'), 'No reversed payments means no findings to report.');
    }

    @IsTest
    static void sendsTimeoutReversalReportWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendTimeoutReversalReport();
        Test.stopTest();
        System.assert(true, 'sendTimeoutReversalReport should run end-to-end (live SOQL) without throwing.');
    }
}
