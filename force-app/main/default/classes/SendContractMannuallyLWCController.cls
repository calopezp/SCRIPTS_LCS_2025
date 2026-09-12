/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-12-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   02-10-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
public without sharing class SendContractMannuallyLWCController {

    @AuraEnabled
    public static void sendContract(String contractId){
        try {
            System.debug('Ready to execute future method - sendContractAsync');
            sendContractAsync(contractId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @Future(callout=true)
    public static void sendContractAsync(String contractId) {
        System.debug('Executing SendContractMannuallyLWCController.sendContract');
        Contract ct = SM_ContractHelper.getRequiredInfoToCongaAPI(contractId);
        Contract contractToUpdate;
        SM_TransactionLog__c log = new SM_TransactionLog__c();
        Map<Id, APXTConga4__Conga_Solution__c> congaSolutionByContractId = SM_ContractHelper.getCongaSolutionSetupByContractId(new Set<String>{contractId});
        SM_ServiceInvokation requestSI = SM_ContractHelper.createRequestCongaAPI();
        SM_ServiceInvokation calloutService = new SM_ServiceInvokation(true);
        if(congaSolutionByContractId.containsKey(contractId)) {
            APXTConga4__Conga_Solution__c congaSolution = congaSolutionByContractId.get(ct.Id);
            SM_ContractHelper.addAdditionalParamsToURLCongaAPI(requestSI, ct, congaSolution.APXTConga4__Composer_Parameters__c);
            calloutService = calloutService.callService(requestSI.endPoint, requestSI.method, requestSI.headers, requestSI.request, requestSI.timeout);
            if (calloutService.isSucces) {
                contractToUpdate = SM_ContractHelper.updateContract(ct.Id);
            }
            log = calloutService.crateTransactionLog(ct.Id, requestSI.integrationName);
        }
        System.debug('callout: ' + calloutService);
        Database.SaveResult rs;
        if (log != null) {
            rs = Database.insert(log);
            System.debug('rs: ' + JSON.serialize(rs));
        }
        if (contractToUpdate != null) {
            rs = Database.update(contractToUpdate);
            System.debug('rs: ' + JSON.serialize(rs));
        }
    }
}