public with sharing class SM_PaymentProcessHandler {
    /**
    * @description This method will create the required payment records based on the properties AC/RC
    * @author srojas@legal-credit | 05-02-2021
    * @param newItems 
    * @param oldItems 
    **/
    public static void validatePayments(Map<Id,SObject> newItems, Map<Id,SObject> oldItems){
        /* Vilidates the Creation of a Chargent Order if it doesn't exit already */
        List<Contract> contractsToUpdateList = new List<Contract>();
        List<Object> pmToValidate = new List<Object>();
        List<Object> chargentPTypes = new List<Object>();
        Try{
            List<String> ACids = new List<String>();
            List<String> SusId = new List<String>();
            List<String> ACHACids = new List<String>();
            List<String> ACHSusId = new List<String>();
            List<Contract> contractACHIds = new List<Contract>();
            List<Contract> contractOrderIds = new List<Contract>();
            List<Contract> contractSignedIds = new List<Contract>();
            for(String id: newItems.keySet()){
                Contract ctr = (Contract)newItems.get(id);
                System.debug(ctr.SM_Requires_AC_Payment__c);
                if(ctr.SM_Requires_AC_Payment__c){
                    System.debug(ctr.SM_Requires_AC_Payment__c);
                    if(ctr.SM_Payment_methods__c == 'Credit Card'){
                        if(ctr.SM_Way_of_AC_Payment__c != null && ctr.SM_Way_of_AC_Payment__c == 'One payment'){
                            pmToValidate.add('AC - Full Payment');
                        }
                        else{
                            pmToValidate.add('AC - Fees');
                        }
                        chargentPTypes.add('AC');
                    }
                    else if(ctr.SM_Payment_methods__c == 'ACH'){
                        if(ctr.SM_Way_of_AC_Payment__c != null && ctr.SM_Way_of_AC_Payment__c == 'One payment'){
                            pmToValidate.add('AC - Full Payment');
                        }
                        else{
                            pmToValidate.add('AC - Fees');
                        }
                        chargentPTypes.add('AC');
                    }

                }
                if(ctr.SM_Requires_RC_Payment__c){
                    if(ctr.SM_Payment_methods__c == 'Credit Card'){
                        if(ctr.SM_Way_of_Contract_Payment__c != null && ctr.SM_Way_of_Contract_Payment__c == 'Fix Term'){
                            pmToValidate.add('RC - Fees');
                        }
                        else{
                            pmToValidate.add('Subscription');
                        }
                        chargentPTypes.add('Subscription');
                    }
                    else if(ctr.SM_Payment_methods__c == 'ACH'){
                        if(ctr.SM_Way_of_Contract_Payment__c != null && ctr.SM_Way_of_Contract_Payment__c == 'Fix Term'){
                            pmToValidate.add('RC - Fees');
                        }
                        else{
                            pmToValidate.add('Subscription');
                        }
                        chargentPTypes.add('Subscription');
                    }
                }
                // CJ 17-08-2022 SMMCI-33
                if((ctr.Status != oldItems.get(id).get('Status') && ctr.Status =='Complete information' && ctr.Contract_Type__c != SM_ContractHelper.contractType.MASTER ) ||
                    (ctr.SM_Agreement_Status__c != oldItems.get(id).get('SM_Agreement_Status__c') && ctr.SM_Agreement_Status__c == SM_ContractHelper.AgreementStatusEnum.SIGNED  && 
                     ctr.Status == SM_ContractHelper.status.SENT_FOR_SIGNATURE && 
                     ctr.Contract_Type__c == SM_ContractHelper.contractType.MASTER )){
                    if(ctr.SM_Requires_AC_Payment__c && ctr.SM_Payment_methods__c == 'Credit Card'
                       && ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT){  
                        ACids.add(id);
                    }
                    else if(ctr.SM_Requires_RC_Payment__c && ctr.SM_Payment_methods__c == 'Credit Card'
                           && ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT){
                           SusId.add(id);
                    }
                    else if(ctr.SM_Requires_AC_Payment__c && ctr.SM_Payment_methods__c == 'ACH'){
                        ACHACids.add(id);
                    }
                    else if(ctr.SM_Requires_RC_Payment__c && ctr.SM_Payment_methods__c == 'ACH'
                           && ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT){
                           ACHSusId.add(id);
                    }
                    // CJ 17-08-2022 SMMCI-33 
                   if(ctr.SM_Agreement_Status__c != oldItems.get(id).get('SM_Agreement_Status__c') && ctr.SM_Agreement_Status__c == SM_ContractHelper.AgreementStatusEnum.SIGNED && 
                      ctr.Status == SM_ContractHelper.status.SENT_FOR_SIGNATURE && ctr.Contract_Type__c == SM_ContractHelper.contractType.MASTER ){
                      contractSignedIds.add(ctr);
                    }   
                }
                if(ctr.SM_Requires_AC_Payment__c && ctr.SM_AC_collected__c &&
                    ctr.SM_Requires_RC_Payment__c && Boolean.ValueOf(ctr.SM_AC_collected__c) && ctr.Status =='Activated'
                    && oldItems.get(id).get('Status') != ctr.Status &&  ctr.SM_Payment_methods__c == 'Credit Card' 
                    && ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT){
                    SusId.add(id);
                }   
                if(ctr.SM_Requires_AC_Payment__c && ctr.SM_AC_collected__c &&
                    ctr.SM_Requires_RC_Payment__c && Boolean.ValueOf(ctr.SM_AC_collected__c) && ctr.Status =='Activated'
                    && oldItems.get(id).get('Status') != ctr.Status && ctr.SM_Payment_methods__c == 'ACH'
                    && ctr.Contract_Type__c != SM_ContractHelper.contractType.DEPENDENT){
                        ACHSusId.add(id);
                }  
                if(ctr.Contract_Type__c == SM_ContractHelper.contractType.DEPENDENT && ctr.Principal_Contract__c != null
                   && ctr.Contract_activation_form__c == SM_ContractHelper.collectionActivationForm.FUTURE_ACTIVATION
                   && ctr.Status != oldItems.get(id).get('Status') && ctr.Status == SM_ContractHelper.status.ACTIVATED
                   && ctr.SM_Payment_methods__c == 'ACH'){
                     contractACHIds.add(ctr);
                }   
                if(ctr.Contract_Type__c == SM_ContractHelper.contractType.DEPENDENT && ctr.Principal_Contract__c != null
                   && ctr.Contract_activation_form__c == SM_ContractHelper.collectionActivationForm.FUTURE_ACTIVATION
                   && ctr.Status != oldItems.get(id).get('Status') && ctr.Status == SM_ContractHelper.status.ACTIVATED
                   && ctr.SM_Payment_methods__c == 'Credit Card'){
                    contractOrderIds.add(ctr);
                } 
                // CJ 17-08-2022 SMMCI-33 
                if(ctr.Status != oldItems.get(id).get('Status') && ctr.Status == SM_ContractHelper.status.COMPLETE_INFORMATION
                    && ctr.Contract_Type__c == SM_ContractHelper.contractType.MASTER && ctr.Principal_Contract__c == null){
                     contractSignedIds.add(ctr);
                }   
            }
            
            System.debug('ACids '+ACids);
            if(ACids.size()>0){
                System.debug('ACids '+ACids);
                SM_ChargentPaymentProcessHandler.CreateACOrderRecordsChargent(ACids,pmToValidate,chargentPTypes);
            }
            if(SusId.size()>0){ 
               System.debug('SusId '+SusId);
               SM_ChargentPaymentProcessHandler.CreateSubscriptionOrderRecordsChargent(SusId);
            }
            if(ACHACids.size()>0){
                System.debug('ACHACids '+ACHACids);
                SM_ACHPaymentProcessHandler.CreateACOrderRecordsACH(ACHACids,pmToValidate,chargentPTypes);
            }
            if(ACHSusId.size()>0){
                System.debug('ACHSusId '+ACHSusId);
                SM_ACHPaymentProcessHandler.CreateSubscriptionOrderRecordsACH(ACHSusId);
            }
            // CJ SMMCI-23 02/08/2022
            if(!contractACHIds.isEmpty()){
                SM_ACHPaymentProcessHandler.createAssetFeetBoundle(contractACHIds);
            }
            // CJ SMMCI-23 02/08/2022
            if(!contractOrderIds.isEmpty()){
                SM_ChargentPaymentProcessHandler.createAssetFeetBoundle(contractOrderIds);
            }
            // CJ 17-08-2022 SMMCI-33 
            if(!contractSignedIds.isEmpty()){
               sendSignatureContracts(contractSignedIds);
            }
            
        }Catch(System.Exception ex){
            /* Call the TransactionLogHandler class method to create a log 
               parameters need to pass in the method are System.Exception and the Handler ClassName
            */
            System.debug(ex.getStackTraceString() +'<br/>' + ex.getMessage() + '<br/>' + ex.getCause() +' <br/>'+ ex.getTypeName());
            TransactionLogHandler.doHandleException(ex , 'contractTGRController');
        }
    }
    /**
    * @description This method send Signature Contracts and change payment Process
    * @author cjimenez@legal-credit.com | 19-08-2022
    * @param oppscontractSignedIdsId | List<Contract
    */
    public static void sendSignatureContracts(List<Contract> contractSignedIds){
        List<Contract> lstContractUpdate = new List<Contract>();
        for(Contract ctr : contractSignedIds){
            String status = ctr.Status == SM_ContractHelper.status.COMPLETE_INFORMATION ? SM_ContractHelper.status.SENT_FOR_SIGNATURE :
                            SM_ContractHelper.status.PAYMENT_PROCESS;
            Contract ctrUpdate = new Contract();
            ctrUpdate.id = ctr.id;
            ctrUpdate.Status = status;
            if(status == SM_ContractHelper.status.SENT_FOR_SIGNATURE) ctrUpdate.SM_Send_Agreement__c = true;      
            lstContractUpdate.add(ctrUpdate);
        }
       if(!lstContractUpdate.isEmpty()){
          Database.update(lstContractUpdate);
       }
    }
}