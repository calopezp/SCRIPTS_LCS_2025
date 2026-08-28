public class SM_ACH_Flow_Monitor implements Schedulable {

    public static final Date END_DATE = Date.newInstance(2026, 9, 2);
    public static final String NOTIFY_EMAIL = 'clopez@legal-credit.com';

    public void execute(SchedulableContext ctx) {
        runDailyCheck();
        if (Date.today() >= END_DATE) {
            System.abortJob(ctx.getTriggerId());
        }
    }

    public static void runDailyCheck() {
        DateTime since = DateTime.now().addHours(-24);

        List<Contract> recentContracts = [
            SELECT Id, ContractNumber, Status, SM_Requires_AC_Payment__c, SM_Requires_RC_Payment__c,
                   SM_AC_collected__c, SM_Payment_methods__c, CB_Subscription__c,
                   Is_Test_Contract__c, Is_VIP_Contract__c, SM_Customer_Cancellation__c,
                   Contract_Type__c, SM_Full_Payment__c, SM_Total_ac__c, SM_AC_start_date__c,
                   SM_AC_Split_Date__c
            FROM Contract
            WHERE SM_Payment_methods__c = 'ACH'
              AND Status IN ('Payment Process', 'Activated')
              AND (LastModifiedDate >= :since OR CreatedDate >= :since)
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

        List<String> anomalies = buildAnomalies(recentContracts, activeOrders);

        sendEmail(recentContracts.size(), newOrdersCount, anomalies);
    }

    /**
     * Logica pura de deteccion de anomalias, separada de las queries para poder
     * probarla con datos en memoria sin necesidad de insertar SM_ACH_Order__c real
     * (el insert dispara SM_ACHOrderHandler, que en contexto de test choca con un
     * bug preexistente y no relacionado en SM_BypassManager/SM_Bypasser__c).
     */
    public static List<String> buildAnomalies(List<Contract> recentContracts, List<SM_ACH_Order__c> activeOrders) {
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
            if (eligibleForAC && acCount == 0) {
                anomalies.add('REVISAR: Contrato ' + c.ContractNumber + ' (' + c.Id + ') parece elegible para orden AC pero no tiene ninguna activa');
            }
        }

        return anomalies;
    }

    private static void sendEmail(Integer contractCount, Integer orderCount, List<String> anomalies) {
        String body = 'Monitoreo diario - Automatizacion ACH Orders (CONTRACT_10_After_Save_Orchestrator, '
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
        body += '\nMonitoreo automatico activo hasta ' + END_DATE.format() + '.';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{ NOTIFY_EMAIL });
        mail.setSubject((anomalies.isEmpty() ? '[OK] ' : '[REVISAR] ') + 'Monitoreo ACH Orders - ' + Date.today().format());
        mail.setPlainTextBody(body);
        if (!Test.isRunningTest()) {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        }
    }
}
