/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-09-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   06-09-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
public with sharing class SM_AgreementHandler extends SM_TriggerHandler{

    /* Static variables*/
    public static List<Contract> contracts;

    public SM_AgreementHandler(String triggerName){
        super(triggerName);
    }

    /************* Overwrite DML methods *************/
    override public void afterUpdate(){
        try {
            validateChangeStatus(Trigger.new, Trigger.oldMap);
        } catch (Exception e) {
            System.debug('An error occurred in asyncAfterUpdate agreement  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
        }
    }

    /**
     * description this method validate Change Status and update contract
     * @autor camilo.jimenez@publicar.com
     * @param updateEchosign_dev1__SIGN_Agreement__c
	**/
    public static void validateChangeStatus(List<echosign_dev1__SIGN_Agreement__c> newAgreements, Map<id, SObject> oldAgreementMap){
        List <String> lstFieldName =new  List <String>();
        lstFieldName.add('echosign_dev1__Status__c');
        contracts = new List<contract>();
        for(echosign_dev1__SIGN_Agreement__c newAgreement: newAgreements){
            echosign_dev1__SIGN_Agreement__c oldAgreement = (echosign_dev1__SIGN_Agreement__c) oldAgreementMap.get(newAgreement.Id);
            if(SM_Utils.isChangedField(newAgreement, oldAgreement, lstFieldName)){
                contracts.add(changeStatusContract(newAgreement));
            }
        }
        if(!contracts.isEmpty()){
            update contracts;
        }
    }

    /**
     * description this method change Status Contract and return contract
     * @autor camilo.jimenez@publicar.com
     * @param updateEchosign_dev1__SIGN_Agreement__c
	**/
    public static contract changeStatusContract(echosign_dev1__SIGN_Agreement__c newAgreement){
        contract cont = new contract(id=newAgreement.echosign_dev1__Contract__c, SM_Agreement_Status__c=newAgreement.echosign_dev1__Status__c);
        return cont;
    }

}