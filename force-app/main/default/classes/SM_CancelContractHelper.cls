/**
 * @description       :
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : LCS
 * @last modified on  : 10-28-2022
 * @last modified by  : Jonathan S. Pachon (JSPA)
**/
public with sharing class SM_CancelContractHelper {

    private static Boolean hasChargentObjectAccess() {
        if (Test.isRunningTest()) {
            return true;
        }
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('ChargentOrders__ChargentOrder__c')) {
            return false;
        }
        Schema.DescribeSObjectResult chargentDescribe = globalDescribe.get('ChargentOrders__ChargentOrder__c').getDescribe();
        return chargentDescribe.isAccessible() && chargentDescribe.isUpdateable();
    }

    /** This map contains the field and value by Sobject name, to update to cancel */
    private Map<String, List<String>> canceledDataByObjectType = new Map<String, List<String>>{
        'Asset' => new List<String>{'Status', 'Cancelled'},
        'SM_Dispute__c' => new List<String>{'SM_Status__c', 'Cancelled'},
        'SM_ACH_Order__c' => new List<String>{'SM_Payment_Status__c', 'Canceled'},
        'ChargentOrders__ChargentOrder__c' => new List<String>{'ChargentOrders__Status__c', 'Canceled'},
        'SM_Payment__c' => new List<String>{'Payment_Status__c', 'CANCELLED'},
        'Contract' => new List<String>{'Status', 'Cancelled'},
        'echosign_dev1__SIGN_Agreement__c' => new List<String>{'echosign_dev1__Status__c', 'Cancelled / Declined'}
    };

    private Set<SObject> recordsToUpdate = new Set<SObject>();
    private Set<SObject> recordsToUpdate2 = new Set<SObject>();
    private List<SObject> recordsToInsert;

    /**
    * @description
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param Set<String> contractIds
    * @return List<Contract>
    **/
    public List<Contract> getContractsData(Set<String> contractIds){

        if (hasChargentObjectAccess()) {
            return [SELECT
                        (SELECT Id FROM Assets__r),
                        (SELECT Id FROM Disputes__r),
                        (SELECT Id FROM ACH_Orders__r),
                        (SELECT Id FROM Chargent_Orders__r),
                        (SELECT Id FROM echosign_dev1__R00N70000001hM2JEAU__r),
                        (SELECT Id FROM Payment_Data__r WHERE SM_ACH_Order__c <> null AND Payment_Status__c IN ('ACH PENDING', 'ACH TRANSMITTED')),
                        (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                            CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                            RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                            Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                            Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                            SM_Migration_Date__c, SM_Is_Migrated__c
                            FROM Tasks),
                        (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                            SM_Opportunity__c, SM_Contract__c
                            FROM SM_Cloud_Documents_Contract__r)
                    FROM Contract
                    WHERE Id IN: contractIds];
        }

        return [SELECT
                    (SELECT Id FROM Assets__r),
                    (SELECT Id FROM Disputes__r),
                    (SELECT Id FROM ACH_Orders__r),
                    (SELECT Id FROM echosign_dev1__R00N70000001hM2JEAU__r),
                    (SELECT Id FROM Payment_Data__r WHERE SM_ACH_Order__c <> null AND Payment_Status__c IN ('ACH PENDING', 'ACH TRANSMITTED')),
                    (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                        CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                        RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                        Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                        Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                        SM_Migration_Date__c, SM_Is_Migrated__c
                        FROM Tasks),
                    (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                        SM_Opportunity__c, SM_Contract__c
                        FROM SM_Cloud_Documents_Contract__r)
                FROM Contract
                WHERE Id IN: contractIds];
    }

    /**
    * @description This methos excecute de proccess to cancel dependent contracts and related records
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 07/10/2022
    * @param contractIds
    **/
    public void cancelDependentContracts(Set<String> contractIds) {

        Set<String> dependentContractIds = new Set<String>();

        for (Contract dependent : [SELECT Id FROM Contract WHERE Principal_Contract__c IN: contractIds]) {
            dependentContractIds.add(dependent.Id);
        }

        if (!dependentContractIds.isEmpty()) {
            /** Send records to cancel */
            cancelRecords(getContractsData(dependentContractIds), true);
        }
    }

    /**
    * @description Thid method validate what contracts are available to upgrade
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param Map<String String> opportunityIdsByContractId
    * @param Map<String Opportunity> updatedOpportunityByContractIds
    * @return Set<String>
    **/
    public Set<String> getAvailableContractsToUpgrade(Map<String,String> opportunityIdsByContractId, Map<String,Opportunity> updatedOpportunityByContractIds) {
        Set<String> availableContractToUpgradeIds = new Set<String>();
        for (String  ctId : opportunityIdsByContractId.keySet()) {
            if (updatedOpportunityByContractIds.containsKey(ctId)) {
                Opportunity opp = updatedOpportunityByContractIds.get(ctId);
                if (opp.SM_MeetsUpgradeConditions__c == 'You can Upgrade') {
                    availableContractToUpgradeIds.add(ctId);
                } else {
                    String description = System.label.SM_ERROR_CANCEL_UPGRADED_CONTRACT_PROCESS;
                    String errorDetail = 'Meets Upgrade Condition: ' + opp.SM_MeetsUpgradeConditions__c + ' - Upgraded Process Detail: ' + opp.SM_UpgradeProcessDetail__c;
                    description = String.format(description, new List<String>{ctId, errorDetail});
                    TransactionLogHandler.doHandleException(description, 'CancelUpgradedContract', ctId);
                    SM_TaskHelper.createTaskToValidateErrorInUpgradedContract(description, ctId);
                }
            }
        }
        return availableContractToUpgradeIds;
    }

    /**
    * @description This method prepare data to cancel the related contract records
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param List<Contract> upgradedContracts
    * @param Boolean cancelContract
    **/
    public void cancelRecords(List<Contract> upgradedContracts, Boolean cancelContract){

        Map<String,SM_ACH_Order__c> ordersToProcess = new Map<String,SM_ACH_Order__c>();

        /** Check related lists by contract, to update to cancel */
        for (Contract upgradedContract : upgradedContracts) {

            if (!upgradedContract.Payment_Data__r.isEmpty()) {
                String description = System.label.ERROR_CANCEL_UPGRADED_CONTRACT_BY_PENDING_PAYMENT;
                TransactionLogHandler.doHandleException(description, 'CancelUpgradedContract', upgradedContract.Id);
                SM_TaskHelper.createTaskToValidateErrorInUpgradedContract(description, upgradedContract.Id);
                continue;
            }

            if (!upgradedContract.Assets__r.isEmpty()) {
                setCanceledStatusByObject(upgradedContract.Assets__r);
            }

            if (!upgradedContract.Disputes__r.isEmpty()) {
                setCanceledStatusByObject2(upgradedContract.Disputes__r);
            }

            if (!upgradedContract.Chargent_Orders__r.isEmpty()) {
                if (hasChargentObjectAccess()) {
                    setCanceledStatusByObject(upgradedContract.Chargent_Orders__r);
                }
            }

            if (!upgradedContract.ACH_Orders__r.isEmpty()) {
                setCanceledStatusByObject(upgradedContract.ACH_Orders__r);
            }

            if (!upgradedContract.echosign_dev1__R00N70000001hM2JEAU__r.isEmpty()) {
                setCanceledStatusByObject(upgradedContract.echosign_dev1__R00N70000001hM2JEAU__r);
            }

            if (cancelContract) {
                setCanceledStatusByObject(new List<SObject>{upgradedContract});
            }
        }
    }

    /**
    * @description This method cancel all related contract records except disputes
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param List<SObject> sobjects
    **/
    public void setCanceledStatusByObject(List<SObject> sobjects){
        String sobjectName = SM_Utils.getSObjectNameById((Id)sobjects[0].get('Id'));
        List<String> cancelData = canceledDataByObjectType.get(sobjectName);
        for (SObject so : sobjects) {
            so.put(cancelData[0], cancelData[1]);
            recordsToUpdate.add(so);
        }
    }

    /**
    * @description This method cancel disputes because it's required to fire dispute handler
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param List<SObject> sobjects
    **/
    public void setCanceledStatusByObject2(List<SObject> sobjects){
        String sobjectName = SM_Utils.getSObjectNameById((Id)sobjects[0].get('Id'));
        List<String> cancelData = canceledDataByObjectType.get(sobjectName);
        for (SObject so : sobjects) {
            so.put(cancelData[0], cancelData[1]);
            recordsToUpdate2.add(so);
        }
    }

    /**
    * @description
    * @author Jonathan S. Pachon (JSPA) | 10-06-2022
    * @param List<Contract> upgradedContracts
    * @param Map<String String> newContractByUpgraded
    **/
    public void cloneRecords(List<Contract> upgradedContracts, Map<String,String> newContractByUpgraded){

        recordsToInsert = new List<SObject>();

        for (Contract upgradedContract : upgradedContracts) {
            /** Clone tasks */
            for (Task task : upgradedContract.Tasks) {
                Task clonedTask = task.clone(false, true, true, false);
                clonedTask.WhatId = newContractByUpgraded.get(upgradedContract.Id);
                recordsToInsert.add(clonedTask);
            }

            /** Clone cloud documents */
            for (SM_Cloud_Document__c cloudDocument : upgradedContract.SM_Cloud_Documents_Contract__r) {
                SM_Cloud_Document__c cloneCloudDocument = cloudDocument.clone();
                cloneCloudDocument.SM_Contract__c = newContractByUpgraded.get(upgradedContract.Id);
                recordsToInsert.add(cloneCloudDocument);
            }
        }
    }

    /**
    * @description This method execute update DML to related contract records and contract
    * @author Jonathan S. Pachon (JSPA) | 10-28-2022
    **/
    public void updateRecords(){

        if (!recordsToUpdate.isEmpty()) {
            List<SObject> auxListToUpdate = new List<SObject>(recordsToUpdate);
            auxListToUpdate.sort();
            SM_TriggerHandler.avoidAllHandlerExcecution = true;
            SM_BypassManager.disableValidationRules();
            update auxListToUpdate;
            SM_BypassManager.enableValidationRules();
            SM_TriggerHandler.avoidAllHandlerExcecution = false;
        }
        if (!recordsToUpdate2.isEmpty()) {
            List<SObject> auxListToUpdate = new List<SObject>(recordsToUpdate2);
            auxListToUpdate.sort();
            update auxListToUpdate;
        }
    }

    /**
    * @description This method execute insert DML to clone records from upgraded contract to new activated contract
    * @author Jonathan S. Pachon (JSPA) | 10-28-
    **/
    public void insertRecords(){

        if(!recordsToInsert.isEmpty()){
            recordsToInsert.sort();
            insert recordsToInsert;
        }
    }

}