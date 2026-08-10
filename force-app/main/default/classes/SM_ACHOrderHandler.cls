/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   04-25-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
public without sharing class SM_ACHOrderHandler extends SM_TriggerHandler{

    public SM_ACHOrderHandler(String triggerName) {
        super(triggerName);
    }

    /************* Overwrite DML methods *************/
    override public void beforeInsert() {
        // SFDCM-366 Update contract to Payment process when it doesn't have any ACH Orders
        updateContractStatus(Trigger.new);
        //CJ 17-11-2021 SMPII-76
        insertNextScheduledPaymentDate(Trigger.new);
        //SMMCI-38
        SM_PaymentHelper.setFeeToCollectFromFailetPayment(Trigger.new);
    }

    override public void afterInsert(){
        // updateAssetsFee(Trigger.new, Trigger.oldMap);
        createAssetsFee(Trigger.new, Trigger.oldMap);
        // JSPA - SFDCMP-296 - Item 7.4 (Evaluar si el Contrato asociado tiene solo Asset de Suscripción   y marcar el ACH Order como Fixed value en caso contrario será  Dynamic)
        setPaymentCondition(Trigger.new);
        // SFDCMP-363 Send Aggrement
        updateContractInfo(Trigger.new);
        //SMMCI-31 CJ 08/08/2022
        updateFeeToCollect(Trigger.new);
    }

    override public void beforeUpdate(){
        // JSPA - SFDCMP-340
        getPaymentDayFromCtAndSetInACHOrder(Trigger.new, Trigger.oldMap);
        //CJ 17-11-2021 SMPII-76
        updateNextScheduledPaymentDate(Trigger.new, Trigger.oldMap);
        // JSPA - SFDCMP-351
        processApplyPenaltyChanges(Trigger.new, Trigger.oldMap);
        // CJ 21-10-2021 SMPII-39
        validateCanceledStatus(Trigger.new);

    }

    override public void afterUpdate(){
        updateAssetsFee(Trigger.new, Trigger.oldMap, false);
        // JSPA - SFDCMP-344
        updatePaymentMethodInChildRecords(Trigger.new, Trigger.oldMap);
    }

    /************* Auxiliar methods *************/
    private void createAssetsFee(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        System.debug('Executing createAssetsFee');
        Map<String, SM_ACH_Order__c> achOrderIdByContractId = new Map<String, SM_ACH_Order__c>();
        Set<ID> idsContract = new Set<ID>();
        for (SM_ACH_Order__c achOrder : newRecords) {
            idsContract.add(achOrder.SM_Contract__c);
            if (achOrder.SM_Payment_Type__c == 'Subscription' || achOrder.SM_Payment_Type__c == 'Fee') achOrderIdByContractId.put(achOrder.SM_Contract__c, achOrder);
        }
        // CJ 06/08/2022 SMMCI-27
        if (!achOrderIdByContractId.isEmpty()) {
            for(Contract ctr : [SELECT id, (SELECT  id, Principal_Contract__c, SM_Contract__r.Contract_activation_form__c,SM_Contract__c,SM_Contract__r.Collection_Main_Contract__c FROM Assets1__r ) FROM Contract WHERE ID IN: idsContract ]){
                if(!ctr.Assets1__r.isEmpty()){
                    for(Asset asset: ctr.Assets1__r)
                        if(asset.SM_Contract__r.Contract_activation_form__c == SM_ContractHelper.collectionActivationForm.INMEDIATE_ACTIVATION
                           && asset.SM_Contract__r.Collection_Main_Contract__c == SM_ContractHelper.collectionMain.READY_FOR_COLLECTION){
                            SM_ACH_Order__c achOrder = achOrderIdByContractId.get(asset.Principal_Contract__c);
                            achOrderIdByContractId.put(asset.SM_Contract__c, achOrder);
                        }
                }
            }
            List<Asset> assetsToProcess = [SELECT Id, Price, SM_Contract__c, Principal_Contract__c, Product2.SM_Plan_Months__c, Product2.SM_Way_to_pay__c, Product2.SM_Monthly_Offer__c FROM Asset WHERE Price > 0 AND SM_Contract__c IN :achOrderIdByContractId.keySet() AND SM_Quantity_of_fees__c = 0];
            // SFDCMP-294 - JSPA
            List<SM_Asset_Fee__c> assetsFeeToInsert = new List<SM_Asset_Fee__c>();
            SM_Asset_Fee__c assetFee;
            for (Asset asset : assetsToProcess) {
                Decimal qtyOfAssetsFeeToCreate = 0;
                String assetFeeType = '';
                Boolean feeToCollect = false;
                Date nextTransactionDate = null;
                if (asset.Product2.SM_Way_to_pay__c == 'Subscription') {
                    qtyOfAssetsFeeToCreate = 1;
                    assetFeeType = 'Subscription';
                }
                if (asset.Product2.SM_Way_to_pay__c == 'Fix Term') {
                    qtyOfAssetsFeeToCreate = asset.Product2.SM_Plan_Months__c;
                    assetFeeType = 'Fee';
                }
                for (Decimal i = 0; i < qtyOfAssetsFeeToCreate; i++) {
                    if ((assetFeeType == 'Subscription') || (assetFeeType == 'Fee' && i == 0)) {
                        feeToCollect = true;
                        nextTransactionDate = asset.Principal_Contract__c != null && achOrderIdByContractId.containsKey(asset.Principal_Contract__c) ? achOrderIdByContractId.get(asset.Principal_Contract__c).SM_Next_Transaction_Date__c : 
                                              achOrderIdByContractId.get(asset.SM_Contract__c).SM_Next_Transaction_Date__c;
                    } else {
                        feeToCollect = false;
                    }
                    // CJ SMMCI-10 25/07/2022
                    assetFee = new SM_Asset_Fee__c(
                        SM_Asset__c = asset.Id,
                        SM_Position__c = i + 1,
                        SM_Type__c = assetFeeType,
                        SM_Amount__c = asset.Principal_Contract__c != null ? asset.Price :  asset.Product2.SM_Monthly_Offer__c,
                        SM_Contract__c = asset.SM_Contract__c,
                        SM_Status__c = 'Scheduled',
                        SM_ACH_Order__c = asset.Principal_Contract__c != null && achOrderIdByContractId.containsKey(asset.Principal_Contract__c) ? achOrderIdByContractId.get(asset.Principal_Contract__c).id : 
                        achOrderIdByContractId.get(asset.SM_Contract__c).id,
                        SM_Fee_to_collect__c = feeToCollect,
                        SM_Date__c = nextTransactionDate,
                        SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                        Name = assetFeeType + '-' + (i + 1)
                    );
                    assetsFeeToInsert.add(assetFee);
                }
            }
            if (!assetsFeeToInsert.isEmpty()) {
                List<Database.SaveResult> sr = Database.insert(assetsFeeToInsert);
                System.debug('sr: ' + JSON.serialize(sr));
            }
        }
    }
    /**
    * @description This method create asset fees and update the asset with chargent order record
    * @author Cjimenez | 02/08/2022
    * @param contractIds,achOrderIdByContractId
    **/
    public static Map<Id,List<SM_Asset_Fee__c>> createAssetFeesProcess(List<String> contractIds,Map<String,SM_ACH_Order__c> achOrderIdByContractId){
        // Get assets by contract ids
        Map<String,Asset> ctrIdsByAsset = new Map<String,Asset>();
        List<Asset> assetsToProcess = [SELECT Id,AC_Price__c,Price,Product2.SM_Requires_AC__c,SM_Contract__c,Principal_Contract__c, Product2.SM_Plan_Months__c, Product2.SM_Way_to_pay__c, Product2.SM_Monthly_Offer__c FROM Asset WHERE SM_Contract__c IN :contractIds AND Price > 0];
        
        List<Asset> assetToUpdate = new List<Asset>();
        Map<Id,List<SM_Asset_Fee__c>> assetsFeeToInsert = new Map<Id,List<SM_Asset_Fee__c>>();
        SM_Asset_Fee__c assetFee;
        for (Asset asset : assetsToProcess) {
            //String chargentOrderId = chargentOrderByContractId.get(asset.SM_Contract__c);
            Decimal qtyOfAssetsFeeToCreate = 0;
            Boolean feeToCollect = false;
            String assetFeeType = '';
            if (asset.Product2.SM_Way_to_pay__c == 'Subscription') {
                qtyOfAssetsFeeToCreate = 1;
                assetFeeType = 'Subscription';
            }
            // CJ SMMCI-23 27/07/2022
            if (asset.Product2.SM_Way_to_pay__c == 'Fix Term') {
                qtyOfAssetsFeeToCreate = asset.Product2.SM_Plan_Months__c;
                assetFeeType = 'Fee';
            }
             // CJ SMMCI-10 25/07/2022
            SM_ACH_Order__c achOrder = achOrderIdByContractId.containsKey(asset.Principal_Contract__c) ? achOrderIdByContractId.get(asset.Principal_Contract__c) : null;
            Decimal position = 0; 
            Decimal acFee = 0;
            if(achOrder != null)
               acFee = asset.Product2.SM_Requires_AC__c == true ? 1 : 0;
               position = asset.Product2.SM_Requires_AC__c == true ? achOrder.SM_Fee_to_collect__c : achOrder.SM_Fee_to_collect__c + 1; 
               qtyOfAssetsFeeToCreate = qtyOfAssetsFeeToCreate + acFee + position ;
            for (Decimal i = position; i < qtyOfAssetsFeeToCreate; i++) {
                if ((assetFeeType == 'Subscription') || (assetFeeType == 'Fee' )) {
                    feeToCollect = true;
                } else {
                    feeToCollect = false;
                }
                if(!assetsFeeToInsert.containsKey(asset.SM_Contract__c)){
                    // CJ SMMCI-10 25/07/2022
                    assetsFeeToInsert.put(
                    	asset.SM_Contract__c,
                    	new List<SM_Asset_Fee__c>{
                            new SM_Asset_Fee__c(
                                SM_Asset__c = asset.id,
                                SM_Position__c = i,
                                SM_Type__c = asset.Product2.SM_Requires_AC__c == true ? 'Fee' : assetFeeType,
                                SM_Amount__c = asset.Product2.SM_Requires_AC__c == true ? asset.AC_Price__c :  asset.Price,
                                SM_Contract__c = asset.SM_Contract__c,
                                SM_Status__c = 'Scheduled',
                                SM_ACH_Order__c = achOrder != null ? achOrder.id : null,
                                SM_Fee_to_collect__c = feeToCollect,
                                SM_Date__c = achOrder.SM_Next_Transaction_Date__c,
                                SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                                Name = assetFeeType + '-' + i
                        	)
                        }
                	);
                }
                else{
                    assetsFeeToInsert.get(asset.SM_Contract__c).add(
                        new SM_Asset_Fee__c(
                            SM_Asset__c = asset.id,
                            SM_Position__c = i,
                            SM_Type__c = assetFeeType,
                            SM_Amount__c = asset.Principal_Contract__c != null ? asset.Price :  asset.Product2.SM_Monthly_Offer__c,
                            SM_Contract__c = asset.SM_Contract__c,
                            SM_Status__c = 'Scheduled',
                            SM_ACH_Order__c = achOrder != null ? achOrder.id : null,
                            SM_Fee_to_collect__c = feeToCollect,
                            SM_Date__c = achOrder.SM_Next_Transaction_Date__c,
                            SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                            Name = assetFeeType + '-' + i
                        )
                    );
                }
            }
        }

        return assetsFeeToInsert;
    }

    public static void updateAssetsFee(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap, Boolean isUpdateAch) {
        Map<String, SM_ACH_Order__c> achOrdersByContractId = new Map<String, SM_ACH_Order__c>();
        // Map<String, SM_ACH_Order__c> achOrdersByContractId = new Map<String, SM_ACH_Order__c>();
        Set<String> idsContract = new Set<String>();
         // CJ 08/08/2022 SMMCI-31
        for (SM_ACH_Order__c achOrder : newRecords) {
            if ((oldRecordsMap != null && SM_Utils.isChangedField(achOrder, oldRecordsMap.get(achOrder.Id), 'SM_Fee_to_collect__c') && (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE)) 
                || isUpdateAch){
                 achOrdersByContractId.put(achOrder.SM_Contract__c, achOrder);
                 idsContract.add(achOrder.SM_Contract__c);
            }
        }
        // CJ 06/08/2022 SMMCI-27
        for(Contract ctr : [SELECT id, (SELECT ID,Collection_Main_Contract__c,Principal_Contract__c FROM Contracts1__r) FROM Contract WHERE ID IN: idsContract ]){
            if(!ctr.Contracts1__r.isEmpty()){
               for(Contract ctr1: ctr.Contracts1__r){
                   if(ctr1.Collection_Main_Contract__c == SM_ContractHelper.collectionMain.READY_FOR_COLLECTION){
                      SM_ACH_Order__c achOrder = achOrdersByContractId.get(ctr1.Principal_Contract__c);
                      achOrdersByContractId.put(ctr1.id,achOrder);
                   }
               }
            }
        }
        if (!achOrdersByContractId.isEmpty()) {
            List<SM_Asset_Fee__c> assetsFeeToUpdate = new List<SM_Asset_Fee__c>();
            List<SM_Asset_Fee__c> assetsFeeToDisable = new List<SM_Asset_Fee__c>();
            Map<String, Decimal> amountAssetsFeeByACHOrderId = new Map<String, Decimal>();
            Map<String, String> contractIdByACHOrderId = new Map<String, String>();
            for (SM_Asset_Fee__c assetFee : [SELECT Id, SM_Amount__c, SM_Contract__c, SM_PrincipalContract__c, SM_ACH_Order__c, SM_Fee_to_collect__c, SM_Date__c, SM_Type__c, SM_Position__c FROM SM_Asset_Fee__c WHERE SM_Contract__c IN :achOrdersByContractId.keySet()]) {
                Decimal amount = 0;
                SM_ACH_Order__c achOrder = assetFee.SM_PrincipalContract__c != null && achOrdersByContractId.containsKey(assetFee.SM_PrincipalContract__c) ? achOrdersByContractId.get(assetFee.SM_PrincipalContract__c) :
                achOrdersByContractId.get(assetFee.SM_Contract__c);
                // Skip if the ACH Order ID is null or empty to prevent errors downstream
                if (assetFee.SM_ACH_Order__c == null || assetFee.SM_ACH_Order__c == '') {
                    continue;
                }
                if (assetFee.SM_Type__c == 'Subscription' || assetFee.SM_Position__c == achOrder.SM_Fee_to_collect__c) {
                    assetFee.SM_Fee_to_collect__c = true;
                    assetFee.SM_Date__c = achOrder.SM_Next_Transaction_Date__c;
                    assetsFeeToUpdate.add(assetFee);
                    // JSPA - 06/02/2021 Pasar a after insert para los ach order que cumplan la condicion (SM_Payment_Type__c != AC)
                    // contractIdByACHOrderId.put(assetFee.SM_ACH_Order__c, assetFee.SM_Contract__c);
                    amount = assetFee.SM_Amount__c != null ? assetFee.SM_Amount__c : 0;
                    if (!amountAssetsFeeByACHOrderId.containsKey(assetFee.SM_ACH_Order__c)) amountAssetsFeeByACHOrderId.put(assetFee.SM_ACH_Order__c, 0);
                    amountAssetsFeeByACHOrderId.put(assetFee.SM_ACH_Order__c, amountAssetsFeeByACHOrderId.get(assetFee.SM_ACH_Order__c) + amount);
                }
                if (assetFee.SM_Type__c != 'Subscription' && assetFee.SM_Position__c != achOrder.SM_Fee_to_collect__c && assetFee.SM_Fee_to_collect__c == true) {
                    assetFee.SM_Fee_to_collect__c = false;
                    assetsFeeToDisable.add(assetFee);
                }
            }
            List<SM_Asset_Fee__c> assetsFeeTotal = new List<SM_Asset_Fee__c>();
            if (!assetsFeeToUpdate.isEmpty()) assetsFeeTotal.addAll(assetsFeeToUpdate);
            if (!assetsFeeToDisable.isEmpty()) assetsFeeTotal.addAll(assetsFeeToDisable);
            if (!assetsFeeTotal.isEmpty()) {
                List<Database.SaveResult> sr = Database.update(assetsFeeTotal);
                System.debug('sr: ' + JSON.serialize(sr));
            }
            if (!amountAssetsFeeByACHOrderId.isEmpty()) {
                // updateACHOrderValues(amountAssetsFeeByACHOrderId);
                //updateACHOrderValues(amountAssetsFeeByACHOrderId, contractIdByACHOrderId);
                System.debug('Ready to execute queueable - SM_UpdateACHOrderInfoQueueable - TotalAmount');
                // System.enqueueJob(new SM_UpdateACHOrderInfoQueueable('TotalAmount', amountAssetsFeeByACHOrderId, contractIdByACHOrderId));
                updateACHOrderValues(amountAssetsFeeByACHOrderId);
            }
        }
    }

    private static void updateACHOrderValues(Map<String, Decimal> amountAssetsFeeByACHOrderId) {
        System.debug('Executing updateACHOrderValues');
        System.debug('amountAssetsFeeByACHOrderId: ' + amountAssetsFeeByACHOrderId);
        // System.debug('processToExecute: ' + processToExecute);
        List<SM_ACH_Order__c> achOrdersToUpdate = new List<SM_ACH_Order__c>();
        for (String achOrderId : amountAssetsFeeByACHOrderId.keySet()) {
            // Ensure the achOrderId is valid before creating the update object
            if (achOrderId != null && achOrderId != '') {
                SM_ACH_Order__c achOrderToUpdate = new SM_ACH_Order__c(
                    Id = achOrderId,
                    SM_Total__c = amountAssetsFeeByACHOrderId.get(achOrderId)
                    );
                achOrdersToUpdate.add(achOrderToUpdate);
            }
        }
        if (!achOrdersToUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(achOrdersToUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }
    }

    private void setPaymentCondition(List<SM_ACH_Order__c> newRecords) {
        Map<String, String> contractIdByACHOrderId = new Map<String, String>();
        for (SM_ACH_Order__c achOrder : newRecords) {
            if (achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.AC && achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE) contractIdByACHOrderId.put(achOrder.Id, achOrder.SM_Contract__c);
        }
        if (!contractIdByACHOrderId.isEmpty()) {
            System.debug('Ready to execute queueable - SM_UpdateACHOrderInfoQueueable - PaymentCondition');
            // System.enqueueJob(new SM_UpdateACHOrderInfoQueueable('PaymentCondition', null, contractIdByACHOrderId));
            setPaymentCondition(contractIdByACHOrderId);
        }
    }

    private void setPaymentCondition(Map<String, String> contractIdByACHOrderId) {
        System.debug('Executing setPaymentCondition');
        System.debug('contractIdByACHOrderId: ' + contractIdByACHOrderId);
        List<Contract> contractsToValidate = [SELECT Id, (SELECT Id, Product2.SM_Way_to_pay__c  FROM Assets__r) FROM Contract WHERE Id IN :contractIdByACHOrderId.values()];
        Map<String, Boolean> onlySuscriptionAssetsByContractId = new Map<String, Boolean>();
        for (Contract ct : contractsToValidate) {
            Boolean thisContractOnlyHasSuscriptionAssets = true;
            for (Asset asset : ct.Assets__r) {
                if (asset.Product2.SM_Way_to_pay__c != 'Subscription') {
                    thisContractOnlyHasSuscriptionAssets = false;
                }
            }
            onlySuscriptionAssetsByContractId.put(ct.Id, thisContractOnlyHasSuscriptionAssets);
        }
        List<SM_ACH_Order__c> achOrdersToUpdate = new List<SM_ACH_Order__c>();
        for (String achOrderId : contractIdByACHOrderId.keySet()) {
            // Skip if achOrderId is null or empty to prevent errors
            if (achOrderId == null || achOrderId == '') {
                continue;
            }
            String contractId = contractIdByACHOrderId.get(achOrderId);
            Boolean onlySuscriptionAssets = onlySuscriptionAssetsByContractId.get(contractId);
            String paymentCondition = onlySuscriptionAssets ? 'Fixed value' : 'Dynamic';
            SM_ACH_Order__c achOrderToUpdate = new SM_ACH_Order__c(
                Id = achOrderId,
                SM_Payment_Condition__c = paymentCondition
            );
            achOrdersToUpdate.add(achOrderToUpdate);
        }
        if (!achOrdersToUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(achOrdersToUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }
    }

    /**
    * @description This method update the payment method in child rercords
    * @author jpachon@legal-credit.com | 05-20-2021
    * @param newRecords | List<SM_ACH_Order__c>
    * @param oldRecordsMap | Map<Id, SObject>
    **/
    private void updatePaymentMethodInChildRecords(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        List<SM_ACH_Order__c> achOrdersFiltered = new List<SM_ACH_Order__c>();
        Set<String> paymentMethodIds = new Set<String>();
        for (SM_ACH_Order__c newACHOrder : newRecords) {
            SM_ACH_Order__c oldACHOrder = (SM_ACH_Order__c) oldRecordsMap.get(newACHOrder.Id);
            if (SM_Utils.isChangedField(newACHOrder, oldACHOrder, 'SM_Payment_Method__c')) {
                achOrdersFiltered.add(newACHOrder);
                paymentMethodIds.add(oldACHOrder.SM_Payment_Method__c);
                paymentMethodIds.add(newACHOrder.SM_Payment_Method__c);
            }
        }
        if(!achOrdersFiltered.isEmpty()) processACHOrdersWithPaymentMethodChanged(achOrdersFiltered, oldRecordsMap, paymentMethodIds);
    }

    /**
    * @description This method update the payment method in child rercords
    * @author jpachon@legal-credit.com | 05-20-2021
    * @param newContracts | List<SM_ACH_Order__c>
    * @param oldRecordsMap | Map<Id, SObject>
    * @param paymentMethodIds | Set<String>
    **/
    private void processACHOrdersWithPaymentMethodChanged(List<SM_ACH_Order__c> achOrdersFiltered, Map<Id, SObject> oldRecordsMap, Set<String> paymentMethodIds) {
        String achRecordType = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment_Method__c', 'ACH');
        Map<String, SM_Payment_Method__c> paymentMethodByIds = new Map<String, SM_Payment_Method__c>([SELECT Id, SM_ACH_Account_Number__c, SM_Routing_Number__c , SM_Routing_Number_Check_Digit__c FROM SM_Payment_Method__c WHERE Id IN : paymentMethodIds AND RecordTypeId = :achRecordType]);
        Map<String, SM_Payment_Method__c> newPaymentMethodByACHOrderId = new Map<String, SM_Payment_Method__c>();
        if (!paymentMethodIds.isEmpty()) {
            for (SM_ACH_Order__c newACHOrder : achOrdersFiltered) {
                SM_ACH_Order__c oldACHOrder = (SM_ACH_Order__c) oldRecordsMap.get(newACHOrder.Id);
                if (paymentMethodByIds.containsKey(newACHOrder.SM_Payment_Method__c) && paymentMethodByIds.containsKey(oldACHOrder.SM_Payment_Method__c)) {
                    newPaymentMethodByACHOrderId.put(newACHOrder.Id, paymentMethodByIds.get(newACHOrder.SM_Payment_Method__c));
                }
            }
        }
        if (!newPaymentMethodByACHOrderId.isEmpty()) getPaymentsToUpdatePaymentMethod(newPaymentMethodByACHOrderId);
    }

    /**
    * @description This method update the payment method in Payments
    * @author jpachon@legal-credit.com | 05-20-2021
    * @param newPaymentMethodByACHOrderId | Map<String, String>
    **/
    private void getPaymentsToUpdatePaymentMethod(Map<String, SM_Payment_Method__c> newPaymentMethodByACHOrderId) {
        List<SM_Payment__c> payments = [SELECT Id, SM_ACH_Order__c, SM_Payment_Method__c FROM SM_Payment__c WHERE SM_ACH_Order__c IN :newPaymentMethodByACHOrderId.keySet() AND Payment_Status__c = :SM_PaymentHelper.status.ACH_PENDING];
        List<SM_Payment__c> paymentsToUpdate = new List<SM_Payment__c>();
        for (SM_Payment__c payment : payments) {
            if (newPaymentMethodByACHOrderId.containsKey(payment.SM_ACH_Order__c)) {
                payment.SM_Payment_Method__c = newPaymentMethodByACHOrderId.get(payment.SM_ACH_Order__c).Id;
                payment.SM_ACH_Account_Number__c = newPaymentMethodByACHOrderId.get(payment.SM_ACH_Order__c).SM_ACH_Account_Number__c != null ? Decimal.valueOf(newPaymentMethodByACHOrderId.get(payment.SM_ACH_Order__c).SM_ACH_Account_Number__c) : 0;
                payment.SM_ACH_Account_Routing_Number__c = newPaymentMethodByACHOrderId.get(payment.SM_ACH_Order__c).SM_Routing_Number__c;
                payment.SM_Routing_Number_Check_Digit__c =Integer.valueOf(newPaymentMethodByACHOrderId.get(payment.SM_ACH_Order__c).SM_Routing_Number_Check_Digit__c);
                paymentsToUpdate.add(payment);
            }
        }
        List<Database.SaveResult> sr = Database.update(paymentsToUpdate);
        System.debug('sr: ' + JSON.serialize(sr));
    }

    /**
    * @description This method update the payment day from Contract
    * @author jpachon@legal-credit.com | 05-20-2021
    * @param newRecords | List<SM_ACH_Order__c>
    * @param oldRecordsMap | Map<Id, SObject>
    **/
    private void getPaymentDayFromCtAndSetInACHOrder(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        Map<String, SM_ACH_Order__c> achOrderByContractId = new Map<String, SM_ACH_Order__c>();
        for (SM_ACH_Order__c newRecord : newRecords) {
            SM_ACH_Order__c oldRecord = (SM_ACH_Order__c)oldRecordsMap.get(newRecord.Id);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'SM_Next_Transaction_Date__c')  && newRecord.SM_Next_Transaction_Date__c != null 
                && newRecord.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.AC && newRecord.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE && !newRecord.SM_IsApplyingDaysCollectedPenalty__c) {
                achOrderByContractId.put(newRecord.SM_Contract__c, newRecord);
            }
        }
        if(!achOrderByContractId.isEmpty()){
            Map<String, Integer> paymentDayByContractId = new Map<String, Integer>();
            Map<String, Contract> contractById = new Map<String, Contract>([SELECT Id, SM_Payment_day__c FROM Contract WHERE Id IN :achOrderByContractId.keySet()]);
            for (Contract ct : contractById.values()) {
                paymentDayByContractId.put(ct.Id, Integer.valueOf(ct.SM_Payment_day__c));
            }
            // JSPA - 09/07/2021 - Case 00001047
            // Change variable from newRecords to achOrderByContractId.values(), to process only the records that match the criteria
            for (SM_ACH_Order__c newRecord : achOrderByContractId.values()) {
                Integer newPaymentDay = paymentDayByContractId.get(newRecord.SM_Contract__c);
                if (newPaymentDay != null) {
                    if (newPaymentDay >= 29) {
                        // Integer lastDay = Date.daysInMonth(newRecord.SM_Next_Transaction_Date__c.year(), newRecord.SM_Next_Transaction_Date__c.month());
                        // newRecord.SM_Next_Transaction_Date__c = Date.newInstance(newRecord.SM_Next_Transaction_Date__c.year(), newRecord.SM_Next_Transaction_Date__c.month(), lastDay);
                        // JSPA - 08/18/2021
                        Integer lastDayOfMonth = Date.daysInMonth(newRecord.SM_Next_Transaction_Date__c.year(), newRecord.SM_Next_Transaction_Date__c.month());
                        if(newPaymentDay > lastDayOfMonth) {
                            newPaymentDay = lastDayOfMonth;
                        }
                        newRecord.SM_Next_Transaction_Date__c = Date.newInstance(newRecord.SM_Next_Transaction_Date__c.year(), newRecord.SM_Next_Transaction_Date__c.month(), newPaymentDay);
                    } else {
                        newRecord.SM_Next_Transaction_Date__c = Date.newInstance(newRecord.SM_Next_Transaction_Date__c.year(), newRecord.SM_Next_Transaction_Date__c.month(), newPaymentDay);
                    }
                }
            }
        }
         // This flag is required to avoid that when a record comes from processErrorChargentOrders method execute this method
         for (SM_ACH_Order__c newRecord : newRecords) {
               newRecord.SM_IsApplyingDaysCollectedPenalty__c = false;
          }
        System.debug('newRecords: ' + newRecords);
    }

    /**
    * @description This method update the total value according with it is required sum or subtract the penalty value
    * @author jpachon@legal-credit.com | 06-18-2021
    * @param newRecords | List<SM_ACH_Order__c>
    * @param oldRecordsMap | Map<Id, SObject>
    **/
    private void processApplyPenaltyChanges(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        for (SM_ACH_Order__c newRecord : newRecords) {
            SM_ACH_Order__c oldRecord = (SM_ACH_Order__c)oldRecordsMap.get(newRecord.Id);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'SM_Apply_penalty__c')) {
                newRecord.SM_Penalty_date__c = System.today();
                newRecord.SM_User_who_applies_the_penalty__c = UserInfo.getUserId();
                if (newRecord.SM_Apply_penalty__c) {
                    newRecord.SM_Total__c = newRecord.SM_Total__c + newRecord.SM_Penalty_value__c;
                } else {
                    newRecord.SM_Total__c = newRecord.SM_Total__c - newRecord.SM_Penalty_value__c;
                }
            }
        }
    }

    /**
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 06-29-2021
    * @param newRecords
    **/
    private void updateContractInfo(List<SM_ACH_Order__c> newRecords) {
        Set<String> contractIds = new Set<String>();
        for (SM_ACH_Order__c ACHOrder : newRecords) {
            contractIds.add(ACHOrder.SM_Contract__c);
        }
        Map<String, Contract> contracts = SM_ACHOrderHelper.getContractByIds(contractIds);
        for (SM_ACH_Order__c ACHOrder : newRecords) {
            Contract contract=contracts.get(ACHOrder.SM_Contract__c);
            if(contract != null && contract.SM_Agreement_Status__c == null && ACHOrder.SM_Payment_Start_Date__c == system.Today()){
                contract.SM_Send_Agreement__c=true;
            }
        }
        List<Database.SaveResult> sr = Database.update(contracts.values());
        System.debug('sr: ' + sr);
    }

    /**
    * @description This method update Contract Info
    * @author jpachon@legal-credit.com | 07-07-2021
    * @param newRecords
    **/
    private void updateContractStatus(List<SM_ACH_Order__c> newRecords) {
        Set<String> contractIds = new Set<String>();
        for (SM_ACH_Order__c achOrder : newRecords) {
            contractIds.add(ACHOrder.SM_Contract__c);
        }
        if (contractIds.isEmpty()) return;
        Map<String, Contract> contracts = SM_ACHOrderHelper.getContractByIds(contractIds);
        for (SM_ACH_Order__c achOrder : newRecords) {
            Contract contract = contracts.get(achOrder.SM_Contract__c);
            if(contract.Status == SM_ContractHelper.status.COMPLETE_INFORMATION && contract.ACH_Orders__r.size() == 0) contract.Status = SM_ContractHelper.status.PAYMENT_PROCESS;
        }
        List<Database.SaveResult> rs;
        if (!contracts.isEmpty()) {
            SM_BypassManager.disableValidationRules();
            rs = Database.update(contracts.values());
            SM_BypassManager.enableValidationRules();
            System.debug('rs: ' + JSON.serialize(rs));
        }
    }

     /**
    * @description this method validate what change status to canceled
    * @author cjimenez@legal-credit.com | 21-10-2021
    * @param newRecords
    **/
    private void validateCanceledStatus(List<SM_ACH_Order__c> newRecords){
        Map<String,SM_ACH_Order__c> achOrderById = new Map<String,SM_ACH_Order__c>();
        List<String> lstStatusPayment=new List<String>{SM_PaymentHelper.status.ACH_PENDING,SM_PaymentHelper.status.ACH_TRANSMITTED};
        for (SM_ACH_Order__c achOrder : newRecords) {
            if(achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.CANCELED){
                achOrderById.put(achOrder.id,achOrder);
            }
        }
        for(SM_Payment__c payment:[SELECT ID,SM_Status__c,SM_ACH_Order__c 
                                   FROM SM_Payment__c 
                                   WHERE SM_ACH_Order__c IN:achOrderById.keySet() 
                                   AND Payment_Status__c IN:lstStatusPayment]){
            String key=payment.SM_ACH_Order__c;
            SM_ACH_Order__c achOrder=achOrderById.containsKey(key) ? achOrderById.get(key) : null;
            if(achOrder != null)showErrorMessage(achOrder);
        }
    }

    /**
    * @description This method shows the errors on the screen
    * @author cjimenez@legal-credit.com | 22-02-2021
    * @param oppLineItem
    **/
    public void showErrorMessage(SM_ACH_Order__c achOrder){
        achOrder.addError(LABEL.SM_CANCELED_ACH_ORDER_MASSAGE);
   }


   /**
    * @description his method update Next Scheduled Payment Date
    * @author Camilo Jimenez -> cjimenez@legal-credit.com | 08/11/2021
    * @param newInvoice | List<ChargentOrders__ChargentOrder__c>
    * @param oldInvoice | Map<Id, SObject>
    **/
    private static void updateNextScheduledPaymentDate(List<SM_ACH_Order__c> newRecords, Map<Id, SObject> oldRecordsMap){
        BusinessHours bHour=SM_Utils.getBusinessHour('Monee Business Hour');
        for (SM_ACH_Order__c newAch : newRecords) {
             SM_ACH_Order__c oldAch= (SM_ACH_Order__c) oldRecordsMap.get(newAch.Id);
             if ( SM_Utils.isChangedField(newAch, oldAch, 'SM_Payment_Start_Date__c') && newAch.SM_Payment_Start_Date__c != null) {
                newAch.SM_IsApplyingDaysCollectedPenalty__c=true;
                DateTime paymendDate=DateTime.newInstance(newAch.SM_Payment_Start_Date__c.year(),newAch.SM_Payment_Start_Date__c.month(),newAch.SM_Payment_Start_Date__c.day());
                SM_Utils.CompanybusinessDay companybusinessDay=SM_Utils.getSuggestedBusinessHour(bHour,paymendDate);
                if(companybusinessDay.businessDay){
                    newAch.SM_Payment_Start_Date__c = companybusinessDay.newDate;  
                    newAch.SM_Next_Transaction_Date__c = companybusinessDay.newDate;  
                    newAch.SM_Payment_End_Date__c = companybusinessDay.newDate;  
                }   
             }
            if (SM_Utils.isChangedField(newAch, oldAch, 'SM_Next_Transaction_Date__c') && newAch.SM_Next_Transaction_Date__c != null) {
                newAch.SM_IsApplyingDaysCollectedPenalty__c=true;
                DateTime paymendDate=DateTime.newInstance(newAch.SM_Next_Transaction_Date__c.year(),newAch.SM_Next_Transaction_Date__c.month(),newAch.SM_Next_Transaction_Date__c.day());
                SM_Utils.CompanybusinessDay companybusinessDay=SM_Utils.getSuggestedBusinessHour(bHour,paymendDate);
                if(companybusinessDay.businessDay){
                    newAch.SM_Payment_Start_Date__c = companybusinessDay.newDate;  
                    newAch.SM_Next_Transaction_Date__c = companybusinessDay.newDate;  
                    newAch.SM_Payment_End_Date__c = companybusinessDay.newDate;  
                }
             }
        }
    }   

    /**
    * @description
    * @author Camilo Jimenez -> cjimenez@legal-credit.com | 08/11/2021
    * @param newContracts | List<ChargentOrders__ChargentOrder__c>
    **/
    private static void insertNextScheduledPaymentDate(List<SM_ACH_Order__c> newRecords){
        BusinessHours bHour=SM_Utils.getBusinessHour('Monee Business Hour');
        for (SM_ACH_Order__c newAch : newRecords) { 
             DateTime paymendDate= DateTime.newInstance(newAch.SM_Next_Transaction_Date__c.year(),newAch.SM_Next_Transaction_Date__c.month(),newAch.SM_Next_Transaction_Date__c.day());
             SM_Utils.CompanybusinessDay companybusinessDay=SM_Utils.getSuggestedBusinessHour(bHour,paymendDate);
            if(companybusinessDay.businessDay){
                newAch.SM_Payment_Start_Date__c = companybusinessDay.newDate;  
                newAch.SM_Next_Transaction_Date__c = companybusinessDay.newDate;  
                newAch.SM_Payment_End_Date__c = companybusinessDay.newDate; 
             }
        }
    }

     /**
    * @description This methos check change status to clone payments
    * @author Camilo Jiemenez -> cjimenez@legal-credit.com | 08/08/2022 
    * @param newRecords 
    **/
    private static void updateFeeToCollect(List<SM_ACH_Order__c> newRecords){
        List<SM_ACH_Order__c> lstAchUpdate = new List<SM_ACH_Order__c>();
        for (SM_ACH_Order__c achOrder : newRecords) {
            if(achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE)
               lstAchUpdate.add(new SM_ACH_Order__c (id = achOrder.id, SM_Fee_to_collect__c = 1));
        }
        if(!lstAchUpdate.isEmpty()){
            List<Database.SaveResult> sr =  Database.update(lstAchUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }
    }

}