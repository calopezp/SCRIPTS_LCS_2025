@IsTest
public class SM_CustomerCancellationActionTest {

    @TestSetup
    static void makeData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = true, SetupOwnerId = UserInfo.getProfileId());

        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        acc.PersonEmail = 'test.cc.action@test.invalid';
        insert acc;

        Contract ct = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 45.68
        );
        insert ct;

        SM_ACH_Order__c ord = SM_TestSmartDataFactory.getACHOrder(ct.Id);
        ord.SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.SUBSCRIPTION;
        ord.SM_Total__c = 100;
        ord.SM_Fee_to_collect__c = 10;
        ord.SM_Penalty_value__c = 5;
        ord.SM_Apply_penalty__c = true;
        ord.SM_Next_Transaction_Date__c = Date.today();
        ord.SM_Payment_Status__c = 'Pending';
        insert ord;

        SM_Payment__c pago = new SM_Payment__c(
            SM_Amount__c = 100,
            SM_Contract__c = ct.Id,
            SM_ACH_Order__c = ord.Id,
            Payment_Status__c = 'ACH PENDING'
        );
        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        insert pago;
        SM_TriggerHandler.avoidAllHandlerExcecution = false;
    }

    @IsTest
    static void testObtenerPreview() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];

        Test.startTest();
        SM_CustomerCancellationActionController.PreviewResult preview = SM_CustomerCancellationActionController.obtenerPreview(ct.Id);
        Test.stopTest();

        System.assertEquals(false, preview.yaMarcado, 'El contrato no deberia estar marcado todavia');
        System.assertEquals(1, preview.cantidadOrdenes, 'Deberia haber 1 ACH Order elegible');
        System.assertEquals(1, preview.cantidadPayments, 'Deberia haber 1 payment en ACH PENDING');
        System.assertEquals(true, preview.esAdministrador, 'El usuario que corre el test deberia ser System Administrator');
        System.assertEquals(1, preview.ordenes.size(), 'El detalle deberia traer 1 registro');
        System.assertEquals('Pending', preview.ordenes[0].estatusAnterior, 'El estatus anterior deberia ser Pending');

        Contract ctDespues = [SELECT SM_Customer_Cancellation__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(false, ctDespues.SM_Customer_Cancellation__c, 'El preview no debe modificar el contrato');
    }

    @IsTest
    static void testMarcarCustomerCancellation() {
        Contract ct = [SELECT Id FROM Contract LIMIT 1];
        SM_ACH_Order__c ord = [SELECT Id FROM SM_ACH_Order__c LIMIT 1];

        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        Test.startTest();
        SM_CustomerCancellationActionController.ResultadoAccion resultado = SM_CustomerCancellationActionController.marcarCustomerCancellation(ct.Id);
        Test.stopTest();
        SM_TriggerHandler.avoidAllHandlerExcecution = false;

        System.assertEquals(true, resultado.success, 'La accion deberia ser exitosa');
        System.assertEquals(1, resultado.ordenesActualizadas, 'Deberia actualizar 1 ACH Order');
        System.assertEquals(1, resultado.paymentsEliminados, 'Deberia eliminar 1 payment (usuario System Administrator)');
        System.assertEquals(0, resultado.paymentsPendientesDeRevision, 'No deberian quedar payments pendientes de revision para un administrador');

        Contract ctDespues = [SELECT SM_Customer_Cancellation__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(true, ctDespues.SM_Customer_Cancellation__c, 'El contrato deberia quedar marcado');

        SM_ACH_Order__c ordDespues = [SELECT SM_Payment_Status__c FROM SM_ACH_Order__c WHERE Id = :ord.Id];
        System.assertEquals('Stopped', ordDespues.SM_Payment_Status__c, 'La orden deberia quedar Stopped');

        Integer paymentsRestantes = [SELECT COUNT() FROM SM_Payment__c WHERE SM_ACH_Order__c = :ord.Id AND Payment_Status__c = 'ACH PENDING'];
        System.assertEquals(0, paymentsRestantes, 'No deberian quedar payments en ACH PENDING');
    }

    @IsTest
    static void testMarcarCustomerCancellationSinOrdenesElegibles() {
        Account acc = SM_TestSmartDataFactory.getPersonAccount();
        acc.PersonEmail = 'test.cc.action.sinordenes@test.invalid';
        insert acc;

        Contract ct = new Contract(
            AccountId = acc.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 10
        );
        insert ct;

        Test.startTest();
        SM_CustomerCancellationActionController.ResultadoAccion resultado = SM_CustomerCancellationActionController.marcarCustomerCancellation(ct.Id);
        Test.stopTest();

        System.assertEquals(true, resultado.success, 'Deberia poder marcar el contrato aunque no tenga ordenes elegibles');
        System.assertEquals(0, resultado.ordenesActualizadas, 'No deberia haber ordenes para actualizar');
        System.assertEquals(0, resultado.paymentsEliminados, 'No deberia haber payments para eliminar');

        Contract ctDespues = [SELECT SM_Customer_Cancellation__c FROM Contract WHERE Id = :ct.Id];
        System.assertEquals(true, ctDespues.SM_Customer_Cancellation__c, 'El contrato deberia quedar marcado igual');
    }
}
