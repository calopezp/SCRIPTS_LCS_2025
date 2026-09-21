@isTest
private class SM_ACH_Flow_MonitorTest {

    // ContractNumber (auto-number) y SM_Net_AC__c (formula) no son escribibles via
    // constructor; se usan con put() para poder simular su valor en objetos en
    // memoria (sin insertar) que alimentan buildAnomalies().
    private static Contract fakeContract(Id contractId, String contractNum, Decimal totalAc, Date splitDate) {
        return new Contract(
            Id = contractId,
            SM_Requires_AC_Payment__c = true,
            Is_Test_Contract__c = false,
            Is_VIP_Contract__c = false,
            SM_Customer_Cancellation__c = false,
            SM_Full_Payment__c = false,
            Contract_Type__c = 'Master',
            SM_AC_start_date__c = Date.today(),
            SM_AC_Split_Date__c = splitDate,
            SM_Total_ac__c = totalAc
        );
    }

    @isTest
    static void testRunDailyCheckEmptyOrg() {
        Test.startTest();
        SM_ACH_Flow_Monitor.runDailyCheck();
        Test.stopTest();
    }

    @isTest
    static void testScheduleAndExecute() {
        Test.startTest();
        String jobId = System.schedule('SM_ACH_Flow_Monitor_Test_Job', '0 0 0 1 1 ? 2040', new SM_ACH_Flow_Monitor());
        Test.stopTest();
        System.assertNotEquals(null, jobId);
    }

    @isTest
    static void testBuildAnomalies_noIssues() {
        Id fakeContractId = (Id) '800000000000001';
        Contract c = fakeContract(fakeContractId, '00000001', 100, null);
        SM_ACH_Order__c order = new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'AC');

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(
            new List<Contract>{ c }, new List<SM_ACH_Order__c>{ order }, new Set<Id>()
        );
        System.assertEquals(0, anomalies.size());
    }

    @isTest
    static void testBuildAnomalies_missingOrder() {
        Id fakeContractId = (Id) '800000000000002';
        Contract c = fakeContract(fakeContractId, '00000002', 100, null);

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(
            new List<Contract>{ c }, new List<SM_ACH_Order__c>(), new Set<Id>()
        );
        System.assert(anomalies.size() > 0);
        System.assert(anomalies[0].contains('REVISAR'));
    }

    // calp 2026-09-21 :: reproduce el falso positivo real del correo del 2026-09-21 -- un
    // contrato cuya orden AC ya esta 'Completed' (por eso no aparece en activeOrders, que
    // excluye Completed/Canceled a proposito) NO debe reportarse como "sin orden".
    @isTest
    static void testBuildAnomalies_completedOrderNotFalsePositive() {
        Id fakeContractId = (Id) '800000000000007';
        Contract c = fakeContract(fakeContractId, '00000007', 100, null);

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(
            new List<Contract>{ c }, new List<SM_ACH_Order__c>(), new Set<Id>{ fakeContractId }
        );
        System.assertEquals(0, anomalies.size());
    }

    // Truco estandar de Apex para poblar una subquery (relacion hija, ej. ACH_Orders__r) en un
    // SObject en memoria sin insertar/consultar - putSObject solo sirve para relaciones padre
    // (un solo registro), no para listas.
    private static Contract fakeContractWithAchOrders(Id contractId, String paymentMethod, List<SM_ACH_Order__c> achOrders) {
        Map<String, Object> contractMap = new Map<String, Object>{
            'Id' => contractId,
            'SM_Payment_methods__c' => paymentMethod,
            'ACH_Orders__r' => new Map<String, Object>{
                'totalSize' => achOrders.size(),
                'done' => true,
                'records' => achOrders
            }
        };
        return (Contract) JSON.deserialize(JSON.serialize(contractMap), Contract.class);
    }

    @isTest
    static void testBuildActivatedContractsSection_empty() {
        String section = SM_ACH_Flow_Monitor.buildActivatedContractsSection(new List<Contract>());
        System.assert(section.contains('ninguno'));
    }

    @isTest
    static void testBuildActivatedContractsSection_achWithSubscription() {
        Id fakeContractId = (Id) '800000000000004';
        Contract c = fakeContractWithAchOrders(fakeContractId, 'ACH', new List<SM_ACH_Order__c>{
            new SM_ACH_Order__c(SM_Payment_Type__c = 'Subscription')
        });

        String section = SM_ACH_Flow_Monitor.buildActivatedContractsSection(new List<Contract>{ c });
        System.assert(section.contains('Subscription Order OK'));
    }

    @isTest
    static void testBuildActivatedContractsSection_achMissingSubscription() {
        Id fakeContractId = (Id) '800000000000005';
        Contract c = fakeContractWithAchOrders(fakeContractId, 'ACH', new List<SM_ACH_Order__c>());

        String section = SM_ACH_Flow_Monitor.buildActivatedContractsSection(new List<Contract>{ c });
        System.assert(section.contains('SIN Subscription Order'));
    }

    @isTest
    static void testBuildActivatedContractsSection_chargebee() {
        Id fakeContractId = (Id) '800000000000006';
        Contract c = new Contract(
            Id = fakeContractId,
            SM_Payment_methods__c = 'Credit Card',
            CB_Subscription__c = 'a5Q000000000001'
        );

        String section = SM_ACH_Flow_Monitor.buildActivatedContractsSection(new List<Contract>{ c });
        System.assert(section.contains('Subscription ChargeBee OK'));
    }

    @isTest
    static void testBuildAnomalies_duplicates() {
        Id fakeContractId = (Id) '800000000000003';
        Contract c = fakeContract(fakeContractId, '00000003', 100, Date.today().addDays(15));
        List<SM_ACH_Order__c> orders = new List<SM_ACH_Order__c>{
            new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'AC'),
            new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'AC'),
            new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'AC'),
            new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'Subscription'),
            new SM_ACH_Order__c(SM_Contract__c = fakeContractId, SM_Payment_Type__c = 'Subscription')
        };

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(new List<Contract>{ c }, orders, new Set<Id>());
        System.assertEquals(2, anomalies.size());
    }
}
