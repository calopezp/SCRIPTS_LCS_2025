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
            new List<Contract>{ c }, new List<SM_ACH_Order__c>{ order }
        );
        System.assertEquals(0, anomalies.size());
    }

    @isTest
    static void testBuildAnomalies_missingOrder() {
        Id fakeContractId = (Id) '800000000000002';
        Contract c = fakeContract(fakeContractId, '00000002', 100, null);

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(
            new List<Contract>{ c }, new List<SM_ACH_Order__c>()
        );
        System.assert(anomalies.size() > 0);
        System.assert(anomalies[0].contains('REVISAR'));
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

        List<String> anomalies = SM_ACH_Flow_Monitor.buildAnomalies(new List<Contract>{ c }, orders);
        System.assertEquals(2, anomalies.size());
    }
}
