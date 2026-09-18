/**
 * @description Detecta si algun registro de SM_Trigger_Panel__mdt (el gate que usa
 * SM_TriggerHandler.run() para decidir que contextos ejecutar de cada trigger) se desvio del
 * valor esperado documentado en CLAUDE.md seccion 5. No corrige nada - solo avisa por correo,
 * igual que SM_AgreementSignedDateMonitor. Motivo (2026-09-17/18): varios de estos registros
 * apagados a proposito no son obvios a simple vista en el panel de Setup (ej. el registro
 * "SM_ChargentTransactionTGR" en realidad gatea el trigger SM_PaymentTGR por un nombre mal
 * pasado en el trigger - ver BITACORA_HALLAZGOS_TECNICOS.md fila 2026-09-06) - alguien
 * "arreglando" lo que parece un checkbox mal puesto podria resucitar logica legacy que hoy
 * choca con automatizacion nueva (Flow PAYMENT_Accumulate_AC_On_Contract,
 * SM_ACPaymentActivationHandler).
 * @author Carlos Alberto Lopez Prada
 */
public class SM_TriggerPanelMonitor implements Schedulable {

    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';

    // Debe declararse antes de EXPECTED_BASELINE: los inicializadores estaticos de Apex corren
    // en orden de declaracion, y allTrue()/allFalse() (usados abajo) dependen de este campo.
    private static final List<String> FIELDS = new List<String>{
        'SM_ProcessOnAfterDelete__c', 'SM_ProcessOnAfterInsert__c', 'SM_ProcessOnAfterUpdate__c',
        'SM_ProcessOnBeforeDelete__c', 'SM_ProcessOnBeforeInsert__c', 'SM_ProcessOnBeforeUpdate__c',
        'SM_ProcessOnUnDelete__c'
    };

    // Snapshot validado en vivo contra MONEE 2026-09-18. Si se agrega/retira un trigger real del
    // framework SM_TriggerHandler, actualizar este mapa Y CLAUDE.md seccion 5 en el mismo cambio.
    @TestVisible
    private static final Map<String, Map<String, Boolean>> EXPECTED_BASELINE = new Map<String, Map<String, Boolean>>{
        'SM_ACHOrderTrigger' => allTrue(),
        'SM_ACPaymentActivationTrigger' => new Map<String, Boolean>{
            'SM_ProcessOnAfterDelete__c' => false, 'SM_ProcessOnAfterInsert__c' => true,
            'SM_ProcessOnAfterUpdate__c' => true, 'SM_ProcessOnBeforeDelete__c' => false,
            'SM_ProcessOnBeforeInsert__c' => false, 'SM_ProcessOnBeforeUpdate__c' => false,
            'SM_ProcessOnUnDelete__c' => false
        },
        'SM_AgreementTrigger' => allTrue(),
        'SM_AttachmentTrigger' => allTrue(),
        // Gatea el trigger real SM_ChargentOrderTrigger (ChargentOrders__ChargentOrder__c).
        // Todo en false a proposito: la app/licencia Chargent ya no esta activa en MONEE (el
        // objeto existe en el schema pero ya no es consultable via API estandar, confirmado
        // 2026-09-17) - ver CLAUDE.md seccion 3. NO reactivar sin confirmar con Carlos.
        'SM_ChargentOrderTrigger' => allFalse(),
        // OJO: este nombre es enganoso. El trigger real "SM_ChargentTransactionTGR" no usa este
        // registro - lo usa SM_PaymentTGR.trigger, que le pasa este nombre por error a su
        // handler (SM_paymentTGR_Handler). Todo en false a proposito: root cause ya resuelto via
        // el Flow PAYMENT_Accumulate_AC_On_Contract (BITACORA_HALLAZGOS_TECNICOS.md 2026-09-06).
        // NO reactivar sin confirmar con Carlos.
        'SM_ChargentTransactionTGR' => allFalse(),
        'SM_CompanySettingTrigger' => allTrue(),
        'SM_ContactPointAddressTrigger' => allTrue(),
        'SM_ContractTrigger' => allTrue(),
        'SM_DisputeTrigger' => allTrue(),
        'SM_LateFeeReconciliationTrigger' => new Map<String, Boolean>{
            'SM_ProcessOnAfterDelete__c' => false, 'SM_ProcessOnAfterInsert__c' => false,
            'SM_ProcessOnAfterUpdate__c' => true, 'SM_ProcessOnBeforeDelete__c' => false,
            'SM_ProcessOnBeforeInsert__c' => false, 'SM_ProcessOnBeforeUpdate__c' => false,
            'SM_ProcessOnUnDelete__c' => false
        },
        'SM_LeadTrigger' => allTrue(),
        'SM_OpportunityLineTrigger' => allTrue(),
        'SM_OpportunityTrigger' => allTrue(),
        // Registro huerfano: SM_PaymentTGR.trigger no lo consulta (ver nota de
        // SM_ChargentTransactionTGR arriba) - se deja documentado en true tal como esta en vivo,
        // sin efecto real. Si algun dia el trigger se corrige para usar su propio nombre, este
        // baseline pasaria a importar de verdad.
        'SM_PaymentTGR' => allTrue(),
        // El handler activo real de SM_Payment__c (SM_PaymentHandler) - debe quedarse en true.
        'SM_PaymentTrigger' => allTrue(),
        'SM_TaskTrigger' => allTrue(),
        'SM_TrackingInboundTrigger' => allTrue()
    };

    private static Map<String, Boolean> allTrue() {
        Map<String, Boolean> m = new Map<String, Boolean>();
        for (String f : FIELDS) { m.put(f, true); }
        return m;
    }

    private static Map<String, Boolean> allFalse() {
        Map<String, Boolean> m = new Map<String, Boolean>();
        for (String f : FIELDS) { m.put(f, false); }
        return m;
    }

    public void execute(SchedulableContext ctx) {
        runDailyCheck();
    }

    public static void runDailyCheck() {
        sendEmail(checkBaseline());
    }

    @TestVisible
    private static List<String> checkBaseline() {
        return diffAgainstBaseline(
            [SELECT SM_TriggerName__c, SM_ProcessOnAfterDelete__c, SM_ProcessOnAfterInsert__c,
                    SM_ProcessOnAfterUpdate__c, SM_ProcessOnBeforeDelete__c,
                    SM_ProcessOnBeforeInsert__c, SM_ProcessOnBeforeUpdate__c, SM_ProcessOnUnDelete__c
             FROM SM_Trigger_Panel__mdt],
            EXPECTED_BASELINE
        );
    }

    @TestVisible
    private static List<String> diffAgainstBaseline(List<SM_Trigger_Panel__mdt> records, Map<String, Map<String, Boolean>> baseline) {
        List<String> anomalies = new List<String>();
        Set<String> seenTriggerNames = new Set<String>();

        for (SM_Trigger_Panel__mdt panel : records) {
            seenTriggerNames.add(panel.SM_TriggerName__c);
            Map<String, Boolean> expected = baseline.get(panel.SM_TriggerName__c);
            if (expected == null) {
                anomalies.add('Registro nuevo sin baseline documentado: "' + panel.SM_TriggerName__c
                    + '" - agregarlo a SM_TriggerPanelMonitor.EXPECTED_BASELINE y a CLAUDE.md seccion 5.');
                continue;
            }
            for (String field : FIELDS) {
                Boolean actual = (Boolean) panel.get(field);
                Boolean expectedValue = expected.get(field);
                if (actual != expectedValue) {
                    anomalies.add(panel.SM_TriggerName__c + '.' + field + ' = ' + actual
                        + ' (se esperaba ' + expectedValue + ')');
                }
            }
        }

        for (String expectedName : baseline.keySet()) {
            if (!seenTriggerNames.contains(expectedName)) {
                anomalies.add('Registro esperado pero ya no existe: "' + expectedName + '"');
            }
        }

        return anomalies;
    }

    @TestVisible
    private static String buildBody(List<String> anomalies) {
        if (anomalies.isEmpty()) {
            return 'Sin anomalias detectadas. Los ' + EXPECTED_BASELINE.size()
                + ' registros de SM_Trigger_Panel__mdt coinciden con el baseline documentado '
                + 'en CLAUDE.md seccion 5.\n';
        }

        String body = 'ANOMALIAS DETECTADAS (' + anomalies.size() + ') en SM_Trigger_Panel__mdt:\n'
            + 'No se modifico ningun registro, solo diagnostico. Ver CLAUDE.md seccion 5 antes de '
            + 'tocar cualquiera de estos - varios estan apagados a proposito (migracion de '
            + 'Chargent en curso, ver seccion 3).\n\n';

        for (String anomaly : anomalies) {
            body += '- ' + anomaly + '\n';
        }
        return body;
    }

    private static void sendEmail(List<String> anomalies) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject((anomalies.isEmpty() ? '[OK] ' : '[REVISAR] ') + 'Monitoreo Trigger Panel - ' + Date.today().format());
        mail.setPlainTextBody(buildBody(anomalies));
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }
}
