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
            SM_Check_Collection_Date__c = Date.newInstance(2026, 8, 13),
            SM_Transmission_Date_ACH_File__c = Date.newInstance(2026, 7, 29),
            SM_Historical_Collection_Status__c = 'PRC_AUT: RETURN //PRC_AUT_15D_SIN_REPORTE: ACCEPTED //'
        );
        reversed.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildTimeoutReversalReport(new List<SM_Payment__c>{ reversed });
        Test.stopTest();

        System.assert(report.contains(ct.ContractNumber), 'The report should list the contract whose timeout-acceptance got reversed.');
        System.assert(report.contains('RETURN'), 'The report should show the current status that contradicted the timeout default.');
        System.assert(report.contains('Transmitido el: 29 jul 2026'), 'The report should show the ACH transmission date as dd mmm yyyy.');
        System.assert(report.contains('cumple 15 dias'), 'The report should extract the timeout-day threshold from the historical tag.');
        // Transmitido 2026-07-29 + 15 dias = 2026-08-13 -> "13 ago 2026"
        System.assert(report.contains('Pago aceptado por dias el 13 ago 2026'), 'The report should compute the accepted-on date from transmission date + threshold days.');
        System.assert(report.contains('Reportado en Collections del: 13 ago 2026'), 'The report date should also use dd mmm yyyy.');
        System.assert(report.contains('R01 (Fondos insuficientes (NSF))'), 'The report should show the return code meaning.');
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

    // calp 2026-09-22 :: compilado semanal para Comercial, agrupado por accion en vez de codigo.
    // calp 2026-09-24 :: cada contrato se clasifica UNA sola vez, por el codigo de su rechazo
    // mas reciente -- por eso esta prueba usa 2 contratos distintos (uno solo-R02, uno solo-R10)
    // en vez de 2 pagos de codigos distintos sobre el MISMO contrato (eso lo cubre la prueba de
    // abajo, weeklyDigestClassifiesContractByMostRecentCode).
    @IsTest
    static void weeklyDigestGroupsNewVsBacklogByAction() {
        Contract ct1 = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c, AccountId, RecordTypeId FROM Contract LIMIT 1];
        Contract ct2 = new Contract(AccountId = ct1.AccountId, RecordTypeId = ct1.RecordTypeId);
        insert ct2;
        ct2 = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract WHERE Id = :ct2.Id];

        SM_Payment__c nuevoR02 = new SM_Payment__c(
            SM_Contract__c = ct1.Id, SM_Amount__c = 75, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R02', CreatedDate = DateTime.now()
        );
        nuevoR02.SM_Contract__r = ct1;

        SM_Payment__c backlogR10 = new SM_Payment__c(
            SM_Contract__c = ct2.Id, SM_Amount__c = 99, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R10', CreatedDate = DateTime.now().addDays(-30)
        );
        backlogR10.SM_Contract__r = ct2;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildWeeklyComercialDigest(
                new List<SM_Payment__c>{ nuevoR02, backlogR10 }, new List<SM_Payment__c>(), Date.today().addDays(-7), true
            );
        Test.stopTest();

        System.assert(report.contains('ACTUALIZAR METODO DE PAGO'), 'R02 should land in the update-payment-method section.');
        System.assert(report.contains('DISPUTA O REVOCACION DEL CLIENTE'), 'R10 should land in the dispute section.');
        System.assert(report.contains('NUEVO ESTA SEMANA'), 'The R02 payment from today should be flagged as new this week.');
        System.assert(report.contains('BACKLOG ACUMULADO (1 contrato(s), sin novedad esta semana):'), 'fullBacklog=true should list the backlog contract itemized.');
        System.assert(report.contains(ct2.ContractNumber), 'fullBacklog=true should list the individual backlog contract, grouped under its cause.');
        System.assert(report.contains('Causa (ultimo rechazo): R02'), 'Each contract line should show its most recent rejection reason.');
        System.assert(report.contains('Causa (ultimo rechazo): R10'), 'Each contract line should show its most recent rejection reason.');
    }

    @IsTest
    static void weeklyDigestClassifiesContractByMostRecentCode() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];

        // Mismo contrato, 2 codigos distintos: un R02 viejo (metodo de pago) y un R10 mas
        // reciente (disputa) -- debe clasificarse UNA sola vez, bajo "disputa" (el mas reciente),
        // nunca bajo "metodo de pago" tambien.
        SM_Payment__c oldR02 = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 75, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R02', CreatedDate = DateTime.now().addDays(-30)
        );
        oldR02.SM_Contract__r = ct;

        SM_Payment__c newerR10 = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 99, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R10', CreatedDate = DateTime.now()
        );
        newerR10.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildWeeklyComercialDigest(
                new List<SM_Payment__c>{ oldR02, newerR10 }, new List<SM_Payment__c>(), Date.today().addDays(-7), true
            );
        Test.stopTest();

        System.assert(report.contains('Causa (ultimo rechazo): R10'), 'The contract should be labeled with its most recent rejection code (R10), not the older R02.');
        System.assert(!report.contains('Causa (ultimo rechazo): R02'), 'The older R02 should not be shown as the reference cause once a more recent R10 exists.');

        // lastIndexOf, no indexOf: ambos titulos aparecen primero en el RESUMEN (una linea por
        // categoria) y de nuevo como encabezado de su seccion detallada -- la seccion real es la
        // segunda aparicion.
        Integer metodoIdx = report.lastIndexOf('ACTUALIZAR METODO DE PAGO');
        Integer disputaIdx = report.lastIndexOf('DISPUTA O REVOCACION DEL CLIENTE');
        String metodoSection = report.substring(metodoIdx, disputaIdx);
        System.assert(metodoSection.contains('Sin contratos pendientes en esta categoria'), 'The contract should NOT be counted under "metodo de pago" once its most recent code is R10.');
        System.assert(!metodoSection.contains(ct.ContractNumber), 'The contract should not be listed under "metodo de pago" at all.');
    }

    @IsTest
    static void weeklyDigestCollapsesBacklogWhenNotFull() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];

        SM_Payment__c backlogR10 = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 99, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R10', CreatedDate = DateTime.now().addDays(-30)
        );
        backlogR10.SM_Contract__r = ct;

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildWeeklyComercialDigest(
                new List<SM_Payment__c>{ backlogR10 }, new List<SM_Payment__c>(), Date.today().addDays(-7), false
            );
        Test.stopTest();

        System.assert(report.contains('BACKLOG ACUMULADO (1 contrato(s), sin novedad esta semana):'), 'fullBacklog=false should still show the backlog header and per-cause summary.');
        System.assert(report.contains('Causa (ultimo rechazo): R10') && report.contains('-- 1 contrato(s), $99'), 'fullBacklog=false should show a one-line summary per cause (count + total).');
        System.assert(!report.contains(ct.ContractNumber), 'fullBacklog=false should not list the individual contract, only the per-cause summary.');
        System.assert(report.contains('(correr el reporte completo para el detalle por contrato de cada causa)'), 'fullBacklog=false should point to the full report for per-contract detail.');
    }

    // calp 2026-09-24 :: un contrato ya resuelto (pago ACCEPTED despues del ultimo return code)
    // ya no se reporta en absoluto -- no hace falta mencionarlo si ya tiene un pago mas reciente
    // (decision explicita del usuario). Antes se listaba bajo "Ya resueltos"; ese bloque se quito.
    @IsTest
    static void weeklyDigestOmitsResolvedContractsEntirely() {
        Contract ct = [SELECT Id, ContractNumber, Status, SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c FROM Contract LIMIT 1];

        SM_Payment__c oldR16 = new SM_Payment__c(
            SM_Contract__c = ct.Id, SM_Amount__c = 139, Payment_Status__c = 'REJECTED',
            SM_Return_code__c = 'R16', CreatedDate = DateTime.now().addDays(-20)
        );
        oldR16.SM_Contract__r = ct;

        SM_Payment__c laterAccepted = new SM_Payment__c(
            SM_Contract__c = ct.Id, CreatedDate = DateTime.now().addDays(-5)
        );

        Test.startTest();
            String report = SM_ReturnCodeNotifier.buildWeeklyComercialDigest(
                new List<SM_Payment__c>{ oldR16 }, new List<SM_Payment__c>{ laterAccepted }, Date.today().addDays(-7), true
            );
        Test.stopTest();

        System.assert(!report.contains('Ya resueltos'), 'The "Ya resueltos" section was removed entirely, per explicit user instruction.');
        System.assert(!report.contains('BACKLOG ACUMULADO'), 'A resolved contract should not appear in the backlog list either.');
        System.assert(!report.contains(ct.ContractNumber), 'A resolved contract should not be mentioned anywhere in the report.');
        System.assert(report.contains('Sin contratos pendientes en esta categoria'), 'With its only contract resolved, "cuenta congelada" should report no pending contracts.');
    }

    @IsTest
    static void sendsWeeklyComercialDigestWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendWeeklyComercialDigest();
        Test.stopTest();
        System.assert(true, 'sendWeeklyComercialDigest should run end-to-end (live SOQL) without throwing.');
    }

    @IsTest
    static void sendsWeeklyComercialDigestReducedWithoutError() {
        Test.startTest();
            SM_ReturnCodeNotifier.sendWeeklyComercialDigest(false);
        Test.stopTest();
        System.assert(true, 'sendWeeklyComercialDigest(false) (recurring/reduced mode) should run end-to-end without throwing.');
    }
}
