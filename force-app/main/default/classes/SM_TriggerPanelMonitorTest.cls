@isTest
private class SM_TriggerPanelMonitorTest {

    @isTest
    static void testRunDailyCheckAgainstRealOrgMetadata() {
        // SM_Trigger_Panel__mdt es Custom Metadata - no es aislado por test (igual que
        // SM_TestSmartDataFactory consulta Profile real). Solo valida que corra sin excepcion;
        // el contenido real se valida por separado corriendo el chequeo manualmente tras deploy.
        Test.startTest();
        SM_TriggerPanelMonitor.runDailyCheck();
        Test.stopTest();
    }

    @isTest
    static void testScheduleAndExecute() {
        Test.startTest();
        String jobId = System.schedule('SM_TriggerPanelMonitor_Test_Job', '0 0 0 1 1 ? 2040', new SM_TriggerPanelMonitor());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testBuildBody_empty() {
        String body = SM_TriggerPanelMonitor.buildBody(new List<String>());
        System.assert(body.contains('Sin anomalias'));
    }

    @isTest
    static void testBuildBody_withAnomalies() {
        List<String> anomalies = new List<String>{
            'SM_ChargentOrderTrigger.SM_ProcessOnAfterInsert__c = true (se esperaba false)'
        };
        String body = SM_TriggerPanelMonitor.buildBody(anomalies);
        System.assert(body.contains('ANOMALIAS DETECTADAS (1)'));
        System.assert(body.contains('SM_ChargentOrderTrigger'));
    }

    // Custom Metadata no se puede insertar/borrar en un test, asi que se arma en memoria via
    // JSON.deserialize (mismo truco que SM_AgreementSignedDateMonitorTest usa para objetos que
    // no se pueden crear normalmente en un test) para probar diffAgainstBaseline con un baseline
    // sintetico controlado, sin depender de los valores reales en vivo.
    private static SM_Trigger_Panel__mdt fakePanel(String triggerName, Boolean value) {
        Map<String, Object> panelMap = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'SM_Trigger_Panel__mdt' },
            'SM_TriggerName__c' => triggerName,
            'SM_ProcessOnAfterDelete__c' => value,
            'SM_ProcessOnAfterInsert__c' => value,
            'SM_ProcessOnAfterUpdate__c' => value,
            'SM_ProcessOnBeforeDelete__c' => value,
            'SM_ProcessOnBeforeInsert__c' => value,
            'SM_ProcessOnBeforeUpdate__c' => value,
            'SM_ProcessOnUnDelete__c' => value
        };
        return (SM_Trigger_Panel__mdt) JSON.deserialize(JSON.serialize(panelMap), SM_Trigger_Panel__mdt.class);
    }

    @isTest
    static void testDiffAgainstBaseline_matchesExpected() {
        List<SM_Trigger_Panel__mdt> records = new List<SM_Trigger_Panel__mdt>{ fakePanel('Fake_Trigger', false) };
        Map<String, Map<String, Boolean>> baseline = new Map<String, Map<String, Boolean>>{
            'Fake_Trigger' => new Map<String, Boolean>{
                'SM_ProcessOnAfterDelete__c' => false, 'SM_ProcessOnAfterInsert__c' => false,
                'SM_ProcessOnAfterUpdate__c' => false, 'SM_ProcessOnBeforeDelete__c' => false,
                'SM_ProcessOnBeforeInsert__c' => false, 'SM_ProcessOnBeforeUpdate__c' => false,
                'SM_ProcessOnUnDelete__c' => false
            }
        };
        List<String> anomalies = SM_TriggerPanelMonitor.diffAgainstBaseline(records, baseline);
        System.assert(anomalies.isEmpty(), 'No deberia haber anomalias cuando el registro coincide con el baseline');
    }

    @isTest
    static void testDiffAgainstBaseline_flagsDrift() {
        List<SM_Trigger_Panel__mdt> records = new List<SM_Trigger_Panel__mdt>{ fakePanel('Fake_Chargent_Trigger', true) };
        Map<String, Map<String, Boolean>> baseline = new Map<String, Map<String, Boolean>>{
            'Fake_Chargent_Trigger' => new Map<String, Boolean>{
                'SM_ProcessOnAfterDelete__c' => false, 'SM_ProcessOnAfterInsert__c' => false,
                'SM_ProcessOnAfterUpdate__c' => false, 'SM_ProcessOnBeforeDelete__c' => false,
                'SM_ProcessOnBeforeInsert__c' => false, 'SM_ProcessOnBeforeUpdate__c' => false,
                'SM_ProcessOnUnDelete__c' => false
            }
        };
        List<String> anomalies = SM_TriggerPanelMonitor.diffAgainstBaseline(records, baseline);
        System.assertEquals(7, anomalies.size(), 'Los 7 campos en true deberian marcarse como anomalia contra un baseline todo en false');
    }

    @isTest
    static void testDiffAgainstBaseline_flagsUnknownRecord() {
        List<SM_Trigger_Panel__mdt> records = new List<SM_Trigger_Panel__mdt>{ fakePanel('Trigger_Sin_Baseline', true) };
        List<String> anomalies = SM_TriggerPanelMonitor.diffAgainstBaseline(records, new Map<String, Map<String, Boolean>>());
        System.assertEquals(1, anomalies.size());
        System.assert(anomalies[0].contains('sin baseline documentado'));
    }

    @isTest
    static void testDiffAgainstBaseline_flagsMissingRecord() {
        Map<String, Map<String, Boolean>> baseline = new Map<String, Map<String, Boolean>>{
            'Trigger_Que_Ya_No_Existe' => new Map<String, Boolean>{
                'SM_ProcessOnAfterDelete__c' => false, 'SM_ProcessOnAfterInsert__c' => false,
                'SM_ProcessOnAfterUpdate__c' => false, 'SM_ProcessOnBeforeDelete__c' => false,
                'SM_ProcessOnBeforeInsert__c' => false, 'SM_ProcessOnBeforeUpdate__c' => false,
                'SM_ProcessOnUnDelete__c' => false
            }
        };
        List<String> anomalies = SM_TriggerPanelMonitor.diffAgainstBaseline(new List<SM_Trigger_Panel__mdt>(), baseline);
        System.assertEquals(1, anomalies.size());
        System.assert(anomalies[0].contains('ya no existe'));
    }
}
