/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 16/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
public with sharing class SM_AcPaymentToDependentContract {
    
    private Map<Id, Contract> masterById = new Map<Id, Contract>();
    private Map<Id, SM_Payment__c> paymentByMasterId = new Map<Id, SM_Payment__c>();

    /**
    * @description Constructor
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 03/08/2022 
    * @param object Set<Id> paymentIds
    **/
    public SM_AcPaymentToDependentContract(Set<Id> paymentIds) {

        getPaymentData(paymentIds);
    }

    /**
    * @description This method query related payment by pased object
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    * @param so 
    **/
    private void getPaymentData(Set<Id> paymentIds){

        /** get all editable fields of payment object */
        String allEditablePaymentFields = String.join(SM_Utils.getAllEditableFieldsBySObject(SM_Payment__c.getSObjectType().getDescribe().getName()), ',');
        Set<Id> contractIds = new Set<Id>();
        String MASTER_CONTRACT_TYPE = SM_ContractHelper.contractType.MASTER;
        String AC_TYPE = SM_ACHOrderHelper.paymentType.AC;

        /** get related payment with all editable fields */
        String paymentQuery = 'SELECT {0}, SM_Contract__c '
        + 'FROM SM_Payment__c '
        + 'WHERE Id IN: paymentIds '
        + 'AND SM_Contract__r.Contract_Type__c =: MASTER_CONTRACT_TYPE '
        + 'AND SM_Type__c =: AC_TYPE';

        for (SM_Payment__c payment : Database.query(String.format(paymentQuery, new List<String>{allEditablePaymentFields}))) {
            
            contractIds.add(payment.SM_Contract__c);
            paymentByMasterId.put(payment.SM_Contract__c, payment);
        }

        /** Get related contracts */
        buildMasterContractMap(contractIds);

        /** Check related payment to continue proccess */
        if (!paymentByMasterId.isEmpty()) {
            validateAndClonePayment();   
        }
    }

    /**
    * @description This method get master contracts and build map
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    * @param masterIds 
    **/
    private void buildMasterContractMap(Set<Id> masterIds){

        /** Get related contracts */
        for (Contract relatedContract : [SELECT 
                                            Contract_Type__c, SM_Total_ac__c, SM_Charged_AC_Fees__c, SM_Failed_AC_Fees__c
                                            , (SELECT 
                                                    SM_Total_ac__c , SM_AC_Split_Date__c
                                                FROM Contracts1__r
                                                WHERE Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION
                                                AND SM_Requires_AC_Payment__c = true) 
                                        FROM Contract 
                                        WHERE Id IN: masterIds]) 
        {

            masterById.put(relatedContract.Id, relatedContract);
        }
    }

    /**
    * @description This method get dependent contracts and clone payment, to related with contracts
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    **/
    private void validateAndClonePayment(){

        /** Payment list to clone */
        List<SM_Payment__c> clonedPayments = new List<SM_Payment__c>();
        /** Contracts to update */
        List<Contract> dependentContractsToUpdate = new List<Contract>();

        for (Contract master : masterById.values()) {
                
            /** get AC dependent contracts and iterate them */
            List<Contract> dependentContracts = masterById.get(master.Id).Contracts1__r;

            SM_Payment__c payment = paymentByMasterId.get(master.Id);

            if (payment == null) {
                continue;
            }

            /** values to cloned payments */
            Decimal penaltyValueToDependent = dependentContracts.size() > 0 ? (payment.SM_Penalty_value__c / dependentContracts.size()).setScale(2) : 0;
            Decimal feeValueToDependent = dependentContracts.size() > 0 ? (payment.SM_Fee_value__c / dependentContracts.size()).setScale(2) : 0;
            Boolean acCollected = master.SM_Total_ac__c <= payment.SM_Amount__c;

            for (Contract dependent : dependentContracts) {

                Decimal splitAmount = dependent.SM_Total_ac__c > 0 ? (dependent.SM_Total_ac__c / 2).setScale(2) : 0;
                Decimal amountToDependent = dependent.SM_AC_Split_Date__c <> null ? splitAmount : dependent.SM_Total_ac__c;
                
                /** Clone payment from master, overrite amounts and related with dependent cntract*/
                SM_Payment__c clonedPayment = payment.clone();
                clonedPayment.SM_Amount__c = amountToDependent;
                clonedPayment.SM_Contract__c = dependent.Id;
                clonedPayment.SM_Penalty_value__c = penaltyValueToDependent;
                clonedPayment.SM_Fee_value__c = feeValueToDependent;
                clonedPayment.SM_ACH_Order__c = null;
                clonedPayment.SM_Chargent_Orders_Transaction__c = null;

                /** Update contract Ac audit data */
                dependent.SM_Charged_AC_Fees__c = master.SM_Charged_AC_Fees__c;
                dependent.SM_Failed_AC_Fees__c = master.SM_Failed_AC_Fees__c;
                dependent.SM_Payment_Received__c = true;
                dependent.SM_Charged_AC_Amount__c = amountToDependent;
                dependent.SM_AC_collected__c = acCollected;

                /** Add clne to list to insert */
                clonedPayments.add(clonedPayment);

                /** Add dependent to list to update */
                dependentContractsToUpdate.add(dependent);
            }
        }

        /** Insert cloned payments */
        if (!clonedPayments.isEmpty()) {
            insert clonedPayments;
        }

        /** Update dependent contracts */
        if (!dependentContractsToUpdate.isEmpty()) {
            update dependentContractsToUpdate;
        }
    }
}