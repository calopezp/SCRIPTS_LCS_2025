public with sharing class SM_ACHPaymentProcessHandler {
    /**
    * @description This Method creates the AC records Specificly
    * @author srojas@legal-credit | 05-02-2021
    * @param sOIds 
    * @param Pmethods 
    **/
    static final String ACHPENDINGSTATUS = 'Pending';
    public static void CreateACOrderRecordsACH(List<String>  sOIds,List<Object> Pmethods,List<Object> chPtypes){
        
        List<SM_ACH_Order__c> ords = new List<SM_ACH_Order__c>();
        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        Set<String> setPM = new set<String>();
        System.debug(sOIds);
        if(sOIds.size()>0){
            structure.AdditionalFields = 'SM_Opportunity__r.SM_Company_Setting__c'
                                        +',SM_Payment_Method__r.SM_Chargent_Order__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,'
                                        +'SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,';
            structure.sObjectName = 'Contract';
            structure.subqueryObj = 'ACH_Orders__r';
            structure.whereClause = new map<String,List<object>>{'Id'=>(List<object>)sOIds};
            structure.childsWhereClause = new map<String,List<object>>{'SM_Payment_Type__c'=>chPtypes};
            structure.orderByParent ='';
            List<sObject> objs  = SM_Utils.getDynamicQuery(structure);

            set<String> companySettingId = new set<String>();
            sObject crRelationShip = null;
            Map<String,set<String>> requiredFields = new Map<String,set<String>>();
            
            System.debug(objs);
            if(objs.size()>0){
                System.debug(objs);
                for(sObject obj :objs){
                    crRelationShip = obj.getSObject('SM_Opportunity__r');
                    if(crRelationShip != null){
                        companySettingId.add(String.ValueOf(crRelationShip.get('SM_Company_Setting__c')));
                    }
                }
            }
            for(Object obj: Pmethods){
                setPM.add((String)obj);
            }
            if(companySettingId.size()>0){
                requiredFields =  SM_Utils.getRequiredFieldsByProcess('Contract', companySettingId,setPM);
                System.debug(requiredFields);
            }
            Map<String,Boolean> response = new Map<String,Boolean>();
            if(requiredFields.size()>0){
                
                system.debug('No error');
                response = validateMandatoryFields(requiredFields,objs);
                
                system.debug('No error');
            }
            system.debug(response);
            if(response.size()>0){
                for(Contract ctr: (List<Contract>)objs){
                    if(!response.get(ctr.Id) || ctr.ACH_Orders__r.size()>0){
                        continue;
                        
                    }
                    ords.addAll(createTMPRows(ctr));
                }
            }
            if(ords.size()>0){
                System.debug('entered to insert');
                insert ords;
                System.debug('out from insert');
            }
            
        }
    }


    /**
    * @description This method creates the Subscription records which are going to be charged when activating the contract
    * @author srojas@legal-credit | 05-02-2021
    * @param sOIds
    **/
    public static void CreateSubscriptionOrderRecordsACH(List<String>  sOIds){
        List<SM_ACH_Order__c> ords = new List<SM_ACH_Order__c>();
        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        if(sOIds.size()>0){
            structure.AdditionalFields = 'SM_Opportunity__r.SM_Company_Setting__c'
                                        +',SM_Payment_Method__r.SM_Chargent_Order__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,'
                                        +'SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,';
            structure.sObjectName = 'Contract';
            structure.subqueryObj = 'ACH_Orders__r';
            structure.whereClause = new map<String,List<object>>{'Id'=>(List<object>)sOIds};
            structure.childsWhereClause = new map<String,List<object>>{'SM_Payment_Type__c'=>new List<Object>{'Subscription'}};
            structure.orderByParent ='';
            List<sObject> objs  = SM_Utils.getDynamicQuery(structure);
            set<String> companySettingId = new set<String>();
            sObject crRelationShip = null;
            Map<String,Set<String>> requiredFields = new Map<String,Set<String>>();
            if(objs.size()>0){
                for(sObject obj :objs){
                    crRelationShip = obj.getSObject('SM_Opportunity__r');
                    if(crRelationShip != null){
                        companySettingId.add(String.ValueOf(crRelationShip.get('SM_Company_Setting__c')));
                    }
                }
            }
            if(companySettingId.size()>0){
                if(companySettingId.size()>0){
                    requiredFields =  SM_Utils.getRequiredFieldsByProcess('Contract', companySettingId,new Set<String>{'Subscription'});
                }
            }
            Map<String,Boolean> response = new Map<String,Boolean>();
            if(requiredFields.size()>0){
                response = validateMandatoryFields(requiredFields,objs);
            }
            if(response.size()>0){
                
                System.debug('entered ');
                for(Contract ctr: (List<Contract>)objs){
                    System.debug('entered ');
                    if(!response.get(ctr.Id) || ctr.ACH_Orders__r.size()>0){
                        System.debug('entered ');
                        continue;
                    }
                    
                    System.debug('entered ');
                    ords.addAll(createTMPRowsSubscription(ctr));
                }
            }
            if(ords.size()>0){
                insert ords;
            }
            
        }
    }
    /**
    * @description 
    * @author cjimenez -> cjimenez@legal-credit.com | 02/08/2022 
    * @param newContracts 
    **/
    public static void createAssetFeetBoundle(List<Contract>  newContracts){
        Map<Id,List<ChargentOrders__ChargentOrder__c>> contractOrders = new Map<Id,List<ChargentOrders__ChargentOrder__c>>();
        List<SM_Asset_Fee__c> allAssetFees = new List<SM_Asset_Fee__c>();
        List<String> contractMasterIds = new List<String>();
        List<String> sOIds = new List<String>();
        if(!newContracts.isEmpty()){
            Map<String,Set<String>> requiredFields = new Map<String,Set<String>>();
            for(Contract ctr:newContracts){
                if(ctr.Contract_Type__c == SM_ContractHelper.contractType.DEPENDENT && ctr.Principal_Contract__c != null){
                    contractMasterIds.add(ctr.Principal_Contract__c);
                    sOIds.add(ctr.id);
               }
            }  
        }
        Map<String,SM_ACH_Order__c> achOrderIdByContractId = new Map<String,SM_ACH_Order__c>();
        if(!contractMasterIds.isEmpty()){
            SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
            structure.AdditionalFields = 'SM_Opportunity__r.SM_Company_Setting__c'
                                        +',SM_Payment_Method__r.SM_Chargent_Order__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c'
                                        +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,'
                                        +'SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,';
            structure.sObjectName = 'Contract';
            structure.subqueryObj = 'ACH_Orders__r';
            structure.whereClause = new map<String,List<object>>{'Id'=>(List<object>)contractMasterIds};
            structure.childsWhereClause = new map<String,List<object>>();
            structure.orderByParent ='';
            List<String> lstPymentType = new List<String>();
            lstPymentType.add(SM_ACHOrderHelper.paymentType.SUBSCRIPTION);
            lstPymentType.add(SM_ACHOrderHelper.paymentType.FEE);
            List<sObject> objsDependent  = SM_Utils.getDynamicQuery(structure);
                if(!objsDependent.isEmpty()){
                    for(sObject obj :objsDependent){
                        Contract ctr =(Contract)obj;
                        for(SM_ACH_Order__c ACHOrder :ctr.ACH_Orders__r){
                            if(lstPymentType.contains(ACHOrder.SM_Payment_Type__c)){
                               achOrderIdByContractId.put(ACHOrder.SM_Contract__c,ACHOrder);
                            }
                        }
                    }
                }
        }
        Map<Id,List<SM_Asset_Fee__c>> assetFees = SM_ACHOrderHandler.createAssetFeesProcess(sOIds,achOrderIdByContractId);
        for(List<SM_Asset_Fee__c> fees: assetFees.values()){
            allAssetFees.addAll(fees);
        }
        if(!allAssetFees.isEmpty()){
           Database.insert(allAssetFees);
           SM_ACHOrderHandler.updateAssetsFee(achOrderIdByContractId.values(), null, true);
        }
    }

    /**
    * @description This method Validates the Fields that are required 
    * @author srojas@legal-credit | 05-02-2021
    * @param objs
    **/
    private static Map<String,Boolean> validateMandatoryFields(Map<String,set<String>> requiredFields,List<SObject> objs){
        Map<String,Boolean> resp = new Map<String,Boolean>();
        String crKey = '';
        String crCSetting = '';
        for(sObject obj : objs){
            crKey= String.ValueOf(obj.get('Id'));
            crCSetting = String.valueOf(obj.get('SM_Company_Setting__c'));
            if(requiredFields.containsKey(crCSetting)){
                System.debug(requiredFields.get(crCSetting));
                for(String required: requiredFields.get(crCSetting)){
                    if(obj.get(required) == null){
                        resp.put(crKey,false);
                        break;
                    }
                }
                if(!resp.containsKey(crKey)){
                    resp.put(crKey,true);
                }
                else{
                    Trigger.new[0].adderror(new ObjectException('Please Meake Sure That you filled the AC/Subscription information and that you\'ve filled al the ach fields in the payment method.'));
                }
            }
        }
        return resp;
    }

    public class ObjectException extends Exception {  
    }

    /**
    * @description This method will create the TMP Rows to add to a list
    * @author srojas@legal-credit | 05-02-2021
    * @param ctr
    **/
    private static List<SM_ACH_Order__c> createTMPRows(Contract ctr){
        System.debug('entered ');
        List<SM_ACH_Order__c> resp  = new List<SM_ACH_Order__c>();
        SM_ACH_Order__c tmpOrder = new SM_ACH_Order__c();
        Boolean isOneTime = false;
        if(ctr.SM_Requires_AC_Payment__c){
            System.debug('entered ');
            if(ctr.SM_Way_of_AC_Payment__c =='One payment'){
                isOneTime = true;
            }
            // CJ SMMCI 12/07/2022
            if(ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT && ctr.Principal_Contract__c == null){
                if(isOneTime){
                    tmpOrder.SM_Payment_Frequency__c = 'Once';
                    tmpOrder.SM_Payment_Method__c = ctr.SM_Payment_Method__c;
                    tmpOrder.SM_Billing_Email__c = ctr.SM_Email_to_send_contract__c;
                    tmpOrder.SM_Payment_Status__c = ACHPENDINGSTATUS;
                    tmpOrder.SM_Payment_Count__c = 1;
                    tmpOrder.SM_Payment_Start_Date__c = ctr.SM_AC_start_date__c;
                    tmpOrder.SM_Next_Transaction_Date__c = ctr.SM_AC_start_date__c;
                    tmpOrder.SM_Payment_End_Date__c = ctr.SM_AC_start_date__c;
                    tmpOrder.SM_Total__c = ctr.SM_Total_AC__c;
                    tmpOrder.SM_Payment_Type__c = 'AC';
                    tmpOrder.SM_Contract__c = ctr.Id;
                    resp.add(tmpOrder);
                }
                else{
                    System.debug('entered ');
                    double amount = ctr.SM_Total_AC__c/2;
                    System.debug('entered '+amount);
                    for(Integer i = 0; i<2;i++){
                        System.debug('entered '+i);
                        tmpOrder = new SM_ACH_Order__c();
                        tmpOrder.SM_Payment_Frequency__c = 'Once';
                        tmpOrder.SM_Payment_Method__c = ctr.SM_Payment_Method__c;
                        tmpOrder.SM_Billing_Email__c = ctr.SM_Email_to_send_contract__c;
                        tmpOrder.SM_Payment_Status__c = ACHPENDINGSTATUS;
                        tmpOrder.SM_Payment_Count__c = 1;
                        tmpOrder.SM_Payment_Start_Date__c = ctr.SM_AC_start_date__c;
                        tmpOrder.SM_Next_Transaction_Date__c = ctr.SM_AC_start_date__c;
                        tmpOrder.SM_Payment_End_Date__c = ctr.SM_AC_start_date__c;
                        tmpOrder.SM_Total__c = amount;
                        tmpOrder.SM_Payment_Type__c = 'AC';
                        tmpOrder.SM_Contract__c = ctr.Id;
                        ctr.SM_AC_start_date__c = ctr.SM_AC_Split_Date__c;
                        resp.add(tmpOrder);
                    }                
                }
            }
        }
        return resp;
    }

    /**
    * @description This method creates a list member for subscription
    * @author srojas@legal-credit | 05-02-2021
    * @param ctr
    **/
    private static List<SM_ACH_Order__c> createTMPRowsSubscription(Contract ctr){
        List<SM_ACH_Order__c> resp  = new List<SM_ACH_Order__c>();
        SM_ACH_Order__c tmpOrder = new SM_ACH_Order__c();
        Boolean isOneTime = false;
        Date startDate = ctr.SM_Start_date__c;
        // CJ SMMCI 12/07/2022
        if(ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT && ctr.Principal_Contract__c == null){
            if(ctr.SM_Requires_RC_Payment__c && ctr.SM_Way_of_Contract_Payment__c == 'Subscription'){
                tmpOrder.SM_Payment_Frequency__c = ctr.SM_Frecuency__c;
                tmpOrder.SM_Payment_Method__c = ctr.SM_Payment_Method__c;
                tmpOrder.SM_Billing_Email__c = ctr.SM_Email_to_send_contract__c;
                tmpOrder.SM_Payment_Status__c = ACHPENDINGSTATUS;
                tmpOrder.SM_Total__c = ctr.SM_Monthly_offer__c;//To Remove I didn't find the Field To take the Amount for the AC
                tmpOrder.SM_Payment_Type__c = 'Subscription';
                tmpOrder.SM_Contract__c = ctr.Id;
                tmpOrder.SM_Payment_Start_Date__c = ctr.SM_Start_date__c;
                tmpOrder.SM_Next_Transaction_Date__c = ctr.SM_Start_date__c;
                resp.add(tmpOrder);
            }
            if(ctr.SM_Requires_RC_Payment__c && ctr.SM_Way_of_Contract_Payment__c == 'Fix Term'){
                double amount = ctr.SM_Monthly_offer__c/ctr.SM_Plan_Months__c;
                tmpOrder.SM_Payment_Frequency__c = 'Monthly';
                tmpOrder.SM_Payment_Method__c = ctr.SM_Payment_Method__c;
                tmpOrder.SM_Billing_Email__c = ctr.SM_Email_to_send_contract__c;
                tmpOrder.SM_Payment_Status__c = ACHPENDINGSTATUS;
                tmpOrder.SM_Payment_Count__c = 1;
                tmpOrder.SM_Payment_Start_Date__c = ctr.SM_Start_date__c;
                tmpOrder.SM_Total__c = ctr.SM_Monthly_offer__c;
                tmpOrder.SM_Payment_Type__c = 'Fee';
                tmpOrder.SM_Contract__c = ctr.Id;
                tmpOrder.SM_Quantity_of_scheduled_fees__c = ctr.SM_Plan_Months__c;
                Date endDate = null;
                if(ctr.SM_Frecuency__c =='Daily'){
                    endDate = ctr.SM_Start_date__c.addDays(ctr.SM_Plan_Months__c.intValue());
                }
                if(ctr.SM_Frecuency__c =='Biweekly'){
                    endDate = ctr.SM_Start_date__c.addDays((ctr.SM_Plan_Months__c*14).intValue());
                }
                if(ctr.SM_Frecuency__c =='Monthly'){
                    endDate = ctr.SM_Start_date__c.addMonths(ctr.SM_Plan_Months__c.intValue());
                }
                if(ctr.SM_Frecuency__c =='Weekly'){
                    endDate = ctr.SM_Start_date__c.addMonths((ctr.SM_Plan_Months__c*7).intValue());
                }
                tmpOrder.SM_Next_Transaction_Date__c = ctr.SM_Start_date__c;
                tmpOrder.SM_Payment_End_Date__c = endDate;
                resp.add(tmpOrder);
            } 
        }
    return resp;
    }
}