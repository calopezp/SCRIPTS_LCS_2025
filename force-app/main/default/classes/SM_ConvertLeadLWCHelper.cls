/**
 * @description       : Helper class of convert lead process from button on lead object
 * @author            : jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 09-06-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   12-03-2020   jpachon@legal-credit.com   Initial Version
**/
public without sharing class SM_ConvertLeadLWCHelper {

    private static Set<String> fieldsToQuery;

    public static Lead getInfoLead(String leadId) {
        getCustomFields();
        return getLead(leadId);
    }

    private static void getCustomFields() {
        fieldsToQuery = new Set<String>();
        // Query metadata to validate what fields should be querying on Lead SObject
        List<SM_FieldsForAccountSearch__mdt> fields = [SELECT SM_Lead_field__c, SM_Account_field__c FROM SM_FieldsForAccountSearch__mdt];
        for (SM_FieldsForAccountSearch__mdt field : fields) {
            fieldsToQuery.add(field.SM_Lead_field__c);
        }
        fieldsToQuery.add('SM_Destination_business_unit__c');
        fieldsToQuery.add('SM_Company_Setting__c');
    }

    private static Lead getLead(String leadId) {
        Lead record;
        if (!fieldsToQuery.isEmpty()) {
            String queryStr = String.format('SELECT {0}, SM_ManuallyCreated__c, Name FROM Lead WHERE Id =: leadId', new List<String>{String.join(new List<String>(fieldsToQuery), ',')});
            System.debug('queryStr: ' + queryStr);
            record = Database.query(queryStr);
        }
        return record;
    }

    public static List<Account> getDuplicatesAccountsByLead(Lead record) {
        SM_AccountDuplicateController accDuplicateCtr = new SM_AccountDuplicateController();
        Map<Lead, Set<Account>> accounts = accDuplicateCtr.getDuplicatesAccountsByLead(new List<Lead>{record});
        return new List<Account>(accounts.get(record));
    }

    public static Map<String, String> getFieldsMappingToConvertRecord(String companySettingId, String sourceObject, String targetObject) {
        List<SM_Conversion_Fields_Mapping__c> fieldsMapping = [SELECT SM_Source_Field__c, SM_Target_Field__c
                                                            FROM SM_Conversion_Fields_Mapping__c 
                                                            WHERE SM_Company_Setting__c =: companySettingId 
                                                            AND SM_Source_Object__c =: sourceObject 
                                                            AND SM_Target_Object__c =: targetObject];
        Map<String, String> fieldsToMap = new Map<String, String>();
        for (SM_Conversion_Fields_Mapping__c fieldMapping : fieldsMapping) {
            fieldsToMap.put(fieldMapping.SM_Source_Field__c, fieldMapping.SM_Target_Field__c);
        }
        System.debug('fieldsToMap: ' + JSON.serialize(fieldsToMap));
        return fieldsToMap;
    }

    public static Account createAccount(String leadId, Map<String,String> leadToAccountMap) {
        fieldsToQuery = new Set<String>();
        fieldsToQuery.addAll(leadToAccountMap.keySet());
        Lead leadToConvert = getLead(leadId);
        SObject newAccount = SM_Utils.createSObject('Account');
        fillFields('Lead', (SObject)leadToConvert, 'Account', newAccount, leadToAccountMap);
        newAccount.put('RecordTypeId', SM_Utils.getRecordTypeIdByDeveloperName('Account', 'Person Account'));
        System.debug('newAccount: ' + JSON.serialize(newAccount));
        return (Account)newAccount;
    }

    public static Opportunity createOpportunity(String leadId, String accountId, String companySettingId, Map<String,String> leadToOppMap) {
        fieldsToQuery = new Set<String>();
        fieldsToQuery.addAll(leadToOppMap.keySet());
        Lead leadToConvert = getLead(leadId);
        SObject newOpp = SM_Utils.createSObject('Opportunity');
        if (!leadToOppMap.isEmpty()) {
            fillFields('lead', (SObject)leadToConvert, 'Opportunity', newOpp, leadToOppMap);
        }
        fillAditionalFields(newOpp, accountId, companySettingId);
        System.debug('newOpp: ' + JSON.serialize(newOpp));
        return (Opportunity)newOpp;
    }

    public static List<SM_Tracking_Inbound__c> getTrackingInboundToUpdate(String leadId, String accountId) {
        List<SM_Tracking_Inbound__c> recordsToUpdate = [SELECT Id, SM_AccountId__c FROM SM_Tracking_Inbound__c WHERE SM_LeadId__c =: leadId AND SM_AccountId__c = NULL];
        for (SM_Tracking_Inbound__c record : recordsToUpdate) {
            record.SM_AccountId__c = accountId;
        }            
        return recordsToUpdate;
    }

    @TestVisible
    private static void fillFields(String sourceObjName, SObject sourceSObject, String targetObjName, SObject targetSObject, Map<String,String> fieldsMapping) {
        Map<String, Schema.SObjectField> fieldMapSourceObject = Schema.getGlobalDescribe().get(String.valueOf(sourceObjName)).getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> fieldMapTargetObject = Schema.getGlobalDescribe().get(String.valueOf(targetObjName)).getDescribe().fields.getMap();
        String fieldValueTemp = '';
        for (String sourceField : fieldsMapping.keySet()) {
            Schema.DisplayType fieldTypeSourceObj = fieldMapSourceObject.get(sourceField).getDescribe().getType();
            Schema.DisplayType fieldTypeTargetObj = fieldMapTargetObject.get(fieldsMapping.get(sourceField)).getDescribe().getType();
            if (fieldTypeSourceObj == fieldTypeTargetObj) {
                // Get value of source object to put into field target object
                targetSObject.put(fieldsMapping.get(sourceField), sourceSObject.get(sourceField));
            } else {
                System.debug(String.format('Source field (type): {0} ({1}) - Target field (type): {2} ({3})', new List<String>{sourceField, String.valueOf(fieldTypeSourceObj), fieldsMapping.get(sourceField), String.valueOf(fieldTypeTargetObj)}));
            }
        }
    }

    @TestVisible
    private static void fillAditionalFields(SObject newOpp, String accountId, String companySettingId) {
        // Cjimenez 21-02-2021 SFDCMP-136
        Account account = [SELECT ID,NAME, SM_Customer_Number__pc FROM Account where ID =: accountId ];
        Date closeDateName=System.today().addMonths(1);
        String name=account.name+'_'+account.SM_Customer_Number__pc+'_'+closeDateName.format();
        newOpp.put('Name', name);
        newOpp.put('CloseDate', System.today().addMonths(1));
        newOpp.put('StageName', 'New');
        newOpp.put('RecordTypeId', SM_Utils.getRecordTypeIdByDeveloperName('Opportunity', SM_OpportunityHelper.recordType.legalCreditSolutions));
        newOpp.put('AccountId', accountId);
        newOpp.put('SM_Company_Setting__c', companySettingId);
        // JSPA - 01-13-21 - SFDCMP-65
        newOpp.put('SM_Conversion_opportunity__c', true);
    }

    /**
    * @description This method related data from Lead to Opportunity
    * @author diego.jacanamijoy@gmail.com | 01-28-2021 
    * @param leadId 
    * @param opportunityId 
    **/
    public static void copyLeadDataToOpportunity(String leadId, String opportunityId){
        //New documentLinks related to oportunity
        List<ContentDocumentLink> newsDocumentsLinks = new List<ContentDocumentLink>();
        //Get contentDocuments related to Lead
        List<ContentDocumentLink> documentsLinks = [SELECT ContentDocumentId FROM ContentDocumentLink where LinkedEntityId =: leadId WITH SECURITY_ENFORCED];
        //Iterate contentdocuments by created realteds to opportunity
        for(ContentDocumentLink documentLink: [SELECT ContentDocumentId FROM ContentDocumentLink where LinkedEntityId =: leadId]){
            newsDocumentsLinks.add( new ContentDocumentLink(ContentDocumentId = documentLink.ContentDocumentId, LinkedEntityId = opportunityId) );
        }
        //Query to get lead info, related tasks and events
        // String leadQuery = 'SELECT Id, (SELECT WhatId FROM Tasks), (SELECT WhatId FROM Events) FROM Lead WHERE Id = \'' + leadId + '\'';
        // JSPA - 09/06/2021 - Case 00001037
        String leadQuery = 'SELECT Id, (SELECT WhatId FROM Tasks WHERE IsRecurrence = FALSE), (SELECT WhatId FROM Events) FROM Lead WHERE Id = \'' + leadId + '\'';
        //Execute query
        Lead lead = SM_LeadHelper.getLeasByDinamicQuery(leadQuery)[0];
        //Validate if exists tasks, for change realted to opportunity
        for(task task: lead.Tasks){
            task.WhatId = opportunityId;
            task.WhoId = null;
        }
        //Validate if exists events, for change realted to opportunity
        for(Event event: lead.Events){
            event.WhatId = opportunityId;
            event.WhoId = null;
        }
        //Updates
        if(!lead.Tasks.isEmpty()){
            update lead.Tasks;
        }

        if(!lead.Events.isEmpty()){
            update lead.Events;
        }

        //Inserts
        if(newsDocumentsLinks.isEmpty()){
            insert newsDocumentsLinks;
        }
    }

}