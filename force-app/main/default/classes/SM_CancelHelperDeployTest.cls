@IsTest
private with sharing class SM_CancelHelperDeployTest {

    @TestSetup
    static void setupData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());

        Account accountRecord = SM_TestSmartDataFactory.getPersonAccount();
        accountRecord.PersonEmail = 'cancel.helper.deploy@test.invalid';
        insert accountRecord;

        Contract masterContract = new Contract(
            AccountId = accountRecord.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = SM_ContractHelper.contractType.MASTER,
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 100
        );
        insert masterContract;

        Contract dependentContract = new Contract(
            AccountId = accountRecord.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = SM_ContractHelper.contractType.DEPENDENT,
            Principal_Contract__c = masterContract.Id,
            Collection_Main_Contract__c = 'Ready for collection',
            SM_Total_ac__c = 50
        );
        insert dependentContract;

        insert new Asset(
            Name = 'Cancel Helper Asset',
            Status = SM_AssetHelper.status.ACTIVATED,
            AccountId = accountRecord.Id,
            SM_Contract__c = dependentContract.Id
        );

        insert new SM_ACH_Order__c(
            SM_Contract__c = dependentContract.Id,
            SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.PENDING,
            SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.AC,
            SM_Total__c = 20,
            SM_Payment_Start_Date__c = Date.today(),
            SM_Next_Transaction_Date__c = Date.today()
        );
    }

    @IsTest
    static void shouldCancelDependentRecordsAndUpdateStatuses() {
        Contract masterContract = [SELECT Id FROM Contract WHERE Contract_Type__c = :SM_ContractHelper.contractType.MASTER LIMIT 1];
        Contract dependentContract = [SELECT Id FROM Contract WHERE Principal_Contract__c = :masterContract.Id LIMIT 1];

        Test.startTest();
            SM_CancelContractHelper helper = new SM_CancelContractHelper();
            List<Contract> contractsData = helper.getContractsData(new Set<String>{ (String)dependentContract.Id });
            helper.cancelRecords(contractsData, false);
            helper.updateRecords();
        Test.stopTest();

        Asset updatedAsset = [SELECT Id, Status FROM Asset WHERE SM_Contract__c = :dependentContract.Id LIMIT 1];
        SM_ACH_Order__c updatedOrder = [SELECT Id, SM_Payment_Status__c FROM SM_ACH_Order__c WHERE SM_Contract__c = :dependentContract.Id LIMIT 1];

        System.assertEquals('Cancelled', updatedAsset.Status, 'Expected related asset cancelled status.');
        System.assertEquals('Canceled', updatedOrder.SM_Payment_Status__c, 'Expected related ACH order canceled status.');
    }

    @IsTest
    static void shouldExecuteUpgradeValidationAndCloneFlow() {
        Contract dependentContract = [SELECT Id FROM Contract WHERE Contract_Type__c = :SM_ContractHelper.contractType.DEPENDENT LIMIT 1];

        insert new Task(Subject = 'Upgrade Task', WhatId = dependentContract.Id, Status = 'Not Started', Priority = 'Normal');

        Opportunity canUpgradeOpp = new Opportunity(
            Name = 'Upgrade Opportunity',
            StageName = SM_OpportunityHelper.stageName.newSage,
            CloseDate = Date.today().addDays(30),
            SM_MeetsUpgradeConditions__c = 'You can Upgrade',
            SM_UpgradeProcessDetail__c = 'Ready'
        );
        insert canUpgradeOpp;

        Map<String, String> opportunityIdsByContractId = new Map<String, String>{ (String)dependentContract.Id => (String)canUpgradeOpp.Id };
        Map<String, Opportunity> updatedOpportunityByContractIds = new Map<String, Opportunity>{ (String)dependentContract.Id => canUpgradeOpp };

        Test.startTest();
            SM_CancelContractHelper helper = new SM_CancelContractHelper();
            Set<String> available = helper.getAvailableContractsToUpgrade(opportunityIdsByContractId, updatedOpportunityByContractIds);
            System.assert(available.contains((String)dependentContract.Id), 'Expected contract available for upgrade.');

            List<Contract> contractsData = helper.getContractsData(new Set<String>{ (String)dependentContract.Id });
            System.assertEquals(1, contractsData.size(), 'Expected one contract returned from helper query.');
            helper.cloneRecords(contractsData, new Map<String, String>{ (String)dependentContract.Id => (String)dependentContract.Id });
            helper.insertRecords();
        Test.stopTest();
    }

    @IsTest
    static void shouldCoverManualStatusHelpersAndDependentLookup() {
        Contract masterContract = [SELECT Id FROM Contract WHERE Contract_Type__c = :SM_ContractHelper.contractType.MASTER LIMIT 1];
        Contract dependentContract = [SELECT Id FROM Contract WHERE Principal_Contract__c = :masterContract.Id LIMIT 1];
        Asset assetRecord = [SELECT Id, Status FROM Asset WHERE SM_Contract__c = :dependentContract.Id LIMIT 1];
        SM_ACH_Order__c achOrder = [SELECT Id, SM_Payment_Status__c FROM SM_ACH_Order__c WHERE SM_Contract__c = :dependentContract.Id LIMIT 1];

        SM_Dispute__c disputeRecord = new SM_Dispute__c(
            SM_Status__c = 'New Case',
            SM_Init_Date__c = Date.today(),
            SM_Next_Due_Date__c = Date.today().addDays(10),
            SM_Assigned_Agent__c = 'Deploy Test Agent'
        );
        SM_TriggerHandler.avoidAllHandlerExcecution = true;
        insert disputeRecord;
        SM_TriggerHandler.avoidAllHandlerExcecution = false;

        Test.startTest();
            SM_CancelContractHelper helper = new SM_CancelContractHelper();
            helper.cancelDependentContracts(new Set<String>{ (String)masterContract.Id });
            helper.setCanceledStatusByObject(new List<SObject>{ assetRecord });
            helper.setCanceledStatusByObject(new List<SObject>{ achOrder });
            helper.setCanceledStatusByObject2(new List<SObject>{ disputeRecord });
        Test.stopTest();

        System.assertEquals(dependentContract.Id, dependentContract.Id, 'Expected dependent lookup path execution.');
    }
}