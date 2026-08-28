/**
 * @description       : Task Object Handler
 * @author            : jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-18-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                        Modification
 * 1.0   11-27-2020   jpachon.ariza@gmail.com   Initial Version
**/
public without sharing class SM_TaskHandler extends SM_TriggerHandler{

    // private static Map<String, Map<String, String>> configBySObjectName;
    private static Map<String, Map<String, Map<String, String>>> configBySObjectName;

    private static List<String> oppNotValidStages {
        get{
            if(oppNotValidStages == null || oppNotValidStages.isEmpty()){
                try {
                    General_Setting__mdt gs = [SELECT Value__c FROM General_Setting__mdt   WHERE DeveloperName = 'SM_Invalid_states_for_opp_update_five9' LIMIT 1];
                    oppNotValidStages = gs.Value__c.split(';');
                } catch (Exception e) {
                    oppNotValidStages = new List<String>();
                }
            }
            return oppNotValidStages;
        }

        set {}
    }

    public SM_TaskHandler(String triggerName) {
        super(triggerName);
        getMetadata();
    }

    /************* Overwrite DML methods *************/
    override public void afterInsert() {
        try {
            System.debug('afterInsert: ' + UserInfo.getName());
            System.debug('afterInsert: ' + Trigger.new);
            udpateRelatedObject(Trigger.new);
        } catch (Exception e) {
            System.debug('An error occurred in afterInsert Lead  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /************* Auxiliar methods *************/

    /**
    * @description this method validate required fields
    * @author jpachon.ariza@legal-credit.com | 12-23-2020
    * @param newTasks
    **/
    public static void udpateRelatedObject(List<Task> newTasks) {
        System.debug('executing udpateRelatedObject');
        Map<String, List<SObject>> recordsToUpdate = new Map<String, List<SObject>>();
        List<SObject> listToUpdate = new List<SObject>();
        Map<String, String> categoryBydisposition;
        String sObjectName;
        String sObjectId;
        for (Task record : newTasks) {
            sObjectId = String.isBlank(record.WhatId) ? (String.isBlank(record.WhoId) ? '' : record.WhoId) : record.WhatId;
            // category = new Map<String, String>();
            // It's necessary filter by Five9__Five9SessionId__c field to identify what tasks have been created from Five9
            if (record.Five9__Five9SessionId__c != null && String.isNotBlank(sObjectId)) {
                sObjectName = SM_Utils.getSObjectNameById(sObjectId);
                String callDisposition = record.CallDisposition;
                if (configBySObjectName.containsKey(sObjectName) && configBySObjectName.get(sObjectName).containsKey(callDisposition)) {
                    categoryBydisposition = configBySObjectName.get(sObjectName).get(callDisposition);
                }
            }
            if (categoryBydisposition != null && categoryBydisposition.size() == 1) {
                String disposition = new List<String>(categoryBydisposition.keySet())[0];
                String category = categoryBydisposition.values()[0];
                if (String.isNotBlank(disposition) && String.isNotBlank(category)) {
                    if (sObjectName == 'Lead') {
                        listToUpdate.add(new Lead(Id = sObjectId, Status = category, SM_Lead_Disposition__c = disposition));
                    } else if (sObjectName == 'Opportunity') {
                        //validate opportunity stage
                        if(validateOpportunityStage(sObjectId)){
                            listToUpdate.add(new Opportunity(Id = sObjectId, StageName = category, SM_Opportunity_Disposition__c = disposition));
                        }
                    }
                }
            }
        }
        listToUpdate.sort();
        List<Database.SaveResult> sr = Database.update(listToUpdate);
        System.debug('sr: ' + sr);
    }

    // private static void getMetadataOld() {
    //     configBySObjectName = new Map<String, Map<String, String>>();
    //     for (SM_Category_and_Disposition__mdt record : [SELECT SM_SObject_Name__c, SM_Category__c, SM_Disposition__c, SM_Disposition_Five9__c FROM SM_Category_and_Disposition__mdt WHERE SM_Active__c = TRUE]) {
    //         if (!configBySObjectName.containsKey(record.SM_SObject_Name__c)) {
    //             configBySObjectName.put(record.SM_SObject_Name__c, new Map<String, String>());
    //         }
    //         configBySObjectName.get(record.SM_SObject_Name__c).put(record.SM_Disposition__c, record.SM_Category__c);
    //     }
    //     System.debug('configBySObjectName: ' + JSON.serialize(configBySObjectName));
    // }

    private static void getMetadata() {
        configBySObjectName = new Map<String, Map<String, Map<String, String>>>();
        for (SM_Category_and_Disposition__mdt record : [SELECT SM_SObject_Name__c, SM_Category__c, SM_Disposition__c, SM_Disposition_Five9__c FROM SM_Category_and_Disposition__mdt WHERE SM_Active__c = TRUE]) {
            if (!configBySObjectName.containsKey(record.SM_SObject_Name__c)) {
                configBySObjectName.put(record.SM_SObject_Name__c, new Map<String, Map<String, String>>());
            }
            // configBySObjectName.get(record.SM_SObject_Name__c).put(record.SM_Disposition__c, record.SM_Category__c);
            if (!configBySObjectName.get(record.SM_SObject_Name__c).containsKey(record.SM_Disposition_Five9__c)) {
                configBySObjectName.get(record.SM_SObject_Name__c).put(record.SM_Disposition_Five9__c, new Map<String, String>());
            }
            configBySObjectName.get(record.SM_SObject_Name__c).get(record.SM_Disposition_Five9__c).put(record.SM_Disposition__c, record.SM_Category__c);
        }
        // System.debug('configBySObjectName: ' + JSON.serialize(configBySObjectName));
    }

    /**
    * @description This method validate opportunity stage to update by five9
    * @author diego.jacanamijoy@gmail.com | 01-22-2021
    * @param oppId
    * @return Boolean
    **/
    private static Boolean validateOpportunityStage(String oppId){

        Opportunity opp = [SELECT StageName FROM Opportunity WHERE id =: oppId LIMIT 1];
        //Validae status of opportunity
        if(!oppNotValidStages.isEmpty() && oppNotValidStages.contains(opp.StageName)){
            return false;
        }
        return true;
    }

}