/**
 * @description       : Class with utils methods
 * @author            : diego.jacanamijoy@gmail.com
 * @group             : 
9 * @last modified on  : 01-18-2021
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-17-2020   diego.jacanamijoy@gmail.com   Initial Version
**/
public with sharing class SM_Utils {
    
    /**
    * @description This method return sobject name by record id
    * @author diego.jacanamijoy@gmail.com | 11-17-2020 
    * @param recordId 
    * @return String 
    **/
    public static String getSObjectNameById(Id recordId){
        String sObjectName;
        try {
            sObjectName = recordId.getSObjectType().getDescribe().getName();
        } catch (Exception e) {
            sObjectName = '';
        }
        return sObjectName;
    }

    public static SObject createSObject(String sObjectName) {
        return Schema.getGlobalDescribe().get(sObjectName).newSObject() ;
    }

    // Id devRecordTypeId = 
    public static String getRecordTypeIdByDeveloperName(String sObjectName, String recordTypeName) {
        return Schema.getGlobalDescribe().get(sObjectName).getDescribe().getRecordTypeInfosByName().get(recordTypeName).getRecordTypeId();
    }

	/**
	* Check if a value field has changed
	* @param SObject, old SObject, FieldName
	* @return Boolean
	*/
	public static Boolean isChangedField(SObject so, SObject oldSo, String fieldName){
		return oldSo == null || (so.get(fieldName) != oldSo.get(fieldName));
	}

	public static Boolean isChangedField(Sobject so, Sobject oldSo, String[] fieldNames){
		for(String field : fieldNames){
			if(isChangedField(so,oldSo,field)){
				return true;
			}
		}

		return false;
	}

    public static List<String> getFieldsFromFieldSet(String sObjectName, String fieldSetName) {
        Set<String> fields = new Set<String>();
        Schema.FieldSet fieldSetObj = Schema.getGlobalDescribe().get(sObjectName).getDescribe().FieldSets.getMap().get(fieldSetName);
        if(fieldSetObj <> null){
            for (Schema.FieldSetMember field : fieldSetObj.getFields()) {
                fields.add(field.getFieldPath());
            }
        }
        return new List<String>(fields);
    }

    /**
    * @description This method validate if exist field in sobject
    * @author diego.jacanamijoy@gmail.com | 12-09-2020 
    * @param sObjectName 
    * @param fieldName 
    * @return Boolean 
    **/
    public static Boolean validateIfExistFieldBySObject(String sObjectName, String fieldName){
        Map<String,Schema.SObjectField> fieldsBySObject = Schema.getGlobalDescribe().get(sObjectName).getDescribe().fields.getMap();
        return fieldsBySObject.containsKey(fieldName);
    }

    /**
    * @description This method formate phone field
    * @author diego.jacanamijoy@gmail.com | 01-18-2021 
    * @param phone 
    * @return String 
    **/
    public static String formatPhone(String phone){
        return phone.replaceAll('[^0-9]','');
    }

    /*
        @Author : Santiago Rojas
        @BuiltDate : 30-01-2021
        @Description : Get's a dynamic Query Based on the params
        @params : DynamicQueryStructure data
    */
    public static List<sObject> getDynamicQuery(DynamicQueryStructure data){
        // This is the object for which we required data.
        SObjectType rType = ((SObject)(Type.forName('Schema.'+data.sObjectName).newInstance())).getSObjectType();
        List<Schema.ChildRelationship> directRelationShip = null;
        DescribeSObjectResult dRes = rType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = dRes.fields.getMap();
        if(data.subqueryObj != null){
            directRelationShip = new List<Schema.ChildRelationship>();
            String [] subqueries = data.subqueryObj.split(',');
            for(String subquery: subqueries){
                for(Schema.ChildRelationship child: dRes.getChildRelationships()){
                    if(child.getRelationshipName() == subquery){
                        directRelationShip.add(child);
                    }
                }
            }
        }
        
        String subqueries = '';
        if(directRelationShip!= null &&directRelationShip.size()>0){
            subqueries = ','+createSubqueries(directRelationShip,data);
        }
        // Get all of the fields on the object
        set<String> fieldNames = fieldMap.keySet();
        // Build a Dyn amic Query String.
        List<sObject> sObjs  = new List<Sobject>();
        String wherecls = createWhereClause(data,false);
        if(fieldNames.Size()>0){
            String query = 'SELECT '+ data.AdditionalFields+ string.join((Iterable<String>)fieldNames, ',') + subqueries+ ' FROM ';
            query+= String.escapeSingleQuotes(data.sObjectName)+' '+ wherecls +' '+ data.orderByParent;
            System.debug('query: ' + query);
            sObjs = Database.query(query);
        }
        return sObjs;
    }


    private static String createSubqueries(List<Schema.ChildRelationship> subQueries,DynamicQueryStructure data){
        set<String> fieldNames = null;
        Map<String, Schema.SObjectField> fieldMap = null;
        DescribeSObjectResult dRes = null;
        String returnedQuery = '';
        String crRelationShip = '';
        String crOrderBy = '';
        for(Schema.ChildRelationship child: subQueries){
            crRelationShip = child.getRelationshipName();
            dRes = child.getChildSObject().getDescribe();
            if(data.orderByChild != null){
                if(data.orderByChild.containsKey(crRelationShip)){
                    crOrderBy = data.orderByChild.get(crRelationShip);
                }
                else{
                    crOrderBy = '';
                }
            }
            String wherecls = createWhereClause(data,true);
            fieldMap = dRes.fields.getMap();
            fieldNames = fieldMap.keySet();
            ReturnedQuery += '( SELECT '+string.join((Iterable<String>)fieldNames, ',');
            ReturnedQuery += ' FROM '+child.getRelationshipName()+' '+ wherecls +' '+crOrderBy+'),';       
        }
        ReturnedQuery = ReturnedQuery.removeEnd(',');
        return ReturnedQuery;
    }

    private static String createWhereClause(DynamicQueryStructure data, Boolean isChildObj){
        String wherecls = '';
        if(isChildObj){
            if(!data.childsWhereClause.isEmpty()){
                wherecls='WHERE ';
                for(String key : data.childsWhereClause.keySet()){
                    wherecls+=key+' in(\''+String.escapeSingleQuotes(String.join((Iterable<String>)data.childsWhereClause.get(key),'\',\''))+'\') AND ';
                }
                wherecls = wherecls.Substring(0,wherecls.length()-4);
            }
        }
        else{
            if(!data.whereClause.isEmpty()){
                wherecls='WHERE ';
                for(String key : data.whereClause.keySet()){
                    wherecls+=key+' in(\''+String.escapeSingleQuotes(String.join((Iterable<String>)data.whereClause.get(key),'\',\''))+'\') AND ';
                }
                wherecls = wherecls.Substring(0,wherecls.length()-4);
                wherecls = wherecls.replace('\\', '');
            }
        }
        system.debug(wherecls);
        return wherecls;
    }
    
    @InvocableMethod(label='Insert/update Payment Methods' description='Inserts or updates a payment method' category= 'ChargentOrder')
    public static void createOrUpdatePayment(List<ChargentOrders__ChargentOrder__c> obj){
        System.debug('ENTERED');
        System.debug('obj: ' + JSON.serialize(obj));
        SM_Payment_Method__c tmpPaymentMethod =  new SM_Payment_Method__c();
        Map<Id,SM_Payment_Method__c> insertedPM =  new Map<Id,SM_Payment_Method__c>();
        Map<String,SM_Payment_Method__c> toUpdatePM =  new Map<String,SM_Payment_Method__c>();
        Map<String,SM_Payment_Method__c> existingPM =  new Map<String,SM_Payment_Method__c>();//String Concat Key Map.
        Map<String,SM_Payment_Method__c> existingPMs =  new Map<String,SM_Payment_Method__c>();//ContractId Key Map.
        List<SM_Payment_Method__c> pMethods =  new List<SM_Payment_Method__c>();
        Schema.SObjectType pMethod = Schema.getGlobalDescribe().get('SM_Payment_Method__c');
        Set<Id> ctrIds = new Set<Id>();
        Set<Id> AccIds = new Set<Id>();
        Set<Id> orderIds = new Set<Id>();
        map<Id,Contract> contracts =  new  map<Id,Contract>();
        Contract tmpctr = new Contract();
        for(ChargentOrders__ChargentOrder__c ord: obj){
            ctrIds.add(ord.Contract__c);
            orderIds.add(ord.Id);

        }
        contracts = new Map<Id,Contract>([SELECT ID,AccountID FROM Contract where id=: ctrIds]);
        for(Contract ctrTMP: contracts.values()){
            AccIds.add(ctrTMP.AccountId);
        }
        String Key = '';
        String tmpcardNum ='';
        for(SM_Payment_Method__c pm:[
                SELECT ID,SM_Account__c,SM_Credit_Card_Franchise__c,SM_Credit_Card_Name__c,SM_Credit_Card_Number__c 
                FROM SM_Payment_Method__c 
                WHERE SM_Account__c=:AccIds
            ]){
                if(pm.SM_Credit_Card_Number__c != null){
                    tmpcardNum = pm.SM_Credit_Card_Number__c.right(4);//return last 4 digits DAJC 21/07/2021
                    Key =  pm.SM_Credit_Card_Franchise__c+'-'+pm.SM_Credit_Card_Name__c+'-'+tmpcardNum;
                    existingPM.put(Key,pm);
                }
        }
        Map<Id,ChargentOrders__Transaction__c> ordTransct = new Map<Id,ChargentOrders__Transaction__c>();
        List<ChargentOrders__Transaction__c> aprovedTRs = [SELECT ID,ChargentOrders__Order__c FROM ChargentOrders__Transaction__c WHERE ChargentOrders__Order__c=:orderIds ORDER BY createdDate DESC];
        for(ChargentOrders__Transaction__c aprovedTR: aprovedTRs){
            if(!ordTransct.containsKey(aprovedTR.ChargentOrders__Order__c)){
                ordTransct.put(aprovedTR.ChargentOrders__Order__c,aprovedTR);
            }
        }
        for(ChargentOrders__ChargentOrder__c ord: obj){
            if(ordTransct.containskey(ord.Id)){
                tmpctr = contracts.get(ord.contract__c);
                String keyObj = ord.ChargentOrders__Card_Type__c+'-'+ord.ChargentOrders__Credit_Card_Name__c+'-'+ord.ChargentOrders__Card_Last_4__c;
                if(existingPM.containsKey(keyObj)){
                    tmpPaymentMethod = existingPM.get(keyObj);
                    tmpPaymentMethod.SM_Card_Token__c = ord.ChargentOrders__Tokenization__c;
                    tmpPaymentMethod.SM_Chargent_Order__c = ord.Id;
                    existingPMs.put(tmpctr.Id,tmpPaymentMethod);
                    toUpdatePM.put(tmpctr.Id,tmpPaymentMethod);
                    continue;
                }
                tmpPaymentMethod = new SM_Payment_Method__c();
                tmpPaymentMethod.recordTypeId = pMethod.getDescribe().getRecordTypeInfosByDeveloperName().get('Credit_Card').getRecordTypeId();
                tmpPaymentMethod.SM_Account__c = tmpctr.AccountId;
                tmpPaymentMethod.SM_Chargent_Order__c = ord.Id;
                tmpPaymentMethod.SM_Credit_Card_expiration_year__c = ord.ChargentOrders__Card_Year_Indicator__c;
                tmpPaymentMethod.SM_Credit_Card_expiration_month__c = ord.ChargentOrders__Card_Month_Indicator__c;
                tmpPaymentMethod.SM_Credit_Card_Number__c = '**** **** **** '+ord.ChargentOrders__Card_Last_4__c;
                tmpPaymentMethod.SM_Credit_Card_Franchise__c = ord.ChargentOrders__Card_Type__c;
                tmpPaymentMethod.SM_Credit_Card_Name__c = ord.ChargentOrders__Credit_Card_Name__c;
                tmpPaymentMethod.SM_Card_Token__c = ord.ChargentOrders__Tokenization__c;
                tmpctr.SM_Registered_Card_Token__c = ord.ChargentOrders__Tokenization__c;
                insertedPM.put(tmpctr.Id,tmpPaymentMethod);
            }
            
        }
        System.debug('insertedPM: ' + insertedPM);
        if(insertedPM.size()> 0){
            insert insertedPM.values();
        }
        if(contracts.size()> 0){
            for(Contract ctr: contracts.values()){
                if(insertedPM.containsKey(ctr.Id)){
                    ctr.SM_Payment_Method__c = insertedPM.get(ctr.Id).Id;
                }
                else if(existingPMs.containsKey(ctr.Id)){
                    ctr.SM_Payment_Method__c = existingPMs.get(ctr.Id).Id;
                }
            }
            update contracts.values();
        }
        System.debug('toUpdatePM: ' + toUpdatePM);
        if(toUpdatePM.size()>0){
            update toUpdatePM.values();
        }
    }

    public class DynamicQueryStructure{
        public String sObjectName{get;set;}
        public String subqueryObj{get;set;}
        public map<String,list<object>> whereClause{get;set;}
        public map<String,list<object>> childsWhereClause{get;set;}
        public String AdditionalFields{get;set;}
        public String orderByParent{get;set;}
        public Map<String,String> orderByChild{get;set;}
    }


    /**
     * @description This method return required fields by source object and process name
     * @author jpachon@legal-credit.com | 02-14-2020 
     * @param sourceObject | String
     * @param processNames | Set<String>
     * @return requiredFields | Set<String>
     * TODO: Create a generic method to validate required fields from any object
    **/
    public static Map<String, Set<String>> getRequiredFieldsByProcess(String sourceObject, Set<String> companySettingIds, Set<String> processNames) {
        Map<String, Set<String>> requiredFieldsByCompanySetting = new Map<String, Set<String>>();
        for (SM_Required_Field_Info__c record : [SELECT Id, SM_Company_Setting__c, SM_Api_Field_Name__c 
                                                    FROM SM_Required_Field_Info__c 
                                                    WHERE SM_Source_Object__c =: sourceObject 
                                                    AND SM_Company_Setting__c IN: companySettingIds 
                                                    AND SM_Process__c IN: processNames]) {
            // requiredFields.add(record.SM_Api_Field_Name__c);
            if (!requiredFieldsByCompanySetting.containsKey(record.SM_Company_Setting__c)) {
                requiredFieldsByCompanySetting.put(record.SM_Company_Setting__c, new Set<String>());
            }
            requiredFieldsByCompanySetting.get(record.SM_Company_Setting__c).add(record.SM_Api_Field_Name__c);
        }
        return requiredFieldsByCompanySetting;
    }
      /**
     * @description This method return required fields by source object and process name
     * @author cjimenez@legal-credit.com | 06-11-2021 
     * @param nameBusiness,dateValidate
     * @return CompanybusinessDay
     * TODO: Create a generic method to validate business days
    **/
    public static BusinessHours  getBusinessHour(String nameBusiness) {
         BusinessHours bHours = [SELECT Id FROM BusinessHours WHERE Name =: nameBusiness];
         return bHours;
    }
    /**
     * @description This method return required fields by source object and process name
     * @author cjimenez@legal-credit.com | 06-11-2021 
     * @param nameBusiness,dateValidate
     * @return CompanybusinessDay
     * TODO: Create a generic method to validate business days
    **/
    public static CompanybusinessDay getSuggestedBusinessHour(BusinessHours bHours,DateTime dateValidate) {
        CompanybusinessDay companybusinessDay=new CompanybusinessDay();
        Boolean isPreviusDate=false;
        DateTime previusDate=null;
        if(BusinessHours.isWithin(bHours.Id, dateValidate)){
           companybusinessDay.businessDay=false;
           companybusinessDay.newDate=null;
           companybusinessDay.changeDetail='';
           return companybusinessDay;
        }else{
            Integer count = 0;
            previusDate=dateValidate;
            DateTime toDay=System.now();
            while(previusDate.date() > toDay.date()){
                  previusDate=previusDate.addDays(-1);
                if(BusinessHours.isWithin(bHours.Id, previusDate) && previusDate.date() != toDay.date()){
                   isPreviusDate=true;
                   break;
                }
            }
        } 
        companybusinessDay.businessDay=true;
        DateTime newDate= isPreviusDate == true ? previusDate.date() : BusinessHours.nextStartDate(bHours.Id, dateValidate).date();  
        companybusinessDay.newDate= isPreviusDate == true ? previusDate.date() : BusinessHours.nextStartDate(bHours.Id, dateValidate).date();  
        //companybusinessDay.changeDetail= isPreviusDate == true ? SM_InvoiceHelper.logDateChange.CHANGE_PREVIOUS_BUSINESS : SM_InvoiceHelper.logDateChange.CHANGE_LATER_BUSINESS; 
        
        return companybusinessDay;
   }

    /**
    * @description This method return all editable fields by sobect name
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    * @param SObjectName 
    * @return List<String> 
    **/
    public static List<String> getAllEditableFieldsBySObject(String SObjectName){

        List<String> fields = new List<String>();

        Map<String, SObjectField> fieldsMap = Schema.describeSObjects(new List<String>{
            SObjectName
        }).get(0).fields.getMap();

        for (String fieldName : fieldsMap.keySet()) {
            
            DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();

            if (fieldDescribe.isUpdateable()) {
                fields.add(fieldDescribe.getName());
            }
        }

        return fields;
    }

 /**
     * @description This class gets the business day
     * @author cjimenez@legal-credit.com | 06-11-2021 
     * @param businessDay,businessDay,businessDay  
    **/
    public class CompanybusinessDay{
        public Boolean businessDay {get;set;}
        public Date newDate  {get;set;}
        public String changeDetail {get;set;}
    }


}