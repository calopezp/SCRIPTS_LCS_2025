/**
 * @description       : Opportunity Object Handler
 * @author            : jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 10-14-2022
 * @last modified by  : Jonathan S. Pachon (JSPA)
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-27-2020   jpachon@legal-credit.com   Initial Version
 * 1.1   02-14-2021   cjimenez@legal-credit.com   Initial Version
**/
public without sharing class SM_OpportunityHandler extends SM_TriggerHandler{

    /* Static variables */
    private static String reminderIdRT = SM_Utils.getRecordTypeIdByDeveloperName('Task', SM_TaskHelper.recordType.reminder);

    public SM_OpportunityHandler(String triggerName){
        super(triggerName);
    }

    
    /************* Overwrite DML methods *************/
    override public void beforeInsert() {
        try {
           // SRQ - SFDCMP-177
            addPricebook2(Trigger.new);
            updateNameOpprtunity(Trigger.new);
        } catch (Exception e) {
            System.debug('An error occurred in afterInsert Opportunity  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /************* Overwrite DML methods *************/
    override public void afterInsert() {
        try {
            List<Opportunity> oppsToSend = getOpportunitiesToSendFive9(Trigger.newMap);
            if(!oppsToSend.isEmpty()) {
                five9ListAssignmentProcess(oppsToSend);
            }
        } catch (Exception e) {
            System.debug('An error occurred in afterInsert Opportunity  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    override public void afterUpdate() {
        try {
            // JSPA - SFDCMP-63
            processChangesInStageOrDisposition(Trigger.new, Trigger.oldMap);
            //Call method to create contracts
            createContracts(Trigger.new, Trigger.oldMap);
            // SMMCI-48
            processOpportunitiesToValidateUpgrade(Trigger.newMap, Trigger.oldMap);
        } catch (Exception e) {
            System.debug('An error occurred in afterUpdate Opportunity  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /************* Auxiliar methods *************/

    /**
    * @description This method calls five9 helper to assign records to a five9 list
    * @author jpachon@legal-credit.com | 11-28-2020
    * @param newLeads
    **/
    public static void five9ListAssignmentProcess(List<Opportunity> records) {
        System.debug('newOpps: ' + JSON.serialize(records));
         List<Opportunity> temNewOpportunity=new List<Opportunity>();
        // No se crean Five9List para registros creados por formulario New Lead  Camilo Jimenez 10/12/2020
        for (Opportunity opportunity : records) {
           if(!opportunity.SM_Call_Inbound__c){
             temNewOpportunity.add(opportunity);
           }
        }
        SM_Five9Helper.ResultWrapper result = SM_Five9Helper.getFive9ListByRecordId(temNewOpportunity);
        if (!result.errorMsgByRecordId.containsKey('Error')) {
            if (!result.recordsToInsert.isEmpty()) {
                insertFive9ListItems(result.recordsToInsert);
            }
            // TO DO - Confirmar como identificar si debe o no reportar el error presentado durante el proceso de asignacion de lista
        } 
        System.debug('result: ' + JSON.serialize(result));        
    }

    /**
    * @description Method to insert five9 list item records
    * @author jpachon@legal-credit.com | 11-28-2020
    * @param records List<Five9LSP__Five9_List_Item__c>
    **/
    public static void insertFive9ListItems(List<Five9LSP__Five9_List_Item__c> records) {
        List<Database.SaveResult> sr = Database.insert(records, false);
        System.debug('sr: ' + JSON.serialize(sr));
    }

    /**
    * @description Method to return what opportunity records will be sent to five9 process
    * @author jpachon@legal-credit.com | 11-28-2020
    * @param newRecords Map<Id, SObject>
    * @return List<Opportunity>
    **/
    public static List<Opportunity> getOpportunitiesToSendFive9(Map<Id, SObject> newRecords) {
        System.debug('----> ' + newRecords.size());
        Map<Id, Opportunity> newOpps = (Map<Id, Opportunity>)newRecords.clone();
        for (Opportunity record : newOpps.values()) {
            if (record.SM_Conversion_opportunity__c) {
                newOpps.remove(record.Id);
            }
        }
        System.debug('----> ' + newOpps.size());
        return (List<Opportunity>)newOpps.values();
    }

    /**
    * @description Method to process opportunities when have changed stage or disposition value
    * @author jpachon@legal-credit.com | 11-28-2020
    * @param newOpps List<Opportunity>
    * @param oldMap Map<Id, SObject>
    **/
    public static void processChangesInStageOrDisposition(List<Opportunity> newOpps, Map<Id, SObject> oldMap) {
        Map<String, Opportunity> oppsToProcessById = new Map<String, Opportunity>();
        for (Opportunity newOpp : newOpps) {
            Opportunity oldOpp = (Opportunity)oldMap.get(newOpp.Id);
            if (SM_Utils.isChangedField(newOpp, oldOpp, new String[]{'StageName', 'SM_Opportunity_Disposition__c'})) {
                oppsToProcessById.put(newOpp.Id, newOpp);
            }
        }
        if (!oppsToProcessById.isEmpty()) {
            // Its REQUIRED get related data before insert the new records.
            List<Opportunity> oppsWithRelatedData = [SELECT Id, Name, 
                                                (SELECT Id FROM Five9LSP__Five9_List_Items__r),
                                                (SELECT Id, Subject, ActivityDate FROM Tasks WHERE RecordTypeId =: reminderIdRT AND IsRecurrence = FALSE AND Status =: SM_TaskHelper.status.open)
                                                FROM Opportunity WHERE Id IN: oppsToProcessById.keySet()];
            SM_Five9Helper.ResultWrapper result = SM_Five9Helper.getFive9ListByRecordId(oppsToProcessById.values());
            System.debug('result: ' + JSON.serialize(result));
            if (!result.recordsToInsert.isEmpty()){
                List<Database.SaveResult> srLst = Database.insert(result.recordsToInsert, false);
                System.debug('srLst: ' + JSON.serialize(srLst));
            }            
            processOldRelatedData(oppsWithRelatedData);
        }
    }
    
    /**
    * @description Method to process old related data like five9 list items or reminders (tasks)
    * @author jpachon@legal-credit.com | 11-28-2020
    * @param oppsWithRelatedData List<Opportunity>
    **/
    public static void processOldRelatedData(List<Opportunity> oppsWithRelatedData) {
        System.debug('oppsWithRelatedData: ' + JSON.serialize(oppsWithRelatedData));
        List<SObject> sObjectsToDelete = new List<SObject>();
        List<Task> remindersToUpdate = new List<Task>();
        for (Opportunity opp : oppsWithRelatedData) {
            if (!opp.Five9LSP__Five9_List_Items__r.isEmpty()) {
                sObjectsToDelete.addAll(opp.Five9LSP__Five9_List_Items__r);
            }
            if (!opp.Tasks.isEmpty()) {
                remindersToUpdate.addAll(opp.Tasks);
            }
        }
        // JSPA - SFDCMP-49
        if (!remindersToUpdate.isEmpty()) {
            for (Task reminder : remindersToUpdate) {
                if (reminder.ActivityDate <= System.today()) {
                    reminder.Status = SM_TaskHelper.status.completed;
                } else if (reminder.ActivityDate > System.today()) {
                    sObjectsToDelete.add(reminder);
                }
            }
            Database.update(remindersToUpdate, false);
        }
        System.debug('sObjectsToDelete: ' + JSON.serialize(sObjectsToDelete));
        if (!sObjectsToDelete.isEmpty()) {
            sObjectsToDelete.sort();
            List<Database.DeleteResult> rs = Database.delete(sObjectsToDelete, true);
            System.debug('rs: ' + JSON.serialize(rs));
        }
    }

    /**
    * @description Method to validate if generate contract
    * @author diego.jacanamijoy@gmail.com | 02-04-2021 
    * @param newOpps 
    * @param oldMap 
    **/
    public void createContracts(List<Opportunity> newOpps, Map<Id, SObject> oldMap){
        Map<String,Opportunity> idsByOppValids = new Map<String,Opportunity>();
        List<String> dispositionsValids = new List<String>{SM_OpportunityHelper.dispositions.sale, SM_OpportunityHelper.dispositions.salePtp};
        for (Opportunity newOpp : newOpps) {
            Opportunity oldOpp = (Opportunity)oldMap.get(newOpp.Id);
            if (SM_Utils.isChangedField(newOpp, oldOpp, new String[]{'StageName', 'SM_Opportunity_Disposition__c'}) 
                    && newOpp.StageName == SM_OpportunityHelper.stageName.oriented 
                    && dispositionsValids.contains(newOpp.SM_Opportunity_Disposition__c)) {
                        idsByOppValids.put(newOpp.Id,newOpp);
            }
        }
        if(!idsByOppValids.isEmpty()){
            new SM_GenerateContractController(idsByOppValids);
        }
    }

    /**
    * @description Method Update Pricebook2Id
    * @author  cjimenez@legal-credit.com | 14-02-2021
    * @param newMap
    **/
    public static void addPricebook2(List<Opportunity> newOpps) {
       Map<String, String> compSettiToProcessById = new Map<String, String>();
       Set<Id> compaSetids = new Set<Id>();
       for (Opportunity newOpp : newOpps) {
            compaSetids.add(newOpp.SM_Company_Setting__c);
        }

       if(!compaSetids.isEmpty()) {
        for(SM_Company_setting__c compSetti : [SELECT Id,SM_Pricebook2Id__c
                                           FROM SM_Company_setting__c WHERE Id IN: compaSetids]){
            compSettiToProcessById.put(compSetti.Id, compSetti.SM_Pricebook2Id__c);            
          }
       }
       if(!compaSetids.isEmpty()) {
        for (Opportunity newOpp : newOpps) {
            String key=newOpp.SM_Company_Setting__c;
            String pricebook2Id = compSettiToProcessById.containsKey(key) ? compSettiToProcessById.get(key) : null;
            newOpp.Pricebook2Id=pricebook2Id;
          }
       }
    }

      /**
    * @description This method update name opportunity
    * @author cjimenez@legal-credit.com | 22-02-2021
    * @param newOpportunityLineItems 
    **/
    public void updateNameOpprtunity(List<Opportunity> newOpps){

        Map<String, String> compSettiToProcessById = new Map<String, String>();
        Map<String, String> customerNumberByAcc = new Map<String, String>();
        Set<Id> compaSetIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity newOpp : newOpps) {
             compaSetids.add(newOpp.SM_Company_Setting__c);
             accountIds.add(newOpp.AccountId);
         }
 
        if(!compaSetids.isEmpty()) {
         for(SM_Company_setting__c compSetti : [SELECT Id,SM_Pricebook2Id__c,SM_Abbreviated_Company__c
                                                FROM SM_Company_setting__c WHERE Id IN: compaSetIds]){
             compSettiToProcessById.put(compSetti.Id, compSetti.SM_Abbreviated_Company__c);            
           }
        }
        if(!accountIds.isEmpty()) {
         for(Account account:[SELECT id,name,SM_Customer_Number__pc
                                    FROM Account
                                    WHERE ID IN :accountIds]){
            customerNumberByAcc.put(account.id,account.SM_Customer_Number__pc);
         }
       }
        Datetime currentDate =DateTime.now();
      if(!compSettiToProcessById.isEmpty()) {
        for (Opportunity newOpp : newOpps) {
            String keyComp=newOpp.SM_Company_Setting__c;
            String keyAcc=newOpp.AccountId;
            String abbreviatedCompany = compSettiToProcessById.containsKey(keyComp) ? compSettiToProcessById.get(keyComp) : null;
            String customerNumber = customerNumberByAcc.containsKey(keyAcc) ? customerNumberByAcc.get(keyAcc) : null;
            newOpp.name='OPT_'+abbreviatedCompany+'_'+customerNumber+'_'+currentDate.format('dd_MM_yyyy');         
          }
       }
       
    }

    public static void processOpportunitiesToValidateUpgrade(Map<Id, SObject> newRecords, Map<Id, SObject> oldRecords) {
        Map<String,String> opportunityIdsByContractId = new Map<String,String>();
        // Validate what records have changed the Contract to be upgraded field
        for (Opportunity newOpp : (List<Opportunity>)newRecords.values()) {
            Opportunity oldOpp = (Opportunity)oldRecords.get(newOpp.Id);
            if (SM_Utils.isChangedField(newOpp, oldOpp, 'SM_ContractToBeUpgraded__c')) {
                opportunityIdsByContractId.put(newOpp.SM_ContractToBeUpgraded__c, newOpp.Id);
            }
        }
        if (opportunityIdsByContractId.isEmpty()) return;
        Map<String,Opportunity> opportunitiesToUpdate = processRecordsToValidateUpgrade(opportunityIdsByContractId);
        if (!opportunitiesToUpdate.isEmpty()) {
            Database.update(opportunitiesToUpdate.values());
        }
    }

    public static Map<String,Opportunity> processRecordsToValidateUpgrade(Map<String,String> opportunityIdsByContractId) {
        Map<String,Opportunity> results = new Map<String,Opportunity>();
        Map<String, List<Asset>> assetsByContractId = new Map<String, List<Asset>>();
        Set<String> productIds = new Set<String>();
        // Get related asset products of the selected contracts to be upgrade
        for (Contract ct : [SELECT Id, (SELECT Id, Product2Id FROM Assets__r) FROM Contract WHERE Id IN: opportunityIdsByContractId.keySet()]) {
            if (ct.Assets__r.size() == 0) {
                continue;
            }
            for (Asset asset : ct.Assets__r) {
                if (!assetsByContractId.containsKey(ct.Id)) {
                    assetsByContractId.put(ct.Id, new List<Asset>());
                }
                assetsByContractId.get(ct.Id).add(asset);
                productIds.add(asset.Product2Id);
            }
        }
        if (assetsByContractId.isEmpty()) return new Map<String,Opportunity>();
        Map<String,List<SM_UpgradePolicy__c>> upgradePoliciesByProductId = new Map<String,List<SM_UpgradePolicy__c>>();
        Set<String> upgradePolicyIds = new Set<String>();
        // Get Active Upgrade Policies by Product2
        for (Product2 product : [SELECT Id, (SELECT Id FROM Upgrade_policies__r WHERE SM_Active__c = TRUE) FROM Product2 WHERE Id IN: productIds]) {
            if (product.Upgrade_policies__r.size() == 0) {
                continue;
            }
            for (SM_UpgradePolicy__c upgradePolicy : product.Upgrade_policies__r) {
                if (!upgradePoliciesByProductId.containsKey(product.Id)) {
                    upgradePoliciesByProductId.put(product.Id, new List<SM_UpgradePolicy__c>());
                }
                upgradePoliciesByProductId.get(product.Id).add(upgradePolicy);
                upgradePolicyIds.add(upgradePolicy.Id);
            }
        }
        if (upgradePoliciesByProductId.isEmpty()) {
            for (String ctId : opportunityIdsByContractId.keySet()) {
                String opportunityId = opportunityIdsByContractId.get(ctId);
                results.put(ctId, new Opportunity(Id = opportunityId, SM_MeetsUpgradeConditions__c = 'You can Upgrade'));
            }
            return results;
        }
        Map<String,List<SM_ProductLinkingRule__c>> productLinkingRulesByUpgradePolicyId = new Map<String,List<SM_ProductLinkingRule__c>>();
        // Get Product Linking Rules by Upgrade Policy Id
        for (SM_UpgradePolicy__c upgradePolicy : [SELECT Id, (SELECT Id, Name, SM_PrincipalObject__c, SM_ObjectRelation1__c, SM_ObjectRelation2__c, SM_Field__c, SM_Operator__c, SM_Type__c,
                                                                SM_Condition__c, SM_TypeCondition__c, SM_PrincipalObjectCondition__c, SM_ConditionObjectRelation1__c, SM_ConditionObjectRelation2__c, SM_ConditionField__c
                                                                FROM Product_linking_rules__r WHERE SM_Active__c = TRUE ORDER BY Name ASC)
                                                     FROM SM_UpgradePolicy__c WHERE Id IN: upgradePolicyIds]) {
            if (upgradePolicy.Product_linking_rules__r.size() == 0) {
                continue;
            }
            for (SM_ProductLinkingRule__c productLinkingRule : upgradePolicy.Product_linking_rules__r) {
                if (!productLinkingRulesByUpgradePolicyId.containsKey(upgradePolicy.Id)) {
                    productLinkingRulesByUpgradePolicyId.put(upgradePolicy.Id, new List<SM_ProductLinkingRule__c>());
                }
                productLinkingRulesByUpgradePolicyId.get(upgradePolicy.Id).add(productLinkingRule);
            }
        }
        if (productLinkingRulesByUpgradePolicyId.isEmpty()) {
            for (String ctId : opportunityIdsByContractId.keySet()) {
                String opportunityId = opportunityIdsByContractId.get(ctId);
                results.put(ctId, new Opportunity(Id = opportunityId, SM_MeetsUpgradeConditions__c = 'You can Upgrade'));
            }
            return results;
        }
        return executeQueriesAndGetOpportunityToUpdate(opportunityIdsByContractId,assetsByContractId,upgradePoliciesByProductId,productLinkingRulesByUpgradePolicyId);
    }

    private static Map<String,Opportunity> executeQueriesAndGetOpportunityToUpdate(Map<String,String> opportunityIdsByContractId,Map<String, List<Asset>> assetsByContractId,Map<String,List<SM_UpgradePolicy__c>> upgradePoliciesByProductId,Map<String,List<SM_ProductLinkingRule__c>> productLinkingRulesByUpgradePolicyId) {
        Map<String,Opportunity> updatedOpportunityByContractIds = new Map<String,Opportunity>();
        Set<String> generalTypes = new Set<String>{'Boolean','Currency','Number'};
        Boolean upgradeContract;
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        String upgradeCondition;
        List<String> errorDetails = new List<String>();
        Map<String,String> operators = new Map<String,String>{
            'equalsTo'=>'=',
            'lessThan'=>'<',
            'greaterThan'=>'>',
            'lessThanOrEqualTo'=>'<=',
            'greaterThanOrEqualTo'=>'>=',
            'notEqualsTo'=>'<>'
        };
        for (String ctId : opportunityIdsByContractId.keySet()) {
            String opportunityId = opportunityIdsByContractId.get(ctId);
            upgradeContract = true;
            for (Asset asset : assetsByContractId.get(ctId)) {
                for (SM_UpgradePolicy__c upgradePolicy : upgradePoliciesByProductId.get(asset.Product2Id)) {
                    String queryToExecute;
                    String conditionQueryToExecute;
                    List<String> parameters;
                    List<String> conditionParameters;
                    Boolean isVariableType;
                    for (SM_ProductLinkingRule__c productLinkingRule : productLinkingRulesByUpgradePolicyId.get(upgradePolicy.Id)) {
                        queryToExecute = '';
                        conditionQueryToExecute = '';
                        parameters = new List<String>();
                        conditionParameters = new List<String>();
                        isVariableType = false;
                        String fieldStr = productLinkingRule.SM_Field__c;
                        String conditionFieldStr = fieldStr;
                        if (productLinkingRule.SM_Type__c.equals('Static')) {
                            String staticQueryTemplate = 'SELECT {0} FROM {1} WHERE Id = {2} AND {3} {4} {5}';
                            if (String.isNotEmpty(productLinkingRule.SM_ObjectRelation2__c)) {
                                fieldStr = productLinkingRule.SM_ObjectRelation2__c + '.' + fieldStr;
                            }
                            if (String.isNotEmpty(productLinkingRule.SM_ObjectRelation1__c)) {
                                fieldStr = productLinkingRule.SM_ObjectRelation1__c + '.' + fieldStr;
                            }
                            parameters.add(fieldStr);
                            parameters.add(productLinkingRule.SM_PrincipalObject__c);
                            parameters.add('\'' + ctId + '\'');
                            parameters.add(productLinkingRule.SM_Field__c);
                            parameters.add(operators.get(productLinkingRule.SM_Operator__c));
                            if (generalTypes.contains(productLinkingRule.SM_TypeCondition__c)) {
                                parameters.add(productLinkingRule.SM_Condition__c);
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Text') || productLinkingRule.SM_TypeCondition__c.equals('Id')) {
                                parameters.add('\''+ (productLinkingRule.SM_Condition__c != null ? productLinkingRule.SM_Condition__c : '') +'\'');
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Date')) {
                                List<String> dateValues = productLinkingRule.SM_Condition__c.split('/');
                                Date dt = Date.newInstance(Integer.valueOf(dateValues[2]), Integer.valueOf(dateValues[0]), Integer.valueOf(dateValues[1]));
                                parameters.add(String.valueOf(dt));
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Datetime')) {
                                List<String> datetimeValues = productLinkingRule.SM_Condition__c.split(' ');
                                List<String> dateValues = datetimeValues[0].split('/');
                                List<String> timeValues = datetimeValues[1].split(':');
                                Datetime dt = Datetime.newInstance(Integer.valueOf(dateValues[2]), Integer.valueOf(dateValues[0]), Integer.valueOf(dateValues[1]), Integer.valueOf(timeValues[0]), Integer.valueOf(timeValues[1]), Integer.valueOf(timeValues[2]));
                                parameters.add(String.valueOf(dt));
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Variable')) {
                                System.debug('*** PENDING TO IMPLEMENT ***');
                            }
                            queryToExecute = String.format(staticQueryTemplate, parameters);
                        } else if (productLinkingRule.SM_Type__c.equals('Variable')) {
                            isVariableType = true;
                            // Variable Query Parameters - START
                            String variableQueryTemplate = 'SELECT {0} FROM {1} WHERE Id = {2}';
                            if (String.isNotEmpty(productLinkingRule.SM_ObjectRelation2__c)) {
                                fieldStr = productLinkingRule.SM_ObjectRelation2__c + '.' + fieldStr;
                            }
                            if (String.isNotEmpty(productLinkingRule.SM_ObjectRelation1__c)) {
                                fieldStr = productLinkingRule.SM_ObjectRelation1__c + '.' + fieldStr;
                            }
                            parameters.add(fieldStr);
                            parameters.add(productLinkingRule.SM_PrincipalObject__c);
                            parameters.add('\'' + ctId + '\'');
                            if (generalTypes.contains(productLinkingRule.SM_TypeCondition__c)) {
                                parameters.add(productLinkingRule.SM_Condition__c);
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Text') || productLinkingRule.SM_TypeCondition__c.equals('Id')) {
                                parameters.add('\''+ (productLinkingRule.SM_Condition__c != null ? productLinkingRule.SM_Condition__c : '') +'\'');
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Date')) {
                                List<String> dateValues = productLinkingRule.SM_Condition__c.split('/');
                                Date dt = Date.newInstance(Integer.valueOf(dateValues[2]), Integer.valueOf(dateValues[0]), Integer.valueOf(dateValues[1]));
                                parameters.add(String.valueOf(dt));
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Datetime')) {
                                List<String> datetimeValues = productLinkingRule.SM_Condition__c.split(' ');
                                List<String> dateValues = productLinkingRule.SM_Condition__c.split('/');
                                List<String> timeValues = productLinkingRule.SM_Condition__c.split(':');
                                Datetime dt = Datetime.newInstance(Integer.valueOf(dateValues[2]), Integer.valueOf(dateValues[0]), Integer.valueOf(dateValues[1]), Integer.valueOf(timeValues[0]), Integer.valueOf(timeValues[1]), Integer.valueOf(timeValues[2]));
                                parameters.add(String.valueOf(dt));
                            } else if (productLinkingRule.SM_TypeCondition__c.equals('Variable')) {
                                System.debug('*** PENDING TO IMPLEMENT ***');
                            }
                            queryToExecute = String.format(variableQueryTemplate, parameters);
                            // Variable Query Parameters - END
                            // Variable Condition Query Parameters - START
                            String variableConditionQueryTemplate = 'SELECT {0} FROM {1} WHERE Id = {2}';
                            if (String.isNotEmpty(productLinkingRule.SM_ConditionObjectRelation2__c)) {
                                conditionFieldStr = productLinkingRule.SM_ConditionObjectRelation2__c + '.' + conditionFieldStr;
                            }
                            if (String.isNotEmpty(productLinkingRule.SM_ConditionObjectRelation1__c)) {
                                conditionFieldStr = productLinkingRule.SM_ConditionObjectRelation1__c + '.' + conditionFieldStr;
                            }
                            conditionParameters.add(conditionFieldStr);
                            conditionParameters.add(productLinkingRule.SM_PrincipalObjectCondition__c);
                            conditionParameters.add('\'' + opportunityId + '\'');
                            conditionQueryToExecute = String.format(variableConditionQueryTemplate, conditionParameters);
                            // Variable Condition Query Parameters - END
                        }
                        System.debug('queryToExecute: ' + queryToExecute);
                        System.debug('conditionQueryToExecute: ' + conditionQueryToExecute);
                        List<SObject> recordReturned = new List<SObject>();
                        List<SObject> conditionRecordReturned;
                        try {
                             recordReturned = Database.query(queryToExecute);
                             if (isVariableType) {
                                try {
                                    conditionRecordReturned = Database.query(conditionQueryToExecute);
                                } catch (Exception ex) {
                                    System.debug('Exception: ' + ex.getMessage());
                                    upgradeContract = false;
                                    upgradeCondition = 'Error in the conditions configuration';
                                    errorDetails.add(productLinkingRule.Name + ' | ' + ex.getMessage() + '\n');
                                    continue;
                                }
                             }
                        } catch (Exception ex) {
                            System.debug('Exception: ' + ex.getMessage());
                            upgradeContract = false;
                            upgradeCondition = 'Error in the conditions configuration';
                            errorDetails.add(productLinkingRule.Name + ' | ' + ex.getMessage() + '\n');
                            continue;
                        }
                        if (!isVariableType) {
                            if (recordReturned.size() != 1) {
                                upgradeContract = false;
                                continue;
                            }
                        } else {
                            if (recordReturned.size() != 1 || conditionRecordReturned.size() != 1) {
                                upgradeContract = false;
                                continue;
                            }
                            System.debug('recordReturned: ' + recordReturned);
                            System.debug('conditionRecordReturned: ' + conditionRecordReturned);
                            // **************
                            Object recordValueReturned;
                            Object conditionRecordValueReturned;
                            if (!String.isEmpty(productLinkingRule.SM_ObjectRelation2__c)) {
                                recordValueReturned = recordReturned[0].getSObject(productLinkingRule.SM_ObjectRelation2__c).getSObject(productLinkingRule.SM_ObjectRelation1__c).get(productLinkingRule.SM_Field__c);
                            } else if (!String.isEmpty(productLinkingRule.SM_ObjectRelation1__c)) {
                                recordValueReturned = recordReturned[0].getSObject(productLinkingRule.SM_ObjectRelation1__c).get(productLinkingRule.SM_Field__c);
                            } else {
                                recordValueReturned = recordReturned[0].get(fieldStr);
                            }
                            if (!String.isEmpty(productLinkingRule.SM_ConditionObjectRelation2__c)) {
                                conditionRecordValueReturned = conditionRecordReturned[0].getSObject(productLinkingRule.SM_ConditionObjectRelation2__c).getSObject(productLinkingRule.SM_ConditionObjectRelation1__c).get(productLinkingRule.SM_Field__c);
                            } else if (!String.isEmpty(productLinkingRule.SM_ConditionObjectRelation1__c)) {
                                conditionRecordValueReturned = conditionRecordReturned[0].getSObject(productLinkingRule.SM_ConditionObjectRelation1__c).get(productLinkingRule.SM_ConditionField__c);
                            } else {
                                conditionRecordValueReturned = conditionRecordReturned[0].get(conditionFieldStr);
                            }
                            // **************
                            Boolean validation = false;
                            switch on productLinkingRule.SM_Operator__c {
                                when 'equalsTo' {
                                    System.debug('1');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Boolean') {
                                        validation = Boolean.valueOf(recordValueReturned) == Boolean.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Text' || productLinkingRule.SM_TypeCondition__c == 'Id') {
                                        validation = String.valueOf(recordValueReturned) == String.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when 'lessThan' {
                                    System.debug('2');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Number' || productLinkingRule.SM_TypeCondition__c == 'Currency') {
                                        validation = (Decimal)recordValueReturned < (Decimal)conditionRecordValueReturned;
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Date') {
                                        validation = Date.valueOf(recordValueReturned) < Date.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Datetime') {
                                        validation = Datetime.valueOf(recordValueReturned) < Datetime.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when 'greaterThan' {
                                    System.debug('3');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Number' || productLinkingRule.SM_TypeCondition__c == 'Currency') {
                                        validation = (Decimal)recordValueReturned < (Decimal)conditionRecordValueReturned;
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Date') {
                                        validation = Date.valueOf(recordValueReturned) < Date.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Datetime') {
                                        validation = Datetime.valueOf(recordValueReturned) < Datetime.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when 'lessThanOrEqualTo' {
                                    System.debug('4');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Number' || productLinkingRule.SM_TypeCondition__c == 'Currency') {
                                        validation = (Decimal)recordValueReturned < (Decimal)conditionRecordValueReturned;
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Date') {
                                        validation = Date.valueOf(recordValueReturned) < Date.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Datetime') {
                                        validation = Datetime.valueOf(recordValueReturned) < Datetime.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when 'greaterThanOrEqualTo' {
                                    System.debug('5');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Number' || productLinkingRule.SM_TypeCondition__c == 'Currency') {
                                        validation = (Decimal)recordValueReturned < (Decimal)conditionRecordValueReturned;
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Date') {
                                        validation = Date.valueOf(recordValueReturned) < Date.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Datetime') {
                                        validation = Datetime.valueOf(recordValueReturned) < Datetime.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when 'notEqualsTo' {
                                    System.debug('6');
                                    if (productLinkingRule.SM_TypeCondition__c == 'Number' || productLinkingRule.SM_TypeCondition__c == 'Currency') {
                                        validation = (Decimal)recordValueReturned < (Decimal)conditionRecordValueReturned;
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Date') {
                                        validation = Date.valueOf(recordValueReturned) < Date.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Datetime') {
                                        validation = Datetime.valueOf(recordValueReturned) < Datetime.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Boolean') {
                                        validation = Boolean.valueOf(recordValueReturned) == Boolean.valueOf(conditionRecordValueReturned);
                                    }
                                    if (productLinkingRule.SM_TypeCondition__c == 'Text' || productLinkingRule.SM_TypeCondition__c == 'Id') {
                                        validation = String.valueOf(recordValueReturned) == String.valueOf(conditionRecordValueReturned);
                                    }
                                }
                                when else {
                                    System.debug('default');
                                }
                            }
                            if (!validation) {
                                upgradeContract = false;
                            }
                        }
                        // queriesToExecute.add(queryToExecute);
                    }
                }
            }
            String errorDetail = '';
            if (!errorDetails.isEmpty()) {
                for (String error : errorDetails) {
                    errorDetail += error;
                }
            } else {
                if (upgradeContract) {
                    upgradeCondition = 'You can Upgrade';
                } else {
                    upgradeCondition = 'Cannot upgrade';
                }
            }
            if (!updatedOpportunityByContractIds.containsKey(ctId)) {
                updatedOpportunityByContractIds.put(ctId, new Opportunity(Id = opportunityId, SM_MeetsUpgradeConditions__c = upgradeCondition, SM_UpgradeProcessDetail__c = errorDetail));
            }
            // opportunitiesToUpdate.add(new Opportunity(Id = opportunityId, SM_MeetsUpgradeConditions__c = upgradeCondition, SM_UpgradeProcessDetail__c = errorDetail));
        }
        return updatedOpportunityByContractIds;
        // return opportunitiesToUpdate;
    }

    // processRecordsToValidateUpgrade(Trigger.new, Trigger.oldMap);
}