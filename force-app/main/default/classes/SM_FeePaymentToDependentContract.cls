/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 27/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
public with sharing class SM_FeePaymentToDependentContract {
    
    private List<SM_Asset_Fee__c> assetFees = new List<SM_Asset_Fee__c>();
    private Map<Id, SM_Payment__c> paymentByMasterId = new Map<Id, SM_Payment__c>();
    private Map<Id, Decimal> totalAssetFeeAmountByMasterId = new Map<Id,Decimal>();
    private Map<Id, Decimal> quoteNumberByMaster = new Map<Id,Decimal>();
    private Map<Id, List<SM_Asset_Fee__c>> assetFeesByMaster = new Map<Id, List<SM_Asset_Fee__c>>();

    private static Boolean hasChargentTransactionAccess() {
        if (Test.isRunningTest()) {
            return true;
        }
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('ChargentOrders__Transaction__c')
            || !globalDescribe.containsKey('ChargentOrders__ChargentOrder__c')) {
            return false;
        }
        // SM_Fee_to_collect_frm__c es una formula en ChargentOrders__Transaction__c que a su vez
        // referencia ChargentOrders__ChargentOrder__c; hay que validar acceso a ambos objetos.
        return globalDescribe.get('ChargentOrders__Transaction__c').getDescribe().isAccessible()
            && globalDescribe.get('ChargentOrders__ChargentOrder__c').getDescribe().isAccessible();
    }

    /**
    * @description Constructor
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 03/08/2022 
    * @param object Set<Id> paymentIds
    **/
    public SM_FeePaymentToDependentContract(Set<Id> paymentIds) {

        getPaymentData(paymentIds);
    }

    /**
    * @description This method query related payment by pased object
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    * @param so 
    **/
    private void getPaymentData(Set<Id> paymentIds){

        Boolean canAccessChargentTransaction = hasChargentTransactionAccess();

        /** get all editable fields of payment object */
        String allEditablePaymentFields = String.join(SM_Utils.getAllEditableFieldsBySObject(SM_Payment__c.getSObjectType().getDescribe().getName()), ',');
        Set<Id> contractIds = new Set<Id>();
        String MASTER_CONTRACT_TYPE = SM_ContractHelper.contractType.MASTER;
        String FEE_TYPE = SM_ACHOrderHelper.paymentType.FEE;
        String LATE_PAYMENT_TYPE = SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE;

        /** get related payment with all editable fields */
        String paymentQuery = 'SELECT {0}, SM_Contract__c, SM_ACH_Order__r.SM_Fee_to_collect__c'
        + (canAccessChargentTransaction ? ', SM_Chargent_Orders_Transaction__r.SM_Fee_to_collect_frm__c ' : ' ')
        + 'FROM SM_Payment__c '
        + 'WHERE Id IN: paymentIds '
        + 'AND SM_Contract__r.Contract_Type__c =: MASTER_CONTRACT_TYPE '
        + 'AND (SM_Type__c =: FEE_TYPE '
        + 'OR (SM_Type__c =: LATE_PAYMENT_TYPE AND (SM_Original_Type__c =: FEE_TYPE OR SM_Failed_payment__r.SM_Type__c =: FEE_TYPE )))';

        for (SM_Payment__c payment : Database.query(String.format(paymentQuery, new List<String>{allEditablePaymentFields}))) {
            
            contractIds.add(payment.SM_Contract__c);
            paymentByMasterId.put(payment.SM_Contract__c, payment);
        }

        /** Get related asset fee */
        buildAssetFeeByMasterMap(contractIds);

        /** Check amounts and update master contracts */
        checkAmountsAssetFeeWithMaster();

        /** Check related payment to continue proccess */
        if (!paymentByMasterId.isEmpty()) {
            validateAndClonePayment();   
        }

    }

    private void buildAssetFeeByMasterMap(Set<Id> masterIds) {

        /** Get related asset fee */
        for (SM_Asset_Fee__c assetFee : [SELECT SM_Amount__c, SM_Type__c, SM_Position__c, SM_Asset__r.Status, SM_Contract__r.Principal_Contract__c
                                        FROM SM_Asset_Fee__c 
                                        WHERE SM_Contract__r.Principal_Contract__c IN: masterIds
                                        AND SM_Contract__r.Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION]) 
        {
            /** Get payment instance from related to master contract */
            SM_Payment__c paymentAux = (SM_Payment__c) paymentByMasterId.get(assetFee.SM_Contract__r.Principal_Contract__c);

            /** Get Fee to collect value, form ACh or Chergent related record */
            Decimal quoteNumber = paymentAux.SM_ACH_Order__r?.SM_Fee_to_collect__c;
            if (quoteNumber == null && hasChargentTransactionAccess()) {
                quoteNumber = paymentAux.SM_Chargent_Orders_Transaction__r?.SM_Fee_to_collect_frm__c;
            }
            
            /** If psyment type = Fee, quote number = related fee to collect -1, else quote number = related fee to collect */
            quoteNumber = (paymentAux.SM_Type__c == SM_ACHOrderHelper.paymentType.FEE && paymentAux.SM_ACH_Order__r <> null) ? (quoteNumber -1) : quoteNumber;

            /** Check valid Asset Fee by Type, Fee Or Payment Late */
            if ((assetFee.SM_Type__c == 'Fee' && assetFee.SM_Position__c == quoteNumber)
                || 
                (assetFee.SM_Type__c == 'Subscription' && assetFee.SM_Asset__r.Status == 'Activated')) 
            {
                assetFees.add(assetFee);

                /** Build maps to check total Asset fee amount */
                Id masterId = assetFee.SM_Contract__r.Principal_Contract__c;

                //Map to check Penalty value
                if (!assetFeesByMaster.containsKey(masterId)) {
                    assetFeesByMaster.put(masterId, new List<SM_Asset_Fee__c>());    
                }
                assetFeesByMaster.get(masterId).add(assetFee);

                /** Total amount of Asset fee found */
                if (!totalAssetFeeAmountByMasterId.containsKey(masterId)) {
                    totalAssetFeeAmountByMasterId.put(masterId, 0);
                }
                totalAssetFeeAmountByMasterId.put(masterId, (totalAssetFeeAmountByMasterId.get(masterId) + assetFee.SM_Amount__c).setScale(2));

                /** Quote number of master contract */
                quoteNumberByMaster.put(masterId, quoteNumber);
            }
        }
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 25/08/2022 
    **/
    private void checkAmountsAssetFeeWithMaster() {

        List<Contract> mastersToUpdate = new List<Contract>();

        /** Iterate keys = master ids */
        for (Id masterId : totalAssetFeeAmountByMasterId.keySet()) {
            
            if (totalAssetFeeAmountByMasterId.get(masterId) <> paymentByMasterId.get(masterId).SM_Fee_value__c) {
                
                mastersToUpdate.add(
                    new Contract (Id = masterId, Audit_Payments_Master_Contract__c = 'Inconsistency in the amount paid in installments ' + quoteNumberByMaster.get(masterId))
                );
            }
        }

        if (!mastersToUpdate.isEmpty()) {
            update mastersToUpdate;
        }
    }

    /**
    * @description This method get dependent contracts and clone payment, to related with contracts
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 05/08/2022 
    **/
    private void validateAndClonePayment(){

        /** Payment list to clone */
        List<SM_Payment__c> clonedPayments = new List<SM_Payment__c>();

        /** Iterate Asset fee, to clone payments */
        for (SM_Asset_Fee__c assetFee : assetFees) {

            Id contractmasterId = assetFee.SM_Contract__r.Principal_Contract__c;
            SM_Payment__c payment = paymentByMasterId.get(contractmasterId);

            if (payment == null) {
                continue;
            }

            /** Clone payment from master, overrite amounts and related with dependent contract*/
            SM_Payment__c clonedPayment = payment.clone();
            clonedPayment.SM_Fee_value__c = assetFee.SM_Amount__c;
            clonedPayment.SM_Amount__c = assetFee.SM_Amount__c;
            clonedPayment.SM_ACH_Order__c = null;
            clonedPayment.SM_Chargent_Orders_Transaction__c = null;
            clonedPayment.SM_Contract__c = assetFee.SM_Contract__c;
            clonedPayment.SM_Penalty_value__c = payment.SM_Penalty_value__c <> null ? (payment.SM_Penalty_value__c / assetFeesByMaster.get(contractmasterId).size()).setScale(2) : 0;

            /** Add clne to list to insert */
            clonedPayments.add(clonedPayment);
        }

        /** Insert cloned payments */
        if (!clonedPayments.isEmpty()) {
            insert clonedPayments;
        }
    }
}