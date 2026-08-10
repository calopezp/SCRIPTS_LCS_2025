/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 02-20-2022
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   06-19-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
 * 1.1   12-10-2021   Camilo J. Jiemenz B ->    cjimenez@legal-credit.com   Initial Version
**/
public without sharing class SM_PaymentProcessController {

    private Map<String,Contract> newContractsMap;
    private Map<String,Contract> oldContractsMap;
    private Set<String> paymentMethodIds;
    private Map<String,SM_Payment_Method__c> paymentMethodsById;
    private Map<String,Contract> contractInfoWithRelatedData;
    private Map<String,ChargentOrders__ChargentOrder__c> chargentBaseRecordsById;
    private String achRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment_Method__c', 'ACH');
    private String creditCardRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment_Method__c', 'Credit Card');

    public SM_PaymentProcessController(Map<String, Contract> newContractsMap, Map<String, Contract> oldContractsMap, Set<String> paymentMethodIds) {
        this.newContractsMap = newContractsMap;
        this.oldContractsMap = oldContractsMap;
        this.paymentMethodIds = paymentMethodIds;
        paymentMethodsById = new Map<String, SM_Payment_Method__c>(
            [SELECT Id, RecordTypeId, SM_Credit_Card_expiration_year__c, SM_Credit_Card_expiration_month__c, SM_Credit_Card_Number__c, SM_Credit_Card_Franchise__c, SM_Credit_Card_Name__c, SM_Card_Token__c, SM_Chargent_Order__c
            FROM SM_Payment_Method__c
            WHERE Id IN :paymentMethodIds]
        );
        contractInfoWithRelatedData = new Map<String,Contract>(
            [SELECT Id, SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c, SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c, SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,
            (SELECT Id, SM_Contract__c, SM_Payment_Status__c, SM_Payment_Frequency__c, SM_Payment_Count__c, SM_Payment_Stop__c, SM_Payment_Start_Date__c, SM_Total__c, SM_Payment_Type__c, SM_Quantity_of_scheduled_fees__c,
                SM_Fee_to_collect__c, SM_Payment_End_Date__c, SM_Next_Transaction_Date__c, SM_Penalty_value__c, SM_Failed_payment__c, SM_Penalty_date__c, SM_Approval_status__c, SM_Reason_to_approve_exoneration__c, SM_Apply_penalty__c,
                SM_Failed_payment__r.SM_ACH_Order__r.SM_Payment_Type__c
                FROM ACH_Orders__r),
            (SELECT Id, ChargentOrders__Status__c, ChargentOrders__Payment_Status__c, SM_Purpose_of_Payment__c, SM_Payment_Type__c, Contract__c, ChargentOrders__Payment_Frequency__c,
                ChargentOrders__Subtotal__c, ChargentOrders__Payment_Start_Date__c, ChargentOrders__Payment_End_Date__c, ChargentOrders__Next_Transaction_Date__c, SM_Fee_to_collect__c,
                ChargentOrders__Payment_Count__c, ChargentOrders__Transaction_Count_Recurring__c, SM_Apply_Penalty__c, SM_Failed_Payment__c, SM_Penalty_Date__c, SM_Penalty_Value__c,
                SM_Approval_status__c, SM_Reason_to_approve_exoneration__c, SM_User_Who_Applies_Penalty__c
                FROM Chargent_Orders__r WHERE SM_IsRegisterToken__c = false)
            FROM Contract WHERE Id IN :newContractsMap.keySet()]
        );
        getChargentBaseRecords(paymentMethodsById);
    }

    private void getChargentBaseRecords(Map<String,SM_Payment_Method__c> paymentMethodsById) {
        chargentBaseRecordsById = new Map<String,ChargentOrders__ChargentOrder__c>();
        List<Object> chargentBaseRecordIds = new List<Object>();
        for (String paymentMethodId : paymentMethodsById.keySet()) {
            SM_Payment_Method__c paymentMethod = paymentMethodsById.get(paymentMethodId);
            if (paymentMethod.RecordTypeId == creditCardRecordTypeId && String.isNotBlank(paymentMethod.SM_Chargent_Order__c)) {
                chargentBaseRecordIds.add(paymentMethod.SM_Chargent_Order__c);
            }
        }
        if (!chargentBaseRecordIds.isEmpty()) {
            SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
            structure = new SM_Utils.DynamicQueryStructure();
            structure.sObjectName = 'ChargentOrders__ChargentOrder__c';
            structure.whereClause = new map<String,List<object>>{
                'Id'=> chargentBaseRecordIds
            };
            structure.orderByParent ='';
            structure.AdditionalFields = '';
            List<ChargentOrders__ChargentOrder__c> chargentBaseRecords  = (List<ChargentOrders__ChargentOrder__c>)SM_Utils.getDynamicQuery(structure);
            if (chargentBaseRecords != null && chargentBaseRecords.size() > 0) {
                for (ChargentOrders__ChargentOrder__c chargentBaseRecord : chargentBaseRecords) {
                    chargentBaseRecordsById.put(chargentBaseRecord.Id, chargentBaseRecord);
                }
            }
        }
    }

    public void processRecords() {
        System.debug('Executing SM_PaymentProcessController.processRecords');
        System.debug('newContractsMap: ' + JSON.serialize(newContractsMap));
        System.debug('oldContractsMap: ' + JSON.serialize(oldContractsMap));
        System.debug('paymentMethodIds: ' + JSON.serialize(paymentMethodIds));
        // Contract with new payment method (ACH) and old payment method (ACH)
        Set<String> contractsWithACHFromACH = new Set<String>();
        // Contract with new payment method (Chargent) and old payment method (Chargent)
        Set<String> contractsWithChargentFromChargent = new Set<String>();
        // Contract with new payment method (ACH) and old payment method (Chargent)
        Set<String> contractsWithACHFromChargent = new Set<String>();
        // Contract with new payment method (Chargent) and old payment method (ACH)
        Set<String> contractsWithChargentFromACH = new Set<String>();
        // Map<String, ContractWrapper> contractsWithChargentFromACH = new Map<String, ContractWrapper>();
        // ContractWrapper contractInfo;
        for (Contract newContract : newContractsMap.values()) {
            // In this part, we have only the contracts that changed its payment method
            Contract oldContract = oldContractsMap.get(newContract.Id);
            SM_Payment_Method__c oldPaymentMethod = paymentMethodsById.get(oldContract.SM_Payment_Method__c);
            SM_Payment_Method__c newPaymentMethod = paymentMethodsById.get(newContract.SM_Payment_Method__c);
            // contractInfo = new  ContractWrapper(newContract.Id, oldPaymentMethod.Id, newPaymentMethod.Id);
            if (newPaymentMethod.RecordTypeId == achRecordTypeId && oldPaymentMethod.RecordTypeId == achRecordTypeId) {
                contractsWithACHFromACH.add(newContract.Id);
            } else if (newPaymentMethod.RecordTypeId == creditCardRecordTypeId && oldPaymentMethod.RecordTypeId == creditCardRecordTypeId) {
                contractsWithChargentFromChargent.add(newContract.Id);
            } else if (newPaymentMethod.RecordTypeId == achRecordTypeId && oldPaymentMethod.RecordTypeId == creditCardRecordTypeId) {
                contractsWithACHFromChargent.add(newContract.Id);
            } else if (newPaymentMethod.RecordTypeId == creditCardRecordTypeId && oldPaymentMethod.RecordTypeId == achRecordTypeId) {
                contractsWithChargentFromACH.add(newContract.Id);
                // contractsWithChargentFromACH.put(contractInfo.contractId, contractInfo);
            } else {
                System.debug('This step is not being considered');
            }
        }
        if (!contractsWithACHFromACH.isEmpty()) {
            processContractWithNewACHFromOldACHPaymentMethod(contractsWithACHFromACH);
        }
        if (!contractsWithChargentFromChargent.isEmpty()) {
            processContractWithNewChargentFromOldChargentPaymentMethod(contractsWithChargentFromChargent);
        }
        if (!contractsWithACHFromChargent.isEmpty()) {
            processContractWithNewACHFromOldChargentPaymentMethod(contractsWithACHFromChargent);
        }
        if (!contractsWithChargentFromACH.isEmpty()) {
            processContractWithNewChargentFromOldACHPaymentMethod(contractsWithChargentFromACH);
        }
    }

    private void processContractWithNewACHFromOldACHPaymentMethod(Set<String> recordIdsToProcess) {
        // ACH -> ACH
        System.debug('Executing processContractWithNewACHFromOldACHPaymentMethod: - recordToProcess:' + JSON.serialize(recordIdsToProcess));
        List<String> paymentStatusToAvoid = new List<String>{
            SM_ACHOrderHelper.paymentStatus.COMPLETED,
            SM_ACHOrderHelper.paymentStatus.CANCELED
        };
        Map<String, SM_ACH_Order__c> achOrdersToUpdateById = new Map<String, SM_ACH_Order__c>(
            [SELECT Id, SM_Contract__c, SM_Payment_Method__c FROM SM_ACH_Order__c WHERE SM_Contract__c IN :recordIdsToProcess AND SM_Payment_Status__c NOT IN :paymentStatusToAvoid]
        );
        List<SM_ACH_Order__c> achOrdersToUpdate = new List<SM_ACH_Order__c>();
        for (String achOrderId : achOrdersToUpdateById.keySet()) {
            SM_ACH_Order__c achOrderToUpdate = achOrdersToUpdateById.get(achOrderId);
            Contract newContract = newContractsMap.get(achOrderToUpdate.SM_Contract__c);
            achOrderToUpdate.SM_Payment_Method__c = newContract.SM_Payment_Method__c;
            achOrdersToUpdate.add(achOrderToUpdate);
        }
        if (!achOrdersToUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(achOrdersToUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }
    }

    private void processContractWithNewChargentFromOldChargentPaymentMethod(Set<String> recordIdsToProcess) {
        // Chargent -> Chargent
        System.debug('Executing processContractWithNewChargentFromOldChargentPaymentMethod: - recordToProcess:' + JSON.serialize(recordIdsToProcess));
        Map<String, ChargentOrders__ChargentOrder__c> chargentOrdersToUpdateById = new Map<String, ChargentOrders__ChargentOrder__c>([
            SELECT Id, Contract__c FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c IN :recordIdsToProcess AND SM_IsRegisterToken__c = false
            AND ((ChargentOrders__Payment_Status__c IN ('Recurring','Error','Stopped'))
            OR (ChargentOrders__Payment_Status__c = 'Stopped' AND SM_Payment_Type__c = 'Late payment fee' AND SM_Apply_Penalty__c = true AND SM_Purpose_of_Payment__c = 'Collect'))]
        );
        List<ChargentOrders__ChargentOrder__c> chargentOrdersToUpdate = new List<ChargentOrders__ChargentOrder__c>();
        for (String chargentOrderId : chargentOrdersToUpdateById.keySet()) {
            ChargentOrders__ChargentOrder__c chargentOrderToUpdate = chargentOrdersToUpdateById.get(chargentOrderId);
            Contract newContract = newContractsMap.get(chargentOrderToUpdate.Contract__c);
            SM_Payment_Method__c newPaymentMethod = paymentMethodsById.get(newContract.SM_Payment_Method__c);
            // Old fields
            // chargentOrderToUpdate.ChargentOrders__Card_Year_Indicator__c = newPaymentMethod.SM_Credit_Card_expiration_year__c;
            // chargentOrderToUpdate.ChargentOrders__Card_Month_Indicator__c = newPaymentMethod.SM_Credit_Card_expiration_month__c;
            // chargentOrderToUpdate.ChargentOrders__Card_Last_4__c = newPaymentMethod.SM_Credit_Card_Number__c.right(4);
            // chargentOrderToUpdate.ChargentOrders__Card_Type__c = newPaymentMethod.SM_Credit_Card_Franchise__c;
            // chargentOrderToUpdate.ChargentOrders__Billing_First_Name__c = newPaymentMethod.SM_Credit_Card_Name__c;
            // chargentOrderToUpdate.ChargentOrders__Tokenization__c = newPaymentMethod.SM_Card_Token__c;
            // New fields
            chargentOrderToUpdate.ChargentOrders__Card_Last_4__c = newPaymentMethod.SM_Credit_Card_Number__c.right(4);
            chargentOrderToUpdate.ChargentOrders__Card_Year_Indicator__c = newPaymentMethod.SM_Credit_Card_expiration_year__c;
            chargentOrderToUpdate.ChargentOrders__Card_Expiration_Year__c = newPaymentMethod.SM_Credit_Card_expiration_year__c;
            chargentOrderToUpdate.ChargentOrders__Card_Month_Indicator__c = newPaymentMethod.SM_Credit_Card_expiration_month__c;
            chargentOrderToUpdate.ChargentOrders__Card_Expiration_Month__c = newPaymentMethod.SM_Credit_Card_expiration_month__c;
            chargentOrderToUpdate.ChargentOrders__Tokenization__c = newPaymentMethod.SM_Card_Token__c;
            chargentOrdersToUpdate.add(chargentOrderToUpdate);
        }
        if (!chargentOrdersToUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(chargentOrdersToUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }
    }

    // --------------------------------------------------------------- Chargent Order -> ACH ----------------------------------------------

    private void processContractWithNewACHFromOldChargentPaymentMethod(Set<String> recordIdsToProcess) {
        // Chargent -> ACH
        System.debug('Executing processContractWithNewACHFromOldChargentPaymentMethod: - recordToProcess:' + JSON.serialize(recordIdsToProcess));
        Map<String,ChargentOrders__ChargentOrder__c> chargentOrdersToProcess = new Map<String,ChargentOrders__ChargentOrder__c>();
        Set<String> paymentStatusToSubscriptionAndFixTerm = new Set<String>{
            SM_ChargentOrderHelper.paymentStatus.RECURRING,
            SM_ChargentOrderHelper.paymentStatus.AUTOMATED_COLLECTION,
            SM_ChargentOrderHelper.paymentStatus.ERROR
        };
        for (String contractId : contractInfoWithRelatedData.keySet()) {
            Contract newContract = newContractsMap.get(contractId);
            Contract oldContract = oldContractsMap.get(contractId);
            List<ChargentOrders__ChargentOrder__c> chargentOrders = contractInfoWithRelatedData.get(contractId).Chargent_Orders__r;
            for (ChargentOrders__ChargentOrder__c chargentOrder : chargentOrders) {
                // Step 1 & 2: AC Pending 
                if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.AC
                    && (chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.RECURRING
                    || chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.ERROR)) {
                    chargentOrdersToProcess.put(chargentOrder.Id, chargentOrder);
                }
                // Step 3: AC Late payment fee
                //SMPII-7 CJ 25-10-2021
                if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE
                    && (chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.STOPPED
                    || chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.ERROR
                    || chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.RECURRING)
                    && chargentOrder.SM_Purpose_of_Payment__c == SM_ChargentOrderHelper.purposeOfPayment.COLLECT_STR) {
                    chargentOrdersToProcess.put(chargentOrder.Id, chargentOrder);
                }
                // Step 4: Subscription
                if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.SUBSCRIPTION
                    && paymentStatusToSubscriptionAndFixTerm.contains(chargentOrder.ChargentOrders__Payment_Status__c)) {
                    chargentOrdersToProcess.put(chargentOrder.Id, chargentOrder);
                }
                // Step 5: Fix Term - Fee
                if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.FEE
                    && paymentStatusToSubscriptionAndFixTerm.contains(chargentOrder.ChargentOrders__Payment_Status__c)) {
                    chargentOrdersToProcess.put(chargentOrder.Id, chargentOrder);
                }

            }
        }
        if (!chargentOrdersToProcess.isEmpty()) {
            processChargentOrdersWithCreditCardPaymentType(chargentOrdersToProcess);
        }



        // Map<String,ChargentOrders__ChargentOrder__c> achOrdersToProcess = new Map<String,ChargentOrders__ChargentOrder__c>(); - Para chargent  Order
        // for (String contractId : contractInfoWithRelatedData.keySet()) {
        //     Contract newContract = newContractsMap.get(contractId);
        //     Contract oldContract = oldContractsMap.get(contractId);
        //     List<ChargentOrders__ChargentOrder__c> achOrders = contractInfoWithRelatedData.get(contractId).Chargent_Orders__r;
        //     for (ChargentOrders__ChargentOrder__c achOrder : achOrders) {
                // TODO: Agregar los filtros correspondientes a Chargent Order
        //         if (achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.PENDING || achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.INITIATED
        //             || achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.STOPPED) {
        //             achOrdersToProcess.put(achOrder.Id, achOrder);
        //         }
        //     }
        // }
        // if (!achOrdersToProcess.isEmpty()) {
        //     processACHOrdersWithACHPaymentType(achOrdersToProcess);
        // }
    }

    private void processChargentOrdersWithCreditCardPaymentType(Map<String,ChargentOrders__ChargentOrder__c> chargentOrdersToProcess) {
        if (!chargentOrdersToProcess.isEmpty()) {
            createACHOrdersAndUpdateAssetFees(chargentOrdersToProcess);
            cancelChargentOrderds(chargentOrdersToProcess);
        }
    }

    private void createACHOrdersAndUpdateAssetFees(Map<String,ChargentOrders__ChargentOrder__c> chargentOrdersToProcess) {
        Map<String, SM_ACH_Order__c> achOrdersToCreateByChargentOrderId = new Map<String, SM_ACH_Order__c>();
        Map<String,List<SM_Asset_Fee__c>> assetFeesByChargentOrderIds = getAssetFeesByChargentIds(chargentOrdersToProcess.keySet());
        for (String chargentOrderId : chargentOrdersToProcess.keySet()) {
            ChargentOrders__ChargentOrder__c chargentOrder = chargentOrdersToProcess.get(chargentOrderId);
            SM_ACH_Order__c achOrderToCreate = createACHOrder(chargentOrder);
            if (achOrderToCreate != null) achOrdersToCreateByChargentOrderId.put(chargentOrder.Id, achOrderToCreate);
        }
        if (!achOrdersToCreateByChargentOrderId.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(achOrdersToCreateByChargentOrderId.values());
            for (Database.SaveResult result  : results) {
                if (result.isSuccess()) {
                    result.getId();
                } else {
                    for (Database.Error error : result.getErrors()) {
                        System.debug('error: statusCode ' + error.getStatusCode() + ' - message ' + error.getMessage());
                    }
                }
            }
            List<SM_Asset_Fee__c> assetFeesToUpdate = new List<SM_Asset_Fee__c>();
            for (String chargentOrderId : achOrdersToCreateByChargentOrderId.keySet()) {
                SM_ACH_Order__c achOrderCreated = achOrdersToCreateByChargentOrderId.get(chargentOrderId);
                ChargentOrders__ChargentOrder__c currentChargentOrder = chargentOrdersToProcess.get(chargentOrderId);
                List<SM_Asset_Fee__c> assetFees = assetFeesByChargentOrderIds.containsKey(chargentOrderId) ? assetFeesByChargentOrderIds.get(chargentOrderId) : new List<SM_Asset_Fee__c>();
                for (SM_Asset_Fee__c assetFee : assetFees) {
                    if ((currentChargentOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE && assetFee.SM_Position__c >= currentChargentOrder.SM_Fee_to_collect__c)
                            || currentChargentOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION) {
                        assetFeesToUpdate.add(new SM_Asset_Fee__c(Id = assetFee.Id, SM_Chargent_Order__c = null, SM_ACH_Order__c = achOrderCreated.Id));
                    }
                }
            }
            if (!assetFeesToUpdate.isEmpty()) {
                results = Database.update(assetFeesToUpdate);
                System.debug('results: ' + results);
            }
        }
    }

    private Map<String,List<SM_Asset_Fee__c>> getAssetFeesByChargentIds(Set<String> chargentOrderIds) {
        Map<String,List<SM_Asset_Fee__c>> assetFeesByChargentOrderIds = new Map<String,List<SM_Asset_Fee__c>>();
        for (SM_Asset_Fee__c assetFee : [SELECT Id, SM_Chargent_Order__c, SM_Position__c FROM SM_Asset_Fee__c WHERE SM_Chargent_Order__c IN :chargentOrderIds]) {
            if (!assetFeesByChargentOrderIds.containsKey(assetFee.SM_Chargent_Order__c)) assetFeesByChargentOrderIds.put(assetFee.SM_Chargent_Order__c, new List<SM_Asset_Fee__c>()) ;
            assetFeesByChargentOrderIds.get(assetFee.SM_Chargent_Order__c).add(assetFee);
        }
        return assetFeesByChargentOrderIds;
    }

    private void cancelChargentOrderds(Map<String,ChargentOrders__ChargentOrder__c> chargentOrdersToProcess) {
        List<ChargentOrders__ChargentOrder__c> chargentOrdersToCancel = new List<ChargentOrders__ChargentOrder__c>();
        for (String chargentOrderId : chargentOrdersToProcess.keySet()) {
            ChargentOrders__ChargentOrder__c chargentOrderToCancel = new ChargentOrders__ChargentOrder__c();
            chargentOrderToCancel.Id = chargentOrderId;
            // CJ 12-10-2021 It is modified to change canceled status
            chargentOrderToCancel.ChargentOrders__Payment_Status__c = SM_ChargentOrderHelper.paymentStatus.CANCELED;
            chargentOrdersToCancel.add(chargentOrderToCancel);
        }
        if (!chargentOrdersToCancel.isEmpty()) {
            List<Database.SaveResult> results = Database.update(chargentOrdersToCancel);
            for (Database.SaveResult result  : results) {
                if (result.isSuccess()) {
                    result.getId();
                } else {
                    for (Database.Error error : result.getErrors()) {
                        System.debug('error: statusCode ' + error.getStatusCode() + ' - message ' + error.getMessage());
                    }
                }
            }
        }
    }

    private SM_ACH_Order__c createACHOrder(ChargentOrders__ChargentOrder__c chargentOrder) {
        Contract newContract = newContractsMap.get(chargentOrder.Contract__c);
        SM_Payment_Method__c newPaymentMethod = paymentMethodsById.get(newContract.SM_Payment_Method__c);
        SM_ACH_Order__c achOrderToCreate = new SM_ACH_Order__c();
        achOrderToCreate.SM_Billing_Email__c = newContract.SM_Email_to_send_contract__c;
        achOrderToCreate.SM_Payment_Method__c = newPaymentMethod.Id;
        achOrderToCreate.SM_Contract__c = newContract.Id;
        achOrderToCreate.SM_Payment_Type__c = chargentOrder.SM_Payment_Type__c;
        achOrderToCreate.SM_Payment_Frequency__c = chargentOrder.ChargentOrders__Payment_Frequency__c;
        achOrderToCreate.SM_Payment_Count__c = chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.AC || chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.FEE ? chargentOrder.ChargentOrders__Payment_Count__c : null;
        achOrderToCreate.SM_Quantity_of_scheduled_fees__c = chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.FEE ? (chargentOrder.ChargentOrders__Payment_Count__c - chargentOrder.ChargentOrders__Transaction_Count_Recurring__c) : null;
        if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.SUBSCRIPTION || chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.FEE) {
            achOrderToCreate.SM_Fee_to_collect__c = chargentOrder.SM_Fee_to_collect__c;
        }
        achOrderToCreate.SM_Total__c = chargentOrder.ChargentOrders__Subtotal__c;
        achOrderToCreate.SM_Payment_Start_Date__c = chargentOrder.ChargentOrders__Payment_Start_Date__c;
        achOrderToCreate.SM_Payment_End_Date__c = chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.AC ? chargentOrder.ChargentOrders__Payment_Start_Date__c : chargentOrder.ChargentOrders__Payment_End_Date__c;
        achOrderToCreate.SM_Next_Transaction_Date__c = chargentOrder.ChargentOrders__Next_Transaction_Date__c != null ? chargentOrder.ChargentOrders__Next_Transaction_Date__c : chargentOrder.ChargentOrders__Payment_Start_Date__c;
        // SFDCMP-384
        if(chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE) {
            achOrderToCreate.SM_Failed_payment__c = chargentOrder.SM_Failed_Payment__c;
            achOrderToCreate.SM_Apply_penalty__c = chargentOrder.SM_Apply_Penalty__c;
            achOrderToCreate.SM_Penalty_date__c = chargentOrder.SM_Penalty_Date__c != null ? chargentOrder.SM_Penalty_Date__c.date() : null;
            achOrderToCreate.SM_Penalty_value__c = chargentOrder.SM_Penalty_Value__c;
            achOrderToCreate.SM_Approval_status__c = chargentOrder.SM_Approval_status__c;
            achOrderToCreate.SM_Reason_to_approve_exoneration__c = chargentOrder.SM_Reason_to_approve_exoneration__c;
            achOrderToCreate.SM_Payment_Status__c = chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.RECURRING ? SM_ACHOrderHelper.paymentStatus.PENDING : chargentOrder.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.STOPPED ? SM_ACHOrderHelper.paymentStatus.STOPPED : SM_ACHOrderHelper.paymentStatus.PENDING;
            achOrderToCreate.SM_User_who_applies_the_penalty__c = chargentOrder.SM_User_Who_Applies_Penalty__c;
            //SMPII-7 CJ 25-10-2021
            achOrderToCreate.SM_Payment_Condition__c ='Fixed value';
            // achOrderToCreate.SM_Total__c = chargentOrder.ChargentOrders__Subtotal__c; - Duplicated
        } else {
            achOrderToCreate.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.PENDING;
        }
        return achOrderToCreate;
    }

    // --------------------------------------------------------------- ACH -> Chargent Order ----------------------------------------------

    private void processContractWithNewChargentFromOldACHPaymentMethod(Set<String> recordIdsToProcess) {
        // ACH -> Chargent
        System.debug('Executing processContractWithNewChargentFromOldACHPaymentMethod: - recordToProcess:' + JSON.serialize(recordIdsToProcess));
        Map<String,SM_ACH_Order__c> achOrdersToProcess = new Map<String,SM_ACH_Order__c>();
        for (String contractId : contractInfoWithRelatedData.keySet()) {
            Contract newContract = newContractsMap.get(contractId);
            Contract oldContract = oldContractsMap.get(contractId);
            List<SM_ACH_Order__c> achOrders = contractInfoWithRelatedData.get(contractId).ACH_Orders__r;
            for (SM_ACH_Order__c achOrder : achOrders) {
                if (achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.PENDING || achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.INITIATED
                    || achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.STOPPED || achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.CREATED) {
                    achOrdersToProcess.put(achOrder.Id, achOrder);
                }
            }
        }
        if (!achOrdersToProcess.isEmpty()) {
            processACHOrdersWithACHPaymentType(achOrdersToProcess);
        }
    }

    private void processACHOrdersWithACHPaymentType(Map<String,SM_ACH_Order__c> achOrdersToProcess) {
        if (!achOrdersToProcess.isEmpty()) {
            createChargentOrdersAndUpdateAssetFees(achOrdersToProcess);
            cancelACHOrders(achOrdersToProcess);
        }
    }

    private void createChargentOrdersAndUpdateAssetFees(Map<String,SM_ACH_Order__c> achOrdersToProcess) {
        Map<String, ChargentOrders__ChargentOrder__c> chargentOrdersToCreateByACHOrderId = new Map<String, ChargentOrders__ChargentOrder__c>();
        Map<String,List<SM_Asset_Fee__c>> assetFeesByACHOrderIds = getAssetFeesByACHIds(achOrdersToProcess.keySet());
        List<ChargentOrders__ChargentOrder__c> additionalChargentOrdersToInsert = new List<ChargentOrders__ChargentOrder__c>();
        for (String achOrderId : achOrdersToProcess.keySet()) {
            ChargentOrders__ChargentOrder__c chargentOrderToCreate;
            ChargentOrders__ChargentOrder__c penaltyChargentOrder;
            SM_ACH_Order__c achOrder = achOrdersToProcess.get(achOrderId);
            if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE) {
                chargentOrderToCreate = createChargentOrder(achOrder, true);
                //if(achOrder.SM_Apply_penalty__c) penaltyChargentOrder = createChargentOrder(achOrder, true);
            } else {
                chargentOrderToCreate = createChargentOrder(achOrder, false);
            }
            if (chargentOrderToCreate != null) chargentOrdersToCreateByACHOrderId.put(achOrder.Id, chargentOrderToCreate);
            if (penaltyChargentOrder != null) additionalChargentOrdersToInsert.add(penaltyChargentOrder);
        }
        if (!chargentOrdersToCreateByACHOrderId.isEmpty()) {
            List<ChargentOrders__ChargentOrder__c> chargentOrdersToInsert = new List<ChargentOrders__ChargentOrder__c>();
            chargentOrdersToInsert.addAll(chargentOrdersToCreateByACHOrderId.values());
            if (!additionalChargentOrdersToInsert.isEmpty()) chargentOrdersToInsert.addAll(additionalChargentOrdersToInsert);
            List<Database.SaveResult> results = Database.insert(chargentOrdersToInsert);
            System.debug('chargentOrdersToCreateByACHOrderId: ' + chargentOrdersToCreateByACHOrderId);
            // It's not possible set next transaction date in a single transaction, is required update the chargent order records after insert
            List<ChargentOrders__ChargentOrder__c> chargentOrdersToUpdateNextTransactionDate = new List<ChargentOrders__ChargentOrder__c>();
            for (ChargentOrders__ChargentOrder__c chargentOrderToUpdate : chargentOrdersToInsert) {
                if (chargentOrderToUpdate.Id != null) {
                    chargentOrdersToUpdateNextTransactionDate.add(new ChargentOrders__ChargentOrder__c(
                        Id = chargentOrderToUpdate.Id,
                        ChargentOrders__Next_Transaction_Date__c = chargentOrderToUpdate.ChargentOrders__Next_Transaction_Date__c
                    ));
                }
            }
            if (!chargentOrdersToUpdateNextTransactionDate.isEmpty()) Database.update(chargentOrdersToUpdateNextTransactionDate);
            List<SM_Asset_Fee__c> assetFeesToUpdate = new List<SM_Asset_Fee__c>();
            for (String achOrderId : chargentOrdersToCreateByACHOrderId.keySet()) {
                ChargentOrders__ChargentOrder__c chargentOrderCreated = chargentOrdersToCreateByACHOrderId.get(achOrderId);
                SM_ACH_Order__c currentACHOrder = achOrdersToProcess.get(achOrderId);
                List<SM_Asset_Fee__c> assetFees = assetFeesByACHOrderIds.containsKey(achOrderId) ? assetFeesByACHOrderIds.get(achOrderId) : new List<SM_Asset_Fee__c>();
                for (SM_Asset_Fee__c assetFee : assetFees) {
                    if ((currentACHOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE && assetFee.SM_Position__c >= currentACHOrder.SM_Fee_to_collect__c)
                            || currentACHOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION) {
                        assetFeesToUpdate.add(new SM_Asset_Fee__c(Id = assetFee.Id, SM_Chargent_Order__c = chargentOrderCreated.Id, SM_ACH_Order__c = null));
                    }
                }
            }
            if (!assetFeesToUpdate.isEmpty()) {
                results = Database.update(assetFeesToUpdate);
                System.debug('results: ' + results);
            }
        }
    }

    private Map<String,List<SM_Asset_Fee__c>> getAssetFeesByACHIds(Set<String> achOrderIds) {
        Map<String,List<SM_Asset_Fee__c>> assetFeesByACHOrderIds = new Map<String,List<SM_Asset_Fee__c>>();
        for (SM_Asset_Fee__c assetFee : [SELECT Id, SM_ACH_Order__c, SM_Chargent_Order__c, SM_Position__c FROM SM_Asset_Fee__c WHERE SM_ACH_Order__c IN :achOrderIds]) {
            if (!assetFeesByACHOrderIds.containsKey(assetFee.SM_ACH_Order__c)) assetFeesByACHOrderIds.put(assetFee.SM_ACH_Order__c, new List<SM_Asset_Fee__c>()) ;
            assetFeesByACHOrderIds.get(assetFee.SM_ACH_Order__c).add(assetFee);
        }
        return assetFeesByACHOrderIds;
    }

    private void cancelACHOrders(Map<String,SM_ACH_Order__c> achOrdersToProcess) {
        List<SM_ACH_Order__c> achOrdersToCancel = new List<SM_ACH_Order__c>();
        for (String achOrderId : achOrdersToProcess.keySet()) {
            SM_ACH_Order__c achOrder = achOrdersToProcess.get(achOrderId);
            achOrdersToCancel.add(new SM_ACH_Order__c(Id = achOrder.Id, SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.CANCELED));
        }
        if (!achOrdersToCancel.isEmpty()) {
            List<Database.SaveResult> results = Database.update(achOrdersToCancel);
            for (Database.SaveResult result  : results) {
                if (result.isSuccess()) {
                    result.getId();
                } else {
                    for (Database.Error error : result.getErrors()) {
                        System.debug('error: statusCode ' + error.getStatusCode() + ' - message ' + error.getMessage());
                    }
                }
            }
        }
    }

    private ChargentOrders__ChargentOrder__c createChargentOrder(SM_ACH_Order__c achOrder, Boolean isPenaltyOrder) {
        Contract newContract = newContractsMap.get(achOrder.SM_Contract__c);
        SM_Payment_Method__c newPaymentMethod = paymentMethodsById.get(newContract.SM_Payment_Method__c);
        ChargentOrders__ChargentOrder__c chargentBaseRecord = chargentBaseRecordsById.get(newPaymentMethod.SM_Chargent_Order__c);
        if (chargentBaseRecord == null) return null;
        Decimal paymentCount = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.AC || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE ? 1 : achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? null : achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? (achOrder.SM_Quantity_of_scheduled_fees__c - (achOrder.SM_Fee_to_collect__c - 1)) : null ;
        String paymentStop = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.AC || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE ? 'Count' : achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? 'Unending' : achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? 'Count' : null ;
        Decimal feeToCollect = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? achOrder.SM_Fee_to_collect__c : null ;
        Decimal ivuMunicipalPercentage = contractInfoWithRelatedData.get(newContract.Id).SM_Opportunity__r?.SM_Company_Setting__r?.SM_IVU_Municipal_Amount__c;
        Decimal ivuStatePercentage = contractInfoWithRelatedData.get(newContract.Id).SM_Opportunity__r?.SM_Company_Setting__r?.SM_IVU_State_Amount__c;
        ChargentOrders__ChargentOrder__c chargentToCreate = chargentBaseRecord.clone(false);
        chargentToCreate.SM_IsRegisterToken__c = false; // JSPA - 08/27/2021
        chargentToCreate.SM_Migrated__c = false; // JSPA - 08/26/2021 - Case 00001012
        chargentToCreate.SM_Migration_Date__c = null; // JSPA - 08/26/2021 - Case 00001012
        chargentToCreate.ChargentOrders__Payment_Frequency__c = achOrder.SM_Payment_Frequency__c;
        chargentToCreate.ChargentOrders__Account__c = newContract.AccountId;
        chargentToCreate.ChargentOrders__Payment_Count__c = paymentCount;
        chargentToCreate.ChargentOrders__Payment_Stop__c = paymentStop;
        chargentToCreate.ChargentOrders__Gateway__c = contractInfoWithRelatedData.get(newContract.Id).SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c;
        chargentToCreate.ChargentOrders__Payment_Method__c = 'Credit Card';
        chargentToCreate.Contract__c = newContract.Id;
        chargentToCreate.SM_Payment_Type__c = achOrder.SM_Payment_Type__c;
        chargentToCreate.SM_Fee_to_collect__c = feeToCollect;
        chargentToCreate.SM_ACH_Order_source__c = achOrder.Id;
        // Late payment feee
        // SFDCMP-393 CJ 05-10-2021
        if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE) {
            // chargentToCreate.ChargentOrders__Payment_Status__c = achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.PENDING ? SM_ChargentOrderHelper.paymentStatus.RECURRING : achOrder.SM_Payment_Status__c == SM_ACHOrderHelper.paymentStatus.STOPPED ? SM_ChargentOrderHelper.paymentStatus.STOPPED : SM_ChargentOrderHelper.paymentStatus.RECURRING;
            // Apply penalty
            // if (achOrder.SM_Apply_penalty__c == true) {
                if (isPenaltyOrder) {
                    chargentToCreate.ChargentOrders__Payment_Status__c = SM_ChargentOrderHelper.paymentStatus.STOPPED;
                    chargentToCreate.SM_Failed_Payment__c = achOrder.SM_Failed_payment__c;
                    chargentToCreate.SM_Apply_Penalty__c = achOrder.SM_Apply_penalty__c;
                    chargentToCreate.SM_Penalty_Date__c = achOrder.SM_Penalty_date__c;
                    chargentToCreate.SM_Penalty_Value__c = achOrder.SM_Penalty_value__c;
                    chargentToCreate.SM_Approval_status__c = achOrder.SM_Approval_status__c;
                    chargentToCreate.SM_Reason_to_approve_exoneration__c = achOrder.SM_Reason_to_approve_exoneration__c;
                    chargentToCreate.ChargentOrders__Subtotal__c = achOrder.SM_Total__c;
                    // chargentToCreate.ChargentOrders__Tax__c = achOrder.;
                    chargentToCreate.SM_Purpose_of_Payment__c = SM_ChargentOrderHelper.purposeOfPayment.COLLECT_STR;
                    chargentToCreate.SM_Payment_Type__c = achOrder.SM_Payment_Type__c;
                    // chargentToCreate.ChargentOrders__Charge_Amount__c = achOrder.;
                    // chargentToCreate.ChargentOrders__Payment_Start_Date__c = achOrder.SM_Payment_Start_Date__c; - Duplicate
                    // chargentToCreate.ChargentOrders__Payment_End_Date__c = achOrder.SM_Payment_End_Date__c; - Duplicate
                    // chargentToCreate.ChargentOrders__Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c; - Duplicate
                } else {
                    chargentToCreate.SM_Payment_Type__c = achOrder.SM_Failed_payment__r.SM_ACH_Order__r.SM_Payment_Type__c;
                    chargentToCreate.ChargentOrders__Payment_Status__c = SM_ChargentOrderHelper.paymentStatus.RECURRING;
                    chargentToCreate.ChargentOrders__Subtotal__c = achOrder.SM_Total__c;
                    // chargentToCreate.ChargentOrders__Tax__c = achOrder.;
                    chargentToCreate.SM_Purpose_of_Payment__c = SM_ChargentOrderHelper.purposeOfPayment.CONTRACT_FEE;
                    // chargentToCreate.ChargentOrders__Payment_Start_Date__c = achOrder.SM_Payment_Start_Date__c; - Duplicate
                    // chargentToCreate.ChargentOrders__Payment_End_Date__c = achOrder.SM_Payment_End_Date__c; - Duplicate
                    // chargentToCreate.ChargentOrders__Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c; - Duplicate
                }
            // } else {
            //     chargentToCreate.ChargentOrders__Subtotal__c = achOrder.SM_Total__c - achOrder.SM_Penalty_value__c;
            //     // chargentToCreate.ChargentOrders__Tax__c = achOrder.;
            //     chargentToCreate.SM_Purpose_of_Payment__c = SM_ChargentOrderHelper.purposeOfPayment.CONTRACT_FEE;
            // }
        } else {
            // Not apply penalty
            chargentToCreate.ChargentOrders__Subtotal__c = achOrder.SM_Total__c;
            chargentToCreate.SM_Payment_Type__c = achOrder.SM_Payment_Type__c;
            chargentToCreate.ChargentOrders__Payment_Status__c = 'Recurring';
        }
        chargentToCreate.ChargentOrders__Payment_Start_Date__c = chargentToCreate.ChargentOrders__Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.ONCE ? achOrder.SM_Payment_Start_Date__c : achOrder.SM_Next_Transaction_Date__c ;
        chargentToCreate.ChargentOrders__Payment_End_Date__c = achOrder.SM_Payment_End_Date__c;
        chargentToCreate.ChargentOrders__Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c;
          // SMPII-8  CJ 25-10-2021
        chargentToCreate.ChargentOrders__Charge_Date__c= chargentToCreate.ChargentOrders__Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.ONCE ? null : String.valueOf(newContract.SM_Payment_day__c);
        chargentToCreate.SM_P_IVU_Municipal_Amount__c = ivuMunicipalPercentage != null ? ivuMunicipalPercentage : 0;
        chargentToCreate.SM_P_IVU_State_Amount__c = ivuStatePercentage != null ? ivuStatePercentage : 0;
        Decimal tax = (chargentToCreate.ChargentOrders__Subtotal__c * (chargentToCreate.SM_P_IVU_Municipal_Amount__c / 100)) + (chargentToCreate.ChargentOrders__Subtotal__c * (chargentToCreate.SM_P_IVU_State_Amount__c / 100));
        chargentToCreate.ChargentOrders__Tax__c = tax.setScale(3);
        chargentToCreate.ChargentOrders__Charge_Amount__c = chargentToCreate.ChargentOrders__Subtotal__c + chargentToCreate.ChargentOrders__Tax__c;
        return chargentToCreate;
    }
}