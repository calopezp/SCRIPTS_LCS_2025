public class SM_ACH_Flow_Monitor implements Schedulable {

    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';

    public void execute(SchedulableContext ctx) {
        runDailyCheck();
    }

    public static void runDailyCheck() {
        DateTime since = DateTime.now().addHours(-24);

        // calp 2026-09-12 :: contratos que se activaron en las ultimas 24h, sin importar el
        // medio de pago (ACH, ChargeBee, Credit Card, Cash) - todas las rutas de activacion
        // de este org (SM_paymentTGR_Handler, SM_chargentOrTr_Handler, SM_ACPaymentActivationHandler,
        // PAYMENT_Accumulate_AC_On_Contract) ponen StartDate = hoy exactamente cuando activan,
        // asi que es la senal mas confiable de "se activo hoy" sin depender de field history.
        List<Contract> activatedToday = [
            SELECT Id, ContractNumber, Status, SM_Payment_methods__c, CB_Subscription__c,
                   SM_AC_collected__c, SM_Net_AC__c, SM_Net_Monthly_offer__c, StartDate,
                   (SELECT Id, SM_Payment_Type__c FROM ACH_Orders__r WHERE SM_Payment_Type__c = 'Subscription')
            FROM Contract
            WHERE Status = 'Activated' AND StartDate = TODAY
        ];

        // calp 2026-09-21 :: el requerimiento real es "contratos CREADOS en las ultimas 24h", no
        // "tocados" -- con LastModifiedDate cualquier proceso ajeno (un backfill, una automatizacion
        // de otro tipo) que rozara un contrato viejo lo metia al chequeo sin que fuera relevante
        // para validar la creacion de ordenes de contratos nuevos.
        List<Contract> recentContracts = [
            SELECT Id, ContractNumber, Status, SM_Requires_AC_Payment__c, SM_Requires_RC_Payment__c,
                   SM_AC_collected__c, SM_Payment_methods__c, CB_Subscription__c,
                   Is_Test_Contract__c, Is_VIP_Contract__c, SM_Customer_Cancellation__c,
                   Contract_Type__c, SM_Full_Payment__c, SM_Total_ac__c, SM_AC_start_date__c,
                   SM_AC_Split_Date__c
            FROM Contract
            WHERE SM_Payment_methods__c = 'ACH'
              AND Status IN ('Payment Process', 'Activated')
              AND CreatedDate >= :since
        ];

        Set<Id> contractIds = new Set<Id>();
        for (Contract c : recentContracts) {
            contractIds.add(c.Id);
        }

        Integer newOrdersCount = [
            SELECT COUNT() FROM SM_ACH_Order__c WHERE CreatedDate >= :since
        ];

        List<SM_ACH_Order__c> activeOrders = contractIds.isEmpty() ? new List<SM_ACH_Order__c>() : [
            SELECT Id, SM_Contract__c, SM_Payment_Type__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c IN :contractIds
            AND SM_Payment_Status__c NOT IN ('Completed', 'Canceled')
        ];

        // calp 2026-09-21 :: 'Completed' es el estado final EXITOSO de una orden AC (el AC ya se
        // cobro) -- no debe contar como "orden faltante" solo porque activeOrders la excluye a
        // proposito (esa exclusion es correcta para el chequeo de duplicados, no para este). Sin
        // esto, cualquier contrato con el AC ya cobrado y cerrado aparecia como falso positivo
        // "elegible pero sin orden activa" -- 136 de 140 anomalias del correo del 2026-09-21 eran
        // justo esto, 132 de ellas con SM_AC_collected__c=true confirmando que si se habia cobrado.
        Set<Id> contractsWithAnyAcOrder = new Set<Id>();
        if (!contractIds.isEmpty()) {
            for (SM_ACH_Order__c o : [
                    SELECT SM_Contract__c FROM SM_ACH_Order__c
                    WHERE SM_Contract__c IN :contractIds AND SM_Payment_Type__c = 'AC'
            ]) {
                contractsWithAnyAcOrder.add(o.SM_Contract__c);
            }
        }

        List<String> anomalies = buildAnomalies(recentContracts, activeOrders, contractsWithAnyAcOrder);
        // Un contrato ACH activado sin su Subscription Order es la misma clase de bug que se
        // corrigio 2026-09-12 (CONTRACT_Create_ACH_Subscription_Order) - si vuelve a pasar,
        // que se vea como anomalia y dispare el [REVISAR] del asunto, no que se pierda en la lista.
        for (Contract c : activatedToday) {
            if (c.SM_Payment_methods__c == 'ACH' && c.ACH_Orders__r.isEmpty()) {
                anomalies.add('ALERTA: Contrato ' + c.ContractNumber + ' se activo por ACH pero no tiene Subscription Order');
            }
        }

        sendEmail(recentContracts.size(), newOrdersCount, anomalies, activatedToday);
    }

    /**
     * Logica pura de deteccion de anomalias, separada de las queries para poder
     * probarla con datos en memoria sin necesidad de insertar SM_ACH_Order__c real
     * (el insert dispara SM_ACHOrderHandler, que en contexto de test choca con un
     * bug preexistente y no relacionado en SM_BypassManager/SM_Bypasser__c).
     */
    public static List<String> buildAnomalies(List<Contract> recentContracts, List<SM_ACH_Order__c> activeOrders, Set<Id> contractsWithAnyAcOrder) {
        Map<Id, Integer> acCountByContract = new Map<Id, Integer>();
        Map<Id, Integer> subCountByContract = new Map<Id, Integer>();
        for (SM_ACH_Order__c o : activeOrders) {
            if (o.SM_Payment_Type__c == 'AC') {
                acCountByContract.put(o.SM_Contract__c, (acCountByContract.containsKey(o.SM_Contract__c) ? acCountByContract.get(o.SM_Contract__c) : 0) + 1);
            } else if (o.SM_Payment_Type__c == 'Subscription') {
                subCountByContract.put(o.SM_Contract__c, (subCountByContract.containsKey(o.SM_Contract__c) ? subCountByContract.get(o.SM_Contract__c) : 0) + 1);
            }
        }

        List<String> anomalies = new List<String>();

        for (Id cId : subCountByContract.keySet()) {
            if (subCountByContract.get(cId) > 1) {
                anomalies.add('Contrato ' + cId + ': ' + subCountByContract.get(cId) + ' ordenes Subscription activas (esperado max 1)');
            }
        }

        for (Contract c : recentContracts) {
            Boolean expectedSplit = c.SM_AC_Split_Date__c != null;
            Integer expectedMax = expectedSplit ? 2 : 1;
            Integer acCount = acCountByContract.containsKey(c.Id) ? acCountByContract.get(c.Id) : 0;
            if (c.SM_Requires_AC_Payment__c == true && acCount > expectedMax) {
                anomalies.add('Contrato ' + c.ContractNumber + ': ' + acCount + ' ordenes AC activas (esperado max ' + expectedMax + ')');
            }

            Boolean eligibleForAC = c.SM_Requires_AC_Payment__c == true
                && c.Is_Test_Contract__c == false && c.Is_VIP_Contract__c == false
                && c.SM_Customer_Cancellation__c == false && c.SM_Full_Payment__c == false
                && c.Contract_Type__c != 'Dependent' && c.CB_Subscription__c == null
                && c.SM_Total_ac__c != null && c.SM_AC_start_date__c != null;
            if (eligibleForAC && acCount == 0 && !contractsWithAnyAcOrder.contains(c.Id)) {
                anomalies.add('REVISAR: Contrato ' + c.ContractNumber + ' (' + c.Id + ') parece elegible para orden AC pero no tiene ninguna activa');
            }
        }

        return anomalies;
    }

    /**
     * @description Seccion "contratos activados hoy" - cualquier medio de pago (ACH, ChargeBee,
     * Credit Card, Cash). Separada para poder probarla con datos en memoria.
     */
    public static String buildActivatedContractsSection(List<Contract> activatedToday) {
        if (activatedToday.isEmpty()) {
            return 'Contratos activados hoy (cualquier medio de pago): ninguno.\n';
        }
        String section = 'Contratos activados hoy (' + activatedToday.size() + '), cualquier medio de pago:\n';
        for (Contract c : activatedToday) {
            Decimal amount = c.SM_Net_AC__c != null ? c.SM_Net_AC__c : c.SM_Net_Monthly_offer__c;
            String subscriptionNote;
            if (c.SM_Payment_methods__c == 'ACH') {
                subscriptionNote = c.ACH_Orders__r.isEmpty() ? ' - SIN Subscription Order (ver anomalias)' : ' - Subscription Order OK';
            } else if (c.CB_Subscription__c != null) {
                subscriptionNote = ' - Subscription ChargeBee OK';
            } else {
                subscriptionNote = '';
            }
            section += '- ' + c.ContractNumber + ' (' + c.SM_Payment_methods__c + ', AC ' + (amount != null ? amount.format() : '?') + ')' + subscriptionNote + '\n';
        }
        return section;
    }

    private static void sendEmail(Integer contractCount, Integer orderCount, List<String> anomalies, List<Contract> activatedToday) {
        String body = buildActivatedContractsSection(activatedToday) + '\n'
            + 'Monitoreo diario - Automatizacion ACH Orders (CONTRACT_10_After_Save_Orchestrator, '
            + 'CONTRACT_Create_ACH_AC_Order, CONTRACT_Create_ACH_Subscription_Order)\n\n'
            + 'Contratos ACH en Payment Process/Activated tocados en las ultimas 24h: ' + contractCount + '\n'
            + 'SM_ACH_Order__c nuevas en las ultimas 24h: ' + orderCount + '\n\n';

        if (anomalies.isEmpty()) {
            body += 'Sin anomalias detectadas.\n';
        } else {
            body += 'ANOMALIAS DETECTADAS (' + anomalies.size() + '):\n';
            for (String a : anomalies) {
                body += '- ' + a + '\n';
            }
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject((anomalies.isEmpty() ? '[OK] ' : '[REVISAR] ') + 'Monitoreo Contratos Activados - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }
}
