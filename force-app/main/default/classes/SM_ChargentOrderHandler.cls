/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   05-15-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
 * 1.1   09-30-2021   Camilo A. Jimenez B -> cjiemenez@legal-credit.com      Initial Version
**/
public without sharing class SM_ChargentOrderHandler extends SM_TriggerHandler{

    /************* Static Variables *************/
    // Available payment types to create asset fees
    private static List<String> paymentTypes = new List<String>{
        SM_ChargentOrderHelper.paymentType.SUBSCRIPTION,
        SM_ChargentOrderHelper.paymentType.FEE
    };

    public SM_ChargentOrderHandler(String triggerName) {
        super(triggerName);
    }

    /************* Overwrite DML methods *************/
    override public void beforeInsert() {
        // SFDCM-366 Update contract to Payment process when it doesn't have any ACH Orders
        updateContractStatus(Trigger.new);
        //CJ 08-11-2021 SMPII-18
        insertNextScheduledPaymentDate(Trigger.new);
    }

    override public void afterInsert() {
        // SFDCMP-317 - JSPA
        //processRecords(Trigger.new);
        //SMMCI-38
        SM_PaymentHelper.setFeeToCollectFromFailetPayment(Trigger.new);
    }

    override public void beforeUpdate() {
         //SMPII-46 CJ 17-11-2021
         updatePaymentStartDateChargentOrder(Trigger.new, Trigger.oldMap);
        // JSPA - SFDCMP-369
         getPaymentDayFromCtAndSetInChargentOrder(Trigger.new, Trigger.oldMap);
         //CJ 17-11-2021 SMPII-76
         updateNextScheduledPaymentDate(Trigger.new, Trigger.oldMap);
         // SRQ
         updateTotals(Trigger.new, Trigger.oldMap);

    }

    override public void afterUpdate(){
        // SFDCMP-352
        processErrorChargentOrders(Trigger.newMap, Trigger.oldMap);
        //SFDCMP-389
        updatePenaltyDate(Trigger.newMap, Trigger.oldMap);
    }



    /************* Auxiliar methods *************/
    /**
    * @description This method process new records to validate what chargent orders are available to create asset fees
    * @author jpachon@legal-credit.com | 05-15-2021
    * @param newRecords
    **/
    private void processRecords(List<ChargentOrders__ChargentOrder__c> newRecords){
        Map<String, String> chargentOrderByContractId = new Map<String, String>();
        for (ChargentOrders__ChargentOrder__c chargentOrder : newRecords) {
            if (paymentTypes.contains(chargentOrder.SM_Payment_Type__c) && chargentOrder.SM_Purpose_of_Payment__c == 'Contract fee') chargentOrderByContractId.put(chargentOrder.Contract__c, chargentOrder.Id);
        }
        //if (!chargentOrderByContractId.isEmpty()) createAssetFeesProcess(chargentOrderByContractId);
    }

    /**
    * @description This method create asset fees and update the asset with chargent order record
    * @author jpachon@legal-credit.com | 05-15-2021
    * @param newRecords
    **/
    public static Map<Id,List<SM_Asset_Fee__c>> createAssetFeesProcess(List<String> contractIds){
        // Get assets by contract ids
        // CJ 06/08/2022 SMMCI-27
        Set<String> idsContract = new Set<String>();
        idsContract.addAll(contractIds);
        for(Contract ctr : [SELECT id, (SELECT  id, Principal_Contract__c, SM_Contract__r.Contract_activation_form__c,SM_Contract__c,SM_Contract__r.Collection_Main_Contract__c FROM Assets1__r ) FROM Contract WHERE ID IN: contractIds ]){
            if(!ctr.Assets1__r.isEmpty()){
                for(Asset asset: ctr.Assets1__r)
                    if(asset.SM_Contract__r.Contract_activation_form__c == SM_ContractHelper.collectionActivationForm.INMEDIATE_ACTIVATION
                      && asset.SM_Contract__r.Collection_Main_Contract__c == SM_ContractHelper.collectionMain.READY_FOR_COLLECTION){
                        idsContract.add(asset.SM_Contract__c);
                    }
            }
        }
        List<Asset> assetsToProcess = [SELECT Id, Price, SM_Contract__c,Principal_Contract__c, Product2.SM_Plan_Months__c, Product2.SM_Way_to_pay__c, Product2.SM_Monthly_Offer__c FROM Asset WHERE SM_Contract__c IN :idsContract AND Price > 0 AND SM_Chargent_Order__c = null];
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
            if (asset.Product2.SM_Way_to_pay__c == 'Fix Term') {
                qtyOfAssetsFeeToCreate = asset.Product2.SM_Plan_Months__c;
                assetFeeType = 'Fee';
            }
            for (Decimal i = 0; i < qtyOfAssetsFeeToCreate; i++) {
                if ((assetFeeType == 'Subscription') || (assetFeeType == 'Fee' && i == 0)) {
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
                                SM_Asset__c = asset.Id,
                                SM_Position__c = i + 1,
                                SM_Type__c = assetFeeType,
                                SM_Amount__c = asset.Principal_Contract__c != null ? asset.Price :  asset.Product2.SM_Monthly_Offer__c,
                                SM_Contract__c = asset.SM_Contract__c,
                                SM_Status__c = 'Scheduled',
                                //SM_Chargent_Order__c = chargentOrderId,
                                SM_Fee_to_collect__c = feeToCollect,
                                SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                                Name = assetFeeType + '-' + (i + 1)
                        	)
                        }
                	);
                }
                else{
                    assetsFeeToInsert.get(asset.SM_Contract__c).add(
                        new SM_Asset_Fee__c(
                            SM_Asset__c = asset.Id,
                            SM_Position__c = i + 1,
                            SM_Type__c = assetFeeType,
                            SM_Amount__c = asset.Principal_Contract__c != null ? asset.Price :  asset.Product2.SM_Monthly_Offer__c,
                            SM_Contract__c = asset.SM_Contract__c,
                            SM_Status__c = 'Scheduled',
                            //SM_Chargent_Order__c = chargentOrderId,
                            SM_Fee_to_collect__c = feeToCollect,
                            SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                            Name = assetFeeType + '-' + (i + 1)
                        )
                    );
                }
            }
            //assetToUpdate.add(new Asset(Id = asset.Id, SM_Chargent_Order__c = chargentOrderId));
        }

        /*List<Database.SaveResult> sr;
        if (!assetsFeeToInsert.isEmpty()) {
            sr = Database.insert(assetsFeeToInsert);
            System.debug('sr: ' + JSON.serialize(sr));
        }
        if (!assetToUpdate.isEmpty()) {
            sr = Database.update(assetToUpdate);
            System.debug('sr: ' + JSON.serialize(sr));
        }*/
        return assetsFeeToInsert;
    }
    /**
    * @description This method create asset fees and update the asset with chargent order record
    * @author Cjimenez | 02/08/2022
    * @param contractIds,achOrderIdByContractId
    **/
    public static Map<Id,List<SM_Asset_Fee__c>> createAssetFeesProcess(List<String> contractIds,Map<String,ChargentOrders__ChargentOrder__c> achOrderIdByContractId){
        // Get assets by contract ids
        Map<String,Asset> ctrIdsByAsset = new Map<String,Asset>();
        List<Asset> assetsToProcess = [SELECT Id,AC_Price__c,Price,Product2.SM_Requires_AC__c,SM_Contract__c,Principal_Contract__c, Product2.SM_Plan_Months__c, Product2.SM_Way_to_pay__c, Product2.SM_Monthly_Offer__c FROM Asset WHERE SM_Contract__c IN :contractIds AND Price > 0 AND SM_Chargent_Order__c = null];
        
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
            ChargentOrders__ChargentOrder__c chargentOrd = achOrderIdByContractId.containsKey(asset.Principal_Contract__c) ? achOrderIdByContractId.get(asset.Principal_Contract__c) : null;
            Decimal position = 0; 
            Decimal acFee = 0;
            if(chargentOrd != null)
               acFee = asset.Product2.SM_Requires_AC__c == true ? 1 : 0;
               position = asset.Product2.SM_Requires_AC__c == true ? chargentOrd.SM_Fee_to_collect__c : chargentOrd.SM_Fee_to_collect__c + 1; 
               qtyOfAssetsFeeToCreate = qtyOfAssetsFeeToCreate + acFee + position ;
            for (Decimal i = position; i < qtyOfAssetsFeeToCreate; i++) {
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
                                SM_Chargent_Order__c = chargentOrd != null ? chargentOrd.id : null,
                                SM_Fee_to_collect__c = true,
                                SM_Date__c = chargentOrd.ChargentOrders__Payment_Start_Date__c,
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
                            SM_Position__c = i ,
                            SM_Type__c = assetFeeType,
                            SM_Amount__c = asset.Principal_Contract__c != null ? asset.Price :  asset.Product2.SM_Monthly_Offer__c,
                            SM_Contract__c = asset.SM_Contract__c,
                            SM_Status__c = 'Scheduled',
                            SM_Chargent_Order__c = chargentOrd != null ? chargentOrd.id : null,
                            SM_Fee_to_collect__c = false,
                            SM_Date__c = chargentOrd.ChargentOrders__Payment_Start_Date__c,
                            SM_PrincipalContract__c = asset.Principal_Contract__c != null ? asset.Principal_Contract__c : null,
                            Name = assetFeeType + '-' + i
                        )
                    );
                }
            }
        }

        return assetsFeeToInsert;
    }


    /**
    * @description This method update the payment day from Contract
    * @author jpachon@legal-credit.com | 07-09-2021
    * @param newRecords | List<ChargentOrders__ChargentOrder__c>
    * @param oldRecordsMap | Map<Id, SObject>
    **/
    private void getPaymentDayFromCtAndSetInChargentOrder(List<ChargentOrders__ChargentOrder__c> newRecords, Map<Id, SObject> oldRecordsMap) {
        Map<String, ChargentOrders__ChargentOrder__c> chargentOrderByContractId = new Map<String, ChargentOrders__ChargentOrder__c>();
        for (ChargentOrders__ChargentOrder__c newRecord : newRecords) {
            ChargentOrders__ChargentOrder__c oldRecord = (ChargentOrders__ChargentOrder__c)oldRecordsMap.get(newRecord.Id);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'ChargentOrders__Next_Transaction_Date__c') && paymentTypes.contains(newRecord.SM_Payment_Type__c)
                && newRecord.ChargentOrders__Next_Transaction_Date__c != null && newRecord.SM_Purpose_of_Payment__c == SM_ChargentOrderHelper.purposeOfPayment.CONTRACT_FEE
                && !newRecord.SM_IsApplyingDaysCollectedPenalty__c) {
                chargentOrderByContractId.put(newRecord.Contract__c, newRecord);
            }
        }
        if(!chargentOrderByContractId.isEmpty()){
            Map<String, Integer> paymentDayByContractId = new Map<String, Integer>();
            Map<String, Contract> contractById = new Map<String, Contract>([SELECT Id, SM_Payment_day__c FROM Contract WHERE Id IN :chargentOrderByContractId.keySet()]);
            for (Contract ct : contractById.values()) {
                paymentDayByContractId.put(ct.Id, Integer.valueOf(ct.SM_Payment_day__c));
            }
            for (ChargentOrders__ChargentOrder__c newRecord : newRecords) {
                Integer newPaymentDay = paymentDayByContractId.get(newRecord.Contract__c);
                if (newPaymentDay != null && newRecord.ChargentOrders__Payment_Start_Date__c != null && newRecord.ChargentOrders__Next_Transaction_Date__c != null) {
                    if (newPaymentDay >= 29) {
                        Integer lastDayOfMonth = Date.daysInMonth(newRecord.ChargentOrders__Next_Transaction_Date__c.year(), newRecord.ChargentOrders__Next_Transaction_Date__c.month());
                        if(newPaymentDay > lastDayOfMonth) {
                            newPaymentDay = lastDayOfMonth;
                        }
                    }
                    newRecord.ChargentOrders__Next_Transaction_Date__c = Date.newInstance(newRecord.ChargentOrders__Next_Transaction_Date__c.year(), newRecord.ChargentOrders__Next_Transaction_Date__c.month(), newPaymentDay);
                    newRecord.ChargentOrders__Charge_Date__c = String.valueOf(newPaymentDay);
                    newRecord.ChargentOrders__Payment_Start_Date__c = newRecord.ChargentOrders__Next_Transaction_Date__c;
                }
            }
        }
        // This flag is required to avoid that when a record comes from processErrorChargentOrders method execute this method
        for (ChargentOrders__ChargentOrder__c newRecord : newRecords) {
            newRecord.SM_IsApplyingDaysCollectedPenalty__c = false;
        }
    }


    private void updateTotals(List<ChargentOrders__ChargentOrder__c> newRecords, Map<Id, SObject> oldRecordsMap){
        // JSPA - It's not require to make an update when this method is been called from a before
        // List<ChargentOrders__ChargentOrder__c> newValues = new List<ChargentOrders__ChargentOrder__c>();
        for(ChargentOrders__ChargentOrder__c order: newRecords){
            if(SM_Utils.isChangedField(order, oldRecordsMap.get(order.Id), 'ChargentOrders__Subtotal__c')){
                double subtotal = (order.ChargentOrders__Subtotal__c*order.SM_P_IVU_Municipal_Amount__c)/100;
                subtotal += (order.ChargentOrders__Subtotal__c*order.SM_P_IVU_State_Amount__c)/100;
                System.debug(subtotal);
                order.ChargentOrders__Tax__c = subtotal;
                order.ChargentOrders__Charge_Amount__c = order.ChargentOrders__Subtotal__c+subtotal;
                // newValues.add(order);
            }
        }
        // update newValues;
    }
    /**
    * @description This method update Contract Info
    * @author jpachon@legal-credit.com | 07-07-2021
    * @param newRecords
    **/
    private void updateContractStatus(List<ChargentOrders__ChargentOrder__c> newRecords) {
        Set<String> contractIds = new Set<String>();
        for (ChargentOrders__ChargentOrder__c chargentOrder : newRecords) {
            contractIds.add(chargentOrder.Contract__c);
        }
        Map<String, Contract> contracts = new Map<String, Contract>([
            SELECT Id, Status,
            (SELECT Id FROM Chargent_Orders__r)
            FROM Contract
            WHERE Id IN :contractIds
        ]);
        for (ChargentOrders__ChargentOrder__c chargentOrder : newRecords) {
            Contract contract = contracts.get(chargentOrder.Contract__c);
            if(contract.Status == SM_ContractHelper.status.COMPLETE_INFORMATION && contract.Chargent_Orders__r.size() == 0) contract.Status = SM_ContractHelper.status.PAYMENT_PROCESS;
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
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 15-07-2021 
    * @param newRecords
    **/
     private void processErrorChargentOrders(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
       // SFDCMP-389 CJ 30-09-2021
        Set<String> paymentsToProcess = new Set<String>();
        Set<String> chargenOrderIds = new Set<String>();
    
        for (Id newRecordId : newRecordsMap.keySet()) {

            ChargentOrders__ChargentOrder__c oldRecord = (ChargentOrders__ChargentOrder__c)oldRecordsMap.get(newRecordId);
            ChargentOrders__ChargentOrder__c newRecord = (ChargentOrders__ChargentOrder__c)newRecordsMap.get(newRecordId);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'ChargentOrders__Payment_Status__c') && newRecord.ChargentOrders__Payment_Status__c == SM_ChargentOrderHelper.paymentStatus.ERROR) {
                chargenOrderIds.add(newRecord.id);
            }
        }
        List<ChargentOrders__ChargentOrder__c> lstChargenOrderUpdate = new List<ChargentOrders__ChargentOrder__c>();
        List<ChargentOrders__ChargentOrder__c> lstChargenOrderUpdateDate = new List<ChargentOrders__ChargentOrder__c>();
        for(ChargentOrders__ChargentOrder__c chargentOrder:[SELECT id
                                                            ,Contract__r.Status
                                                            ,Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c
                                                            ,ChargentOrders__Payment_Status__c
                                                            ,ChargentOrders__Payment_Frequency__c
                                                            ,SM_Payment_Type__c
                                                            ,ChargentOrders__Payment_Count__c
                                                            ,ChargentOrders__Transaction_Count_Recurring__c
                                                            ,ChargentOrders__Next_Transaction_Date__c
                                                            FROM ChargentOrders__ChargentOrder__c
                                                            WHERE id =: chargenOrderIds ]){

            if(chargentOrder.Contract__r.Status == SM_ContractHelper.status.ACTIVATED || chargentOrder.Contract__r.Status == SM_ContractHelper.status.PAYMENT_PROCESS 
                || chargentOrder.Contract__r.Status == SM_ContractHelper.status.COMPLETE_INFORMATION){  
                    ChargentOrders__ChargentOrder__c oldRecord=(ChargentOrders__ChargentOrder__c)oldRecordsMap.get(chargentOrder.id);
                    chargentOrder.ChargentOrders__Next_Transaction_Date__c=oldRecord.ChargentOrders__Next_Transaction_Date__c;       
                    chargentOrder.ChargentOrders__Payment_Count__c=oldRecord.ChargentOrders__Payment_Count__c;                       
                if(chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE){
                    lstChargenOrderUpdate.add(processErrorChargentOrdersLatePaymentFee(chargentOrder));
                }else if(chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.FEE){
                    ChargentOrders__ChargentOrder__c chargentOrderUpdate=processErrorChargentOrdersFee(chargentOrder);
                    lstChargenOrderUpdate.add(chargentOrderUpdate);
                    lstChargenOrderUpdateDate.add(chargentOrderUpdate);
                }else if(chargentOrder.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE){
                    lstChargenOrderUpdate.add(processErrorChargentOrdersOnce(chargentOrder));
                }else if(chargentOrder.SM_Payment_Type__c ==  SM_ChargentOrderHelper.paymentType.SUBSCRIPTION){
                    ChargentOrders__ChargentOrder__c chargentOrderUpdate=processErroprocessErrorChargentOrderSuscription(chargentOrder);
                    lstChargenOrderUpdate.add(chargentOrderUpdate);
                    lstChargenOrderUpdateDate.add(chargentOrderUpdate);
                }
            }
        }
        // CJ update status and additional fields
        if (lstChargenOrderUpdate != null && !lstChargenOrderUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(lstChargenOrderUpdate);
        }
         // CJ update ChargentOrders__Next_Transaction_Date__c
        if (lstChargenOrderUpdateDate != null && !lstChargenOrderUpdateDate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(lstChargenOrderUpdateDate);
        }
    }


    /**
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 30-09-2021 
    * @param cargentOrder
    * SFDCMP-389
    **/
    private ChargentOrders__ChargentOrder__c processErrorChargentOrdersLatePaymentFee(ChargentOrders__ChargentOrder__c chargentOrder) {
        Date newNextTransactionDate = chargentOrder.Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c != null ? System.today().addDays(Integer.valueOf(chargentOrder.Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Days_Collect_Penalty__c)) : System.today();
        Integer newChargeDate = newNextTransactionDate.day();
        ChargentOrders__ChargentOrder__c chargenOrder= SM_ChargentOrderHelper.updateChargentOrderError(chargentOrder.id,true,newNextTransactionDate,null,SM_ChargentOrderHelper.paymentStatus.RECURRING); 
        chargenOrder.ChargentOrders__Payment_Start_Date__c=newNextTransactionDate;
        chargenOrder.ChargentOrders__Payment_End_Date__c=newNextTransactionDate;
        return chargenOrder;
    }

    /**
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 30-09-20211
    * @param chargentOrder
    * SFDCMP-389
    **/
    private ChargentOrders__ChargentOrder__c processErrorChargentOrdersFee(ChargentOrders__ChargentOrder__c chargentOrder) {
        Date newNextTransactionDate = chargentOrder.ChargentOrders__Payment_Count__c-1 > chargentOrder.ChargentOrders__Transaction_Count_Recurring__c ? Date.newInstance(chargentOrder.ChargentOrders__Next_Transaction_Date__c.year(), chargentOrder.ChargentOrders__Next_Transaction_Date__c.month()+1, chargentOrder.ChargentOrders__Next_Transaction_Date__c.day()) : null;
        Integer newChargeDate = newNextTransactionDate != null ? newNextTransactionDate.day() : null;
        Decimal paymentCount = chargentOrder.ChargentOrders__Payment_Count__c == 1 ? 1 : chargentOrder.ChargentOrders__Payment_Count__c-1;
        String paymentStatus = chargentOrder.ChargentOrders__Payment_Status__c = chargentOrder.ChargentOrders__Payment_Count__c-1 > chargentOrder.ChargentOrders__Transaction_Count_Recurring__c ? SM_ChargentOrderHelper.paymentStatus.RECURRING : SM_ChargentOrderHelper.paymentStatus.CANCELED;
        ChargentOrders__ChargentOrder__c chargenOrder =  SM_ChargentOrderHelper.updateChargentOrderError(chargentOrder.id,true,newNextTransactionDate,String.valueOf(newChargeDate),paymentStatus); 
        chargenOrder.ChargentOrders__Payment_Count__c=paymentCount;
        chargenOrder.ChargentOrders__Payment_Start_Date__c=newNextTransactionDate;
        return chargenOrder;
    }

     /**    
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 30-09-2021
    * @param chargentOrder
    * SFDCMP-389
    **/
    private ChargentOrders__ChargentOrder__c processErrorChargentOrdersOnce(ChargentOrders__ChargentOrder__c chargentOrder) {
        Date newDateToCharge = System.today();
        ChargentOrders__ChargentOrder__c chargenOrder =  SM_ChargentOrderHelper.updateChargentOrderError(chargentOrder.id,true,null,null,SM_ChargentOrderHelper.paymentStatus.COMPLETE); 
        chargenOrder.ChargentOrders__Payment_Start_Date__c=newDateToCharge;
        chargenOrder.ChargentOrders__Payment_End_Date__c = newDateToCharge;
        return chargenOrder;
    }


      /**
    * @description This method update Charget Update
    * @author cjimenez@legal-credit.com | 30-09-2021
    * @param chargentOrder
    **/
    private ChargentOrders__ChargentOrder__c processErroprocessErrorChargentOrderSuscription(ChargentOrders__ChargentOrder__c chargentOrder) {
        Date newNextTransactionDate = Date.newInstance(chargentOrder.ChargentOrders__Next_Transaction_Date__c.year(), chargentOrder.ChargentOrders__Next_Transaction_Date__c.month()+1,chargentOrder.ChargentOrders__Next_Transaction_Date__c.day());
        Integer newChargeDate = newNextTransactionDate.day();
        ChargentOrders__ChargentOrder__c chargenOrder =  SM_ChargentOrderHelper.updateChargentOrderError(chargentOrder.id,true,newNextTransactionDate,String.valueOf(newChargeDate),SM_ChargentOrderHelper.paymentStatus.RECURRING); 
        chargenOrder.ChargentOrders__Payment_Start_Date__c=newNextTransactionDate;
        return chargenOrder;
    }



     /**
    * @description This method update Contract Info
    * @author cjimenez@legal-credit.com | 22-07-2021
    * @param newRecords
    * SFDCMP-389
    **/
    private void updatePenaltyDate(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap){
        Set<String> charOrderIdUpdate = new Set<String>();
        List<ChargentOrders__ChargentOrder__c> listCharOrderUpdate = new List<ChargentOrders__ChargentOrder__c>();
        for (Id newRecordId : newRecordsMap.keySet()) {
            ChargentOrders__ChargentOrder__c oldRecord = (ChargentOrders__ChargentOrder__c)oldRecordsMap.get(newRecordId);
            ChargentOrders__ChargentOrder__c newRecord = (ChargentOrders__ChargentOrder__c)newRecordsMap.get(newRecordId);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'SM_Apply_Penalty__c') && newRecord.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE ) {
                charOrderIdUpdate.add(newRecord.id);
            }
        }
        for(ChargentOrders__ChargentOrder__c chargentOrder:[SELECT id
                                                           ,Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c
                                                           ,ChargentOrders__Subtotal__c
                                                           ,SM_Penalty_Value__c
                                                           FROM ChargentOrders__ChargentOrder__c
                                                           WHERE id =: charOrderIdUpdate ]){
          Decimal latePaymentFee = chargentOrder?.Contract__r?.SM_Opportunity__r?.SM_Company_Setting__r?.SM_Late_payment_fee__c != null ? chargentOrder.Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Late_payment_fee__c : 0;
          ChargentOrders__ChargentOrder__c newChargentOrder=(ChargentOrders__ChargentOrder__c)newRecordsMap.get(chargentOrder.id);
          chargentOrder.ChargentOrders__Subtotal__c=newChargentOrder.SM_Apply_Penalty__c == true ? chargentOrder.ChargentOrders__Subtotal__c+latePaymentFee :  chargentOrder.ChargentOrders__Subtotal__c-latePaymentFee;
          chargentOrder.SM_Penalty_Date__c=System.Now();
          chargentOrder.SM_Penalty_Value__c=newChargentOrder.SM_Apply_Penalty__c == false ? 0 : latePaymentFee;
          listCharOrderUpdate.add(chargentOrder);
        }
        if (listCharOrderUpdate != null && !listCharOrderUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(listCharOrderUpdate);
            System.debug('sr: ' + sr);
        }
           listCharOrderUpdate = new List<ChargentOrders__ChargentOrder__c>();
        for(ChargentOrders__ChargentOrder__c chargentOrder:[SELECT id
                                                           ,SM_IVU_Municipal_Amount__c
                                                           ,SM_IVU_State_Amount__c
                                                           ,ChargentOrders__Subtotal__c
                                                           FROM ChargentOrders__ChargentOrder__c
                                                           WHERE id =: charOrderIdUpdate ]){
            chargentOrder.ChargentOrders__Tax__c=chargentOrder.SM_IVU_Municipal_Amount__c+chargentOrder.SM_IVU_State_Amount__c;
            chargentOrder.ChargentOrders__Charge_Amount__c=chargentOrder.ChargentOrders__Subtotal__c+chargentOrder.SM_IVU_Municipal_Amount__c+chargentOrder.SM_IVU_State_Amount__c;
            listCharOrderUpdate.add(chargentOrder);
        }
        if (listCharOrderUpdate != null && !listCharOrderUpdate.isEmpty()) {
            List<Database.SaveResult> sr = Database.update(listCharOrderUpdate);
            System.debug('sr: ' + sr);
        }
        
    }

    
      /**
    * @description This method update Payment Start Date
    * @author cjimenez@legal-credit.com | 02-11-2021
    * @param newRecords
    **/
    private void updatePaymentStartDateChargentOrder(List<ChargentOrders__ChargentOrder__c> newChargentOrders, Map<Id, SObject> oldChargentOrderMap) {
        List<ChargentOrders__ChargentOrder__c> lstChargentOrders=new  List<ChargentOrders__ChargentOrder__c>();
        Set<String> chargentOrdersByIds = new Set<String>();
        for (ChargentOrders__ChargentOrder__c newChargentOrder : newChargentOrders) {
             ChargentOrders__ChargentOrder__c oldChargentOrder = (ChargentOrders__ChargentOrder__c) oldChargentOrderMap.get(newChargentOrder.Id);
            if(SM_Utils.isChangedField(newChargentOrder, oldChargentOrder, 'ChargentOrders__Next_Transaction_Date__c')){
                newChargentOrder.ChargentOrders__Payment_Start_Date__c= newChargentOrder.ChargentOrders__Next_Transaction_Date__c != null ? newChargentOrder.ChargentOrders__Next_Transaction_Date__c : newChargentOrder.ChargentOrders__Payment_Start_Date__c;
            }
        }
    }

    /**
    * @description his method update Next Scheduled Payment Date
    * @author Camilo Jimenez -> cjimenez@legal-credit.com | 08/11/2021
    * @param newInvoice | List<ChargentOrders__ChargentOrder__c>
    * @param oldInvoice | Map<Id, SObject>
    **/
    private static void updateNextScheduledPaymentDate(List<ChargentOrders__ChargentOrder__c> newRecords, Map<Id, SObject> oldRecordsMap){
        BusinessHours bHour=SM_Utils.getBusinessHour('Monee Business Hour');
        for (ChargentOrders__ChargentOrder__c newCho : newRecords) {
              ChargentOrders__ChargentOrder__c oldCho= (ChargentOrders__ChargentOrder__c) oldRecordsMap.get(newCho.Id);
             if (SM_Utils.isChangedField(newCho, oldCho, 'ChargentOrders__Next_Transaction_Date__c') && newCho.ChargentOrders__Next_Transaction_Date__c != null ){
                  // Use Date (not DateTime) to avoid timezone shifts and preserve manual day/month
                  Date paymendDate = Date.newInstance(newCho.ChargentOrders__Next_Transaction_Date__c.year(), newCho.ChargentOrders__Next_Transaction_Date__c.month(), newCho.ChargentOrders__Next_Transaction_Date__c.day());
                  // Keep existing business-hour suggestion but ensure the resulting date preserves the intended day
                  DateTime paymendDT = DateTime.newInstance(paymendDate.year(), paymendDate.month(), paymendDate.day());
                  SM_Utils.CompanybusinessDay companybusinessDay = SM_Utils.getSuggestedBusinessHour(bHour, paymendDT);
                  if(companybusinessDay.businessDay){
                     // Preserve intended day explicitly to avoid end-of-month rollovers
                     Integer targetDay = paymendDate.day();
                     Date suggested = Date.newInstance(companybusinessDay.newDate.year(), companybusinessDay.newDate.month(), Math.min(targetDay, Date.daysInMonth(companybusinessDay.newDate.year(), companybusinessDay.newDate.month())));
                     newCho.ChargentOrders__Charge_Date__c =  newCho.ChargentOrders__Payment_Frequency__c != SM_ChargentOrderHelper.paymentFrequency.ONCE ? String.valueOf(suggested.day()) : null;
                     newCho.ChargentOrders__Payment_End_Date__c = newCho.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE ? suggested : newCho.ChargentOrders__Payment_End_Date__c; 
                     newCho.ChargentOrders__Next_Transaction_Date__c = suggested;
                  }  
             }
             if (SM_Utils.isChangedField(newCho, oldCho, 'ChargentOrders__Payment_Start_Date__c') && newCho.ChargentOrders__Payment_Start_Date__c != null ){
                 // Use Date to avoid timezone side-effects
                 Date paymendDate = Date.newInstance(newCho.ChargentOrders__Payment_Start_Date__c.year(), newCho.ChargentOrders__Payment_Start_Date__c.month(), newCho.ChargentOrders__Payment_Start_Date__c.day());
                 DateTime paymendDT = DateTime.newInstance(paymendDate.year(), paymendDate.month(), paymendDate.day());
                 SM_Utils.CompanybusinessDay companybusinessDay = SM_Utils.getSuggestedBusinessHour(bHour, paymendDT);
                 if(companybusinessDay.businessDay){
                    // Preserve intended day
                    Integer targetDay = paymendDate.day();
                    Date suggested = Date.newInstance(companybusinessDay.newDate.year(), companybusinessDay.newDate.month(), Math.min(targetDay, Date.daysInMonth(companybusinessDay.newDate.year(), companybusinessDay.newDate.month())));
                    newCho.ChargentOrders__Charge_Date__c = newCho.ChargentOrders__Payment_Frequency__c != SM_ChargentOrderHelper.paymentFrequency.ONCE ? String.valueOf(suggested.day()) : null;
                    newCho.ChargentOrders__Payment_Start_Date__c = suggested;
                    newCho.ChargentOrders__Payment_End_Date__c = newCho.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE ? suggested : newCho.ChargentOrders__Payment_End_Date__c; 
                    newCho.ChargentOrders__Next_Transaction_Date__c = suggested;   
                 }  
              } 
        }
    }   

    /**
    * @description
    * @author Camilo Jimenez -> cjimenez@legal-credit.com | 08/11/2021
    * @param newContracts | List<ChargentOrders__ChargentOrder__c>
    **/
    private static void insertNextScheduledPaymentDate(List<ChargentOrders__ChargentOrder__c> newRecords){
        BusinessHours bHour=SM_Utils.getBusinessHour('Monee Business Hour');
        for (ChargentOrders__ChargentOrder__c newCho : newRecords) { 
         if((newCho.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE && newCho.ChargentOrders__Payment_Start_Date__c != null) || (newCho.ChargentOrders__Payment_Frequency__c != SM_ChargentOrderHelper.paymentFrequency.ONCE && newCho.ChargentOrders__Next_Transaction_Date__c != null)){
            DateTime paymendDate= newCho.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE ? DateTime.newInstance(newCho.ChargentOrders__Payment_Start_Date__c.year(),newCho.ChargentOrders__Payment_Start_Date__c.month(),newCho.ChargentOrders__Payment_Start_Date__c.day()) : 
            DateTime.newInstance(newCho.ChargentOrders__Next_Transaction_Date__c.year(),newCho.ChargentOrders__Next_Transaction_Date__c.month(),newCho.ChargentOrders__Next_Transaction_Date__c.day());
            SM_Utils.CompanybusinessDay companybusinessDay=SM_Utils.getSuggestedBusinessHour(bHour,paymendDate);
            if(companybusinessDay.businessDay){
               newCho.ChargentOrders__Charge_Date__c =newCho.ChargentOrders__Payment_Frequency__c != SM_ChargentOrderHelper.paymentFrequency.ONCE ? String.valueOf(companybusinessDay.newDate.day()) : null;
               if(newCho.ChargentOrders__Payment_Frequency__c == SM_ChargentOrderHelper.paymentFrequency.ONCE){
                  newCho.ChargentOrders__Payment_Start_Date__c = companybusinessDay.newDate;
                  newCho.ChargentOrders__Next_Transaction_Date__c = newCho.ChargentOrders__Next_Transaction_Date__c != null ? companybusinessDay.newDate : null;  
                  newCho.ChargentOrders__Payment_End_Date__c = companybusinessDay.newDate;   
               }else{
                  newCho.ChargentOrders__Payment_Start_Date__c = companybusinessDay.newDate;
                  newCho.ChargentOrders__Next_Transaction_Date__c = companybusinessDay.newDate;  
               } 
            }
        }
      }
    }

}