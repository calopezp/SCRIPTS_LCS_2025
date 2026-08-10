/**
 * @description       : Class controller Update contracts depended
 * @author            : cjimenez@legal-credit.com
 * @group             : 
 * @last modified on  : 14-10-2022
 * @last modified by  : Camilo jimenez -> cjimenez@legal-credit.com
 * 1.0   14-10-2022     cjimenez@legal-credit.com   Initial Version
**/
public with sharing class SM_UpdateContractsController {
    /**
    * @description This Update contracts depended
    * @author Camilo Jimenez | 22-09-2022
    * @param idContract
    **/
    @AuraEnabled
    public static Boolean updateContracts(String idContract){
        Boolean isSuccess = false;
        List<Contract> lstCtrDependedUpdate = new List<Contract>();
        try {
            SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
            structure.sObjectName = 'Contract';
            structure.whereClause = new map<String,List<object>>{'Id'=>new List<object>{idContract}};
            structure.orderByParent = '';
            structure.AdditionalFields = '';
            map<Id,SObject> idsByContract  = new Map<Id,SObject>(SM_Utils.getDynamicQuery(structure));
            Contract ctrDepended = (Contract)idsByContract.get(idContract);
            List<SM_Simultaneous_Contract_Updates__c> lstSimultaneousContract = [SELECT ID,SM_ProcessAutomationByProductFamily__c,SM_TypesContractsUpdated__c,
                                                                                        SM_Object__c,SM_FieldName__c
                                                                                 FROM SM_Simultaneous_Contract_Updates__c 
                                                                                 WHERE SM_ProcessAutomationByProductFamily__c =: ctrDepended.SM_Process_automation_by_product_family__c ];
            if(!lstSimultaneousContract.isEmpty()){      

                Contract ctrMaster = [SELECT ID,(SELECT ID,Contract_activation_form__c FROM Contracts1__r WHERE ID !=: idContract)
                                      FROM Contract
                                      WHERE ID =: ctrDepended.Principal_Contract__c ];  
                                
                if(ctrMaster != null && !ctrMaster.Contracts1__r.isEmpty()){
                    for(Contract contraDepended : ctrMaster.Contracts1__r){
                        for(SM_Simultaneous_Contract_Updates__c simultaneousContract: lstSimultaneousContract){
                            if(contraDepended.Contract_activation_form__c == simultaneousContract.SM_TypesContractsUpdated__c && 
                                ctrDepended.get(simultaneousContract.SM_FieldName__c) != null){
                                contraDepended.put(simultaneousContract.SM_FieldName__c,ctrDepended.get(simultaneousContract.SM_FieldName__c));           
                            }
                        }
                    lstCtrDependedUpdate.add(contraDepended);
                    }
                }
                if(!lstCtrDependedUpdate.isEmpty()){
                    Database.update(lstCtrDependedUpdate);
                }
                isSuccess = true;
                return isSuccess;
            }else {
                return isSuccess;
            }    
        } catch (Exception e) {
            system.debug('Error-->'+e.getMessage());
            return isSuccess;
        }
       
    }
}