/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   04-08-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
 * 1.1   06-29-2021   Camilo J. Camilo Jimenex -> cjimenez@legal-credit.com  Initial Version
 * 1.2   09-07-2026   Juan Duarte / Carlos Lopez -> Ajustes por cancelacion de CHARGENT
**/
public without sharing class SM_PaymentHandler extends SM_TriggerHandler{
    public SM_PaymentHandler(String triggerName) {
        super(triggerName);
    }

    //calp Aug 2026 :: CHARGENT app is permanently disabled for this org; runtime FLS checks
    //don't reflect managed package license revocation, so this is hard-disabled instead.
    private static Boolean hasChargentObjectAccess() {
        return false;
    }

    /************* Overwrite DML methods *************/
    override public void beforeInsert() {
        // SFDCMP-240 - Chargent
        checkPaymentToSendChargentReceipt(Trigger.new);
    }

    override public void afterInsert(){
        Boolean canAccessChargent = hasChargentObjectAccess();
        updateACHOrderInfo(Trigger.new);
        // SFDCMP-363 Send Aggrement
        updateContractInfo(Trigger.new);
         //SFDCMP-352
         if (canAccessChargent) {
             processRejectedPaymentsChargentOrder(Trigger.newMap, Trigger.oldMap);
         }
         // SMMCI-36
        upsertInvoiceByPayment(Trigger.newMap, null);
        // SMMCI-29
        clonePayments(Trigger.new, null);
    }

    override public void beforeUpdate(){
        paymentStatusUpdates(Trigger.new, Trigger.oldMap);
        // SFDCMP-240 - ACH
        checkPaymentToSendACHReceipt(Trigger.new, Trigger.oldMap);
        // SMMCI-36
        upsertInvoiceByPayment(Trigger.newMap, Trigger.oldMap);
    }

    override public void afterUpdate(){
        updateRelatedRecordsByPaymentStatusUpdates(Trigger.new, Trigger.oldMap);
        // SFDCMP-351
        processRejectedPayments(Trigger.newMap, Trigger.oldMap);
        // SMMCI-29
        clonePayments(Trigger.new, Trigger.oldMap);
    }

    /************* Auxiliar methods *************/

    private void checkPaymentToSendChargentReceipt(List<SM_Payment__c> newRecords) {
        List<String> availablePaymentStatusToSendReceipt = System.label.AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT.split(',');
        if (availablePaymentStatusToSendReceipt.isEmpty()) return;
        for (SM_Payment__c newPayment : newRecords) {
            if (availablePaymentStatusToSendReceipt.contains(newPayment.Payment_Status__c)) {
                newPayment.SM_Receipt_Status__c = SM_PaymentHelper.receiptStatus.PENDING_TO_SEND;
            }
        }
    }

    /**
    * @description This method set Installment_number__c when create Payment
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    * @param newRecords 
    **/
    private void upsertInvoiceByPayment(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {

        Set<Id> validaPayments = new Set<Id>();//Payment ids to validate

        /** Check if payment is master */
        for (SM_Payment__c payment : (List<SM_Payment__c>)newRecordsMap.values()) {

            /** Check change status or new record */
            SM_Payment__c oldPayment = (SM_Payment__c)oldRecordsMap?.get(payment.Id);
            Boolean changeStatusOrNew = oldPayment == null || SM_Utils.isChangedField(payment, oldPayment, 'Payment_Status__c');
            
            Boolean hasSupportedSource = payment.SM_ACH_Order__c <> null;
            if (changeStatusOrNew && hasSupportedSource) {
                validaPayments.add(payment.Id);
            }
        }

        if (!validaPayments.isEmpty()) {
            new SM_UpsertInvoiceByPayment(validaPayments, newRecordsMap);
        }
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 16/08/2022 
    * @param newRecords 
    * @param oldRecordsMap 
    **/
    private void clonePayments(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {

        Set<Id> paymentIds = new Set<Id>();//Ids to validate
        String firstPaymentType;
        
        for (SM_Payment__c newPayment : newRecords) {

            /** Check change status or new record */
            SM_Payment__c oldPayment = (SM_Payment__c)oldRecordsMap?.get(newPayment.Id);
            Boolean changeStatusOrNew = oldPayment == null || SM_Utils.isChangedField(newPayment, oldPayment, 'Payment_Status__c');

            Boolean hasSupportedSource = newPayment.SM_ACH_Order__c <> null;
            if (changeStatusOrNew && newPayment.Payment_Status__c == SM_PaymentHelper.status.ACCEPTED && hasSupportedSource) {
                firstPaymentType = firstPaymentType == null ? newPayment.SM_Type__c : firstPaymentType;
                paymentIds.add(newPayment.Id);
            }
        }
        
        /** Check payment ids to validate */
        if (!paymentIds.isEmpty()) {

            /** Dependent type of fisrst record, call method to proccess */

            if (firstPaymentType == SM_ACHOrderHelper.paymentType.AC) {

                new SM_AcPaymentToDependentContract(paymentIds);
            } else if (firstPaymentType == SM_ACHOrderHelper.paymentType.FEE || firstPaymentType == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE) {

                new SM_FeePaymentToDependentContract(paymentIds);
            }
            
        }
    }

    private void checkPaymentToSendACHReceipt(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        List<String> availablePaymentStatusToSendReceipt = System.label.AVAILABLE_PAYMENT_STATUS_TO_SEND_RECEIPT.split(',');
        if (availablePaymentStatusToSendReceipt.isEmpty()) return;
        for (SM_Payment__c newPayment : newRecords) {
            SM_Payment__c oldPayment = (SM_Payment__c)oldRecordsMap.get(newPayment.Id);
            if (SM_Utils.isChangedField(newPayment, oldPayment, 'Payment_Status__c') && availablePaymentStatusToSendReceipt.contains(newPayment.Payment_Status__c)) {
                newPayment.SM_Receipt_Status__c = SM_PaymentHelper.receiptStatus.PENDING_TO_SEND;
            }
        }
    }

    /**
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 29-06-2021
    * @param newRecords
    **/
  private void updateContractInfo(List<SM_Payment__c> newRecords) {
        Set<String> contractIds = new Set<String>();
        for (SM_Payment__c payment : newRecords) {
             contractIds.add(payment.SM_Contract__c);
        }
       Map<String, Contract> contracts = SM_ACHOrderHelper.getContractByIds(contractIds);
       for (Contract contract : contracts.values()) {
         if(contract.SM_Agreement_Status__c == null && contract.SM_Payment_methods__c==SM_ACHOrderHelper.PaymentMethodEnum.ACH){
            contract.SM_Send_Agreement__c=true;
         }
       }
      List<Database.SaveResult> sr = Database.update(contracts.values());
      System.debug('sr: ' + sr);

  }

    /**
    * @description This method update ACH Order Info
    * @author jpachon@legal-credit.com | 04-09-2021
    * @param newRecords
    **/
    private void updateACHOrderInfo(List<SM_Payment__c> newRecords) {
        Set<String> achOrderIds = new Set<String>();
        for (SM_Payment__c payment : newRecords) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
        Map<String, SM_ACH_Order__c> achOrders = SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds);
        System.debug('achOrders: ' + JSON.serialize(achOrders));
        for (SM_ACH_Order__c achOrder : achOrders.values()) {
            // SFDCMP-299 - JSPA
            if(achOrder.SM_Payment_Condition__c != SM_ACHOrderHelper.paymentCondition.FIXED_VALUE && (System.today() < achOrder.SM_Payment_End_Date__c || achOrder.SM_Payment_End_Date__c == null)){
                achOrder.SM_Fee_to_collect__c++;
            }
            Integer qtyOfPayments = achOrder.Payments__r.size();
            if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.ONCE) {
                achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                achOrder.SM_Next_Transaction_Date__c = null;
            } else if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.MONTHLY) {
                achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.INITIATED;
                if (achOrder.SM_Quantity_of_scheduled_fees__c > qtyOfPayments) {
                // if (achOrder.SM_Quantity_of_scheduled_fees__c > achOrder.SM_Fee_to_collect__c) {
                    achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
                } else if (achOrder.SM_Quantity_of_scheduled_fees__c == qtyOfPayments) {
                // } else if (achOrder.SM_Quantity_of_scheduled_fees__c == achOrder.SM_Fee_to_collect__c) {
                    achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                    achOrder.SM_Next_Transaction_Date__c = null;
                } else if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION) {
                    achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
                }
            }
        }
        List<Database.SaveResult> sr = Database.update(achOrders.values());
        System.debug('sr: ' + sr);
    }

    /**
    * @description This method update ACH Order and Contract according to payment status updates
    * @author jpachon@legal-credit.com | 04-12-2020
    * @param newRecordsMap
    **/
    private void paymentStatusUpdates(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        for (SM_Payment__c payment : newRecords) {
            SM_Payment__c oldPayment = (SM_Payment__c)oldRecordsMap.get(payment.Id);
            if (SM_Utils.isChangedField(payment, oldPayment, 'Payment_Status__c')) {
                String paymentStatus = payment.Payment_Status__c;
                Datetime dt = System.now();
                switch on paymentStatus {
                    when 'ACH TRANSMITTED' {
                        payment.SM_Date_ACH_Transmitted__c = dt;
                    }
                    when 'ACCEPTED' {
                        payment.SM_Date_ACH_Acepted__c = dt;
                        payment.SM_Date_Response__c = dt;
                    }
                    when 'REJECTED' {
                        payment.SM_Date_Response__c = dt;
                    }
                    when else {
                        System.debug('Payment status without implementation');
                    }
                }
            }
        }
    }

    /**
    * @description This method update ACH Order and Contract according to payment status updates
    * @author jpachon@legal-credit.com | 04-12-2020
    * @param newRecordsMap
    **/
    private void updateRelatedRecordsByPaymentStatusUpdates(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        Set<String> achOrderIds = new Set<String>();
        for (SM_Payment__c payment : newRecords) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
        Map<String, SM_ACH_Order__c> achOrdersById = SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds);
        List<SM_ACH_Order__c> achOrdersToUpdate = new List<SM_ACH_Order__c>();
        for (SM_Payment__c payment : newRecords) {
            SM_Payment__c oldPayment = (SM_Payment__c)oldRecordsMap.get(payment.Id);
            SM_ACH_Order__c achOrder = achOrdersById.get(payment.SM_ACH_Order__c);
            if (SM_Utils.isChangedField(payment, oldPayment, 'Payment_Status__c')) {
                String paymentStatus = payment.Payment_Status__c;
                // SMPII-141
                switch on paymentStatus {
                    when 'ACCEPTED' {
                        if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE) {
                            achOrder.SM_Failed_Transactions__c = 0;
                        }
                        if (achOrder.SM_Contract__r.Status == SM_ContractHelper.status.CANCELED) {
                            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.CANCELED;
                        }
                        if (achOrder.SM_Contract__r.Status == SM_ContractHelper.status.FINALIZED) {
                            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                        }
                        achOrdersToUpdate.add(achOrder);
                    }
                    when 'REJECTED' {
                        if (achOrder.SM_Contract__r.Status == SM_ContractHelper.status.CANCELED) {
                            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.CANCELED;
                        }
                        if (achOrder.SM_Contract__r.Status == SM_ContractHelper.status.FINALIZED) {
                            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                        }
                        achOrdersToUpdate.add(achOrder);
                    }
                    when else {
                        System.debug('Payment status without implementation');
                    }
                }
            }
        }
        List<Database.SaveResult> sr;
        if (!achOrdersToUpdate.isEmpty()) {
            sr = Database.update(achOrdersToUpdate);
            System.debug('achOrdersById - sr: ' + JSON.serialize(sr));
        }
    }

    /**
    * @description This method create ACH Orders when a payment was rejected
    * @author jpachon@legal-credit.com | 06-18-2020
    * @param newRecordsMap
    **/
    private void processRejectedPayments(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        // Map<String, SM_Payment__c> paymentsToProcess = new Map<String, SM_Payment__c>();
        Set<String> paymentsToProcess = new Set<String>();
        for (Id newRecordId : newRecordsMap.keySet()) {
            SM_Payment__c oldRecord = (SM_Payment__c)oldRecordsMap.get(newRecordId);
            SM_Payment__c newRecord = (SM_Payment__c)newRecordsMap.get(newRecordId);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'Payment_Status__c') && newRecord.Payment_Status__c == SM_PaymentHelper.status.REJECTED
                && SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c','ACH') == newRecord.recordTypeId) {
                paymentsToProcess.add(newRecord.Id);
            }
        }
        Map<String, SM_Payment__c> paymentsReadOnlyById = new Map<String, SM_Payment__c>(
            [SELECT Id, SM_ACH_Order__c, SM_ACH_Order__r.SM_Payment_Type__c, SM_ACH_Order__r.SM_Billing_Email__c,
                SM_ACH_Order__r.SM_Payment_Method__c, SM_ACH_Order__r.SM_Payment_Frequency__c,
                SM_ACH_Order__r.SM_Payment_Status__c, SM_Contract__r.Status,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c,
                (SELECT Id FROM Payments__r), (SELECT Id FROM ACH_Orders__r)
                FROM SM_Payment__c
                WHERE Id IN :paymentsToProcess]);
        SM_ACH_Order__c newACHOrder;
        List<SM_ACH_Order__c> achOrdersToInsert = new List<SM_ACH_Order__c>();
        List<SM_ACH_Order__c> latePaymentACHOrdersToUpdate = new List<SM_ACH_Order__c>();
        for (SM_Payment__c paymentRO : paymentsReadOnlyById.values()) {
            // SMPII-141
            if (paymentRO.SM_Contract__r.Status == SM_ContractHelper.status.CANCELED || paymentRO.SM_Contract__r.Status == SM_ContractHelper.status.FINALIZED) {
                continue;
            }
            Integer daysToCollectPenalty = paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c != null ? Integer.valueOf(paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c) : 0;
            if (paymentRO.Payments__r.size() > 0 || paymentRO.ACH_Orders__r.size() > 0) {
                continue;
            }
             // SMPII-57 CJ 26-10-2021
            if (paymentRO.SM_ACH_Order__r.SM_Payment_Type__c == 'Late payment fee' && paymentRO.SM_ACH_Order__r.SM_Payment_Status__c == 'Completed'
                && paymentRO.SM_ACH_Order__r.SM_Payment_Frequency__c == 'Once' && (paymentRO.SM_Contract__r.Status == 'Payment Process'  || paymentRO.SM_Contract__r.Status == 'Activated')) {
                latePaymentACHOrdersToUpdate.add(new SM_ACH_Order__c(
                    Id = paymentRO.SM_ACH_Order__c,
                    SM_Payment_Status__c = 'Stopped'
                    //SM_Next_Transaction_Date__c = System.today().addDays(daysToCollectPenalty)
                ));
                continue;
            }
            SM_Payment__c changedPayment = (SM_Payment__c)newRecordsMap.get(paymentRO.Id);
            Decimal latePaymentFee = paymentRO?.SM_Contract__r?.SM_Opportunity__r?.SM_Company_Setting__r?.SM_Late_payment_fee__c != null ? paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c : 0;
            newACHOrder = new SM_ACH_Order__c(
                SM_Payment_Type__c = 'Late payment fee',
                SM_Payment_Method__c = paymentRO.SM_ACH_Order__r.SM_Payment_Method__c,
                SM_Contract__c = changedPayment.SM_Contract__c,
                SM_Billing_Email__c = paymentRO.SM_ACH_Order__r.SM_Billing_Email__c,
                SM_Payment_Frequency__c = 'Once',
                SM_Payment_Status__c = 'Stopped',
                SM_Fee_to_collect__c = null,
                SM_Total__c = changedPayment.SM_Amount__c + latePaymentFee,
                SM_Penalty_value__c = latePaymentFee,
                SM_Penalty_date__c = System.today(),
                SM_Apply_penalty__c = true,
                SM_User_who_applies_the_penalty__c = UserInfo.getUserId(),
                SM_Payment_Start_Date__c = System.today().addDays(daysToCollectPenalty),
                SM_Payment_End_Date__c = System.today().addDays(daysToCollectPenalty),
                SM_Next_Transaction_Date__c = System.today().addDays(daysToCollectPenalty),
                SM_Payment_Condition__c = 'Fixed value',
                SM_Failed_payment__c = changedPayment.Id
            );
            achOrdersToInsert.add(newACHOrder);
        }
        List<Database.SaveResult> sr;
        if (achOrdersToInsert != null && !achOrdersToInsert.isEmpty()) {
            sr = Database.insert(achOrdersToInsert);
            System.debug('sr: ' + sr);
        }
        if (!latePaymentACHOrdersToUpdate.isEmpty()) {
            System.debug('latePaymentACHOrdersToUpdate: ' + latePaymentACHOrdersToUpdate);
            sr = Database.update(latePaymentACHOrdersToUpdate);
            System.debug('sr: ' + sr);
        }
    }


      /**
    * @description This method create ACH Orders when a payment was rejected
    * @author cjimenez@legal-credit.com | 07-12-2021
    * @param newRecordsMap
    **/
    private void processRejectedPaymentsChargentOrder(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
            //calp jul 2026
        if (!hasChargentObjectAccess()) {
            return;
        }
        // Map<String, SM_Payment__c> paymentsToProcess = new Map<String, SM_Payment__c>();
        Set<String> paymentsToProcess = new Set<String>();
        Set<String> contraId = new Set<String>();
        Set<Id> chargentTransactionIds = new Set<Id>();
        // SFDCMP-389 CJ 29-09-2021
		for (Id newRecordId : newRecordsMap.keySet()) {
            SM_Payment__c newRecord = (SM_Payment__c)newRecordsMap.get(newRecordId);
            if (newRecord.Payment_Status__c == SM_PaymentHelper.status.REJECTED
                && SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c','Credit Card') == newRecord.recordTypeId
                && String.isNotBlank(newRecord.SM_Chargent_Orders_Transaction__c)) {
                paymentsToProcess.add(newRecord.Id);
                chargentTransactionIds.add(newRecord.SM_Chargent_Orders_Transaction__c);
            }
        }

        if (paymentsToProcess.isEmpty() || chargentTransactionIds.isEmpty()) {
            return;
        }

        Map<String, SM_Payment__c> paymentsReadOnlyById = new Map<String, SM_Payment__c>(
            [SELECT Id,
                SM_Contract__c,
                SM_Chargent_Orders_Transaction__c,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.StatusCreditCardLatePaymentFee__c,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c,
                SM_Contract__r.Status,
                (SELECT Id FROM Payments__r), (SELECT Id FROM Chargent_Orders__r)
                FROM SM_Payment__c
                WHERE Id IN :paymentsToProcess]
                );

        Map<Id, ChargentOrders__Transaction__c> chargentTransactionsById = new Map<Id, ChargentOrders__Transaction__c>(
            [SELECT Id, ChargentOrders__Order__c, ChargentOrders__Response_Status__c
             FROM ChargentOrders__Transaction__c
             WHERE Id IN :chargentTransactionIds]
        );

        Set<Id> chargentOrderIds = new Set<Id>();
        for (ChargentOrders__Transaction__c chargentTransaction : chargentTransactionsById.values()) {
            if (chargentTransaction.ChargentOrders__Order__c != null) {
                chargentOrderIds.add(chargentTransaction.ChargentOrders__Order__c);
            }
        }

        if (chargentOrderIds.isEmpty()) {
            return;
        }

        Map<Id, ChargentOrders__ChargentOrder__c> chargentOrdersById = new Map<Id, ChargentOrders__ChargentOrder__c>(
            [SELECT Id, ChargentOrders__Payment_Status__c, SM_Payment_Type__c, CreatedDate
             FROM ChargentOrders__ChargentOrder__c
             WHERE Id IN :chargentOrderIds]
        );

        List<ChargentOrders__ChargentOrder__c> chargentOrdersToInsert = new List<ChargentOrders__ChargentOrder__c>();

        for (SM_Payment__c paymentRO : paymentsReadOnlyById.values()) {
            ChargentOrders__Transaction__c chargentTransaction = chargentTransactionsById.get((Id)paymentRO.SM_Chargent_Orders_Transaction__c);
            if(chargentTransaction != null && String.isNotBlank(chargentTransaction.ChargentOrders__Order__c))
               contraId.add(paymentRO.SM_Contract__c);
        }

        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        structure.AdditionalFields = '';
        structure.sObjectName = 'ChargentOrders__ChargentOrder__c';
        structure.whereClause = new map<String,List<object>>{'Contract__c'=>new List<object>()};
        structure.orderByParent ='';
        for(String idData: contraId){
            structure.whereClause.get('Contract__c').add(idData);
        }
        map<Id,SObject> orders  = new Map<Id,SObject>(SM_Utils.getDynamicQuery(structure));
       
   
        for (SM_Payment__c paymentRO : paymentsReadOnlyById.values()) {
            Boolean createLatePaymentFee=true;
                 ChargentOrders__Transaction__c chargentTransaction = chargentTransactionsById.get((Id)paymentRO.SM_Chargent_Orders_Transaction__c);
                 ChargentOrders__ChargentOrder__c currentChargentOrder = chargentTransaction == null ? null : chargentOrdersById.get(chargentTransaction.ChargentOrders__Order__c);
                 if(currentChargentOrder == null){
                     continue;
                 }
                 if(currentChargentOrder.SM_Payment_Type__c == 'Late payment fee'){
                createLatePaymentFee=false;
                continue;
             }
             
         if(createLatePaymentFee){
            ChargentOrders__ChargentOrder__c newChargentOrder;
            ChargentOrders__ChargentOrder__c newChargentOrderClone;
            SM_Payment__c changedPayment = (SM_Payment__c)newRecordsMap.get(paymentRO.Id);
            Decimal latePaymentFee = paymentRO?.SM_Contract__r?.SM_Opportunity__r?.SM_Company_Setting__r?.SM_Late_payment_fee__c != null ? paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c : 0;
            newChargentOrderClone=(ChargentOrders__ChargentOrder__c)orders.get(chargentTransaction.ChargentOrders__Order__c);
            if (newChargentOrderClone == null) {
                continue;
            }
            newChargentOrder=newChargentOrderClone.clone();
            newChargentOrder.SM_Migrated__c = false; // JSPA - 08/26/2021 - Case 00001012
            newChargentOrder.SM_Migration_Date__c = null; // JSPA - 08/26/2021 - Case 00001012
            newChargentOrder.SM_Payment_Type__c = 'Late payment fee';
            newChargentOrder.ChargentOrders__Payment_Frequency__c='Once';
            newChargentOrder.ChargentOrders__Payment_Stop__c='Count';
            newChargentOrder.ChargentOrders__Payment_Count__c=1;
            newChargentOrder.ChargentOrders__Payment_Status__c=paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.StatusCreditCardLatePaymentFee__c;
            newChargentOrder.SM_Fee_to_collect__c=null;
            Date paymentDate= null;
            paymentDate=paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c != null? System.today().addDays(Integer.valueOf(paymentRO.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c)) : System.today();
            newChargentOrder.ChargentOrders__Payment_Start_Date__c=paymentDate;
            newChargentOrder.ChargentOrders__Payment_End_Date__c=paymentDate;
            newChargentOrder.ChargentOrders__Next_Transaction_Date__c=null;
            newChargentOrder.ChargentOrders__Charge_Date__c='';
            newChargentOrder.SM_Purpose_of_Payment__c='Collect';
            newChargentOrder.SM_Failed_Payment__c=paymentRO.id;
            newChargentOrder.SM_Apply_Penalty__c=true;
            newChargentOrder.SM_User_Who_Applies_Penalty__c=UserInfo.getUserId();
            Decimal currentSubtotal = newChargentOrder.ChargentOrders__Subtotal__c != null ? newChargentOrder.ChargentOrders__Subtotal__c : 0;
            newChargentOrder.ChargentOrders__Subtotal__c = currentSubtotal + latePaymentFee;
            newChargentOrder.SM_Penalty_Date__c=currentChargentOrder.CreatedDate;
            newChargentOrder.SM_Penalty_Value__c=latePaymentFee;

              chargentOrdersToInsert.add(newChargentOrder);
          }
        }
        if (chargentOrdersToInsert != null && !chargentOrdersToInsert.isEmpty()) {
            List<Database.SaveResult> sr = Database.insert(chargentOrdersToInsert);
        }
        Set<String> charOrderIdUpdate = new Set<String>();
        List<ChargentOrders__ChargentOrder__c> chargenOrderUpdate = new List<ChargentOrders__ChargentOrder__c>();

        for (ChargentOrders__ChargentOrder__c cargentOrder : chargentOrdersToInsert){
             charOrderIdUpdate.add(cargentOrder.id);
        }

        for(ChargentOrders__ChargentOrder__c cargentOrder:[SELECT id
                                                            ,SM_IVU_Municipal_Amount__c
                                                            ,SM_IVU_State_Amount__c
                                                            ,ChargentOrders__Subtotal__c
                                                            FROM ChargentOrders__ChargentOrder__c
                                                            WHERE id =: charOrderIdUpdate ]){
               Decimal municipalTax = cargentOrder.SM_IVU_Municipal_Amount__c != null ? cargentOrder.SM_IVU_Municipal_Amount__c : 0;
               Decimal stateTax = cargentOrder.SM_IVU_State_Amount__c != null ? cargentOrder.SM_IVU_State_Amount__c : 0;
               Decimal subtotal = cargentOrder.ChargentOrders__Subtotal__c != null ? cargentOrder.ChargentOrders__Subtotal__c : 0;
               cargentOrder.ChargentOrders__Tax__c = municipalTax + stateTax;
               cargentOrder.ChargentOrders__Charge_Amount__c = subtotal + municipalTax + stateTax;
             chargenOrderUpdate.add(cargentOrder);
            }

        if (chargenOrderUpdate != null && !chargenOrderUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(chargenOrderUpdate);
        }
    }
}