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
    * @description Chargent app is permanently disabled; this method is now a permanent
    * no-op. Body removed 2026-08 (was ~150 lines of unreachable Chargent SOQL/DML) since
    * hasChargentObjectAccess() always returns false. Original logic preserved in git
    * history (commit 1869663) if Chargent is ever reinstated.
    * @author cjimenez@legal-credit.com | 07-12-2021
    * @param newRecordsMap
    **/
    private void processRejectedPaymentsChargentOrder(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        return;
    }
}