@isTest
private class SM_AgreementSignedDateMonitorTest {

    @isTest
    static void testRunDailyCheckEmptyOrg() {
        Test.startTest();
        SM_AgreementSignedDateMonitor.runDailyCheck();
        Test.stopTest();
    }

    @isTest
    static void testScheduleAndExecute() {
        Test.startTest();
        String jobId = System.schedule('SM_AgreementSignedDateMonitor_Test_Job', '0 0 0 1 1 ? 2040', new SM_AgreementSignedDateMonitor());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testBuildBody_empty() {
        String body = SM_AgreementSignedDateMonitor.buildBody(new List<echosign_dev1__SIGN_Agreement__c>());
        System.assert(body.contains('Sin anomalias'));
    }

    // echosign_dev1__SIGN_Agreement__c es un objeto de paquete gestionado sin metadata local
    // (ver BITACORA_HALLAZGOS_TECNICOS.md); se arma en memoria via JSON.deserialize (mismo
    // truco que SM_ACH_Flow_MonitorTest usa para simular relaciones padre/hijo sin insertar)
    // en vez de insertar un registro real, que requeriria pasar por el wizard de Adobe Sign.
    @isTest
    static void testBuildBody_withOrphan() {
        Map<String, Object> agreementMap = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'echosign_dev1__SIGN_Agreement__c' },
            'Id' => (Id) '801000000000001AAA',
            'Name' => 'LCS-TEST - Cliente de Prueba',
            'CreatedDate' => DateTime.now(),
            'echosign_dev1__DateSent__c' => null,
            'Owner' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'User' },
                'Alias' => 'testuser'
            },
            'echosign_dev1__Contract__r' => new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Contract' },
                'ContractNumber' => '00000001'
            }
        };
        echosign_dev1__SIGN_Agreement__c fakeAgreement =
            (echosign_dev1__SIGN_Agreement__c) JSON.deserialize(JSON.serialize(agreementMap), echosign_dev1__SIGN_Agreement__c.class);

        String body = SM_AgreementSignedDateMonitor.buildBody(new List<echosign_dev1__SIGN_Agreement__c>{ fakeAgreement });
        System.assert(body.contains('ANOMALIAS DETECTADAS (1)'));
        System.assert(body.contains('00000001'));
        System.assert(body.contains('testuser'));
        System.assert(body.contains('nunca'));
    }
}
