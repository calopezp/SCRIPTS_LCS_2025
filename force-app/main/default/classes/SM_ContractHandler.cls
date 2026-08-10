public without sharing class SM_ContractHandler extends SM_TriggerHandler {

    public SM_ContractHandler(String triggerName) {
        super(triggerName);
    }

    public override void beforeUpdate() {}
    public override void afterUpdate() {}
    public override void asyncAfterInsert() {}
    public override void asyncAfterUpdate() {}

    public void processChangesToSendContract(List<Contract> newContracts, Map<Id,SObject> oldContractsMap) {}

    public static void updateChargentValue(Map<Id,SObject> contracts, Map<Id,SObject> oldContracts) {}
    public static void findPaymentCondition(Map<Id,SObject> newContractsMap, Map<Id,SObject> oldContractsMap) {}
    public static void updateStageOpportunity(List<Contract> newContracts, Map<Id,SObject> oldContractsMap) {}
    public static void validateRequiredFieldsByProcess(Map<Id,SObject> newContractsMap, Map<Id,SObject> oldContractsMap) {}
    public static void processAssetsByContractStatusChange(List<Contract> newContracts, Map<Id,SObject> oldContractsMap) {}
    public static void checkContractFutureActivationType(List<Contract> newRecords, Map<Id,SObject> oldRecordsMap) {}
    public static void updateContractFutureActivation(List<Contract> newRecords, Map<Id,SObject> oldRecordsMap) {}
    public static void checkUpdateMasterStatus(List<Contract> newRecords, Map<Id,SObject> oldRecordsMap) {}
    public static void processRecordsToCancelUpgradedContracts(List<Contract> newRecords, Map<Id,SObject> oldRecordsMap) {}
    public static void testGarbage() {}
}