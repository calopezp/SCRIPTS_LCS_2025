/*
    @Author : Santiago Rojas
    @BuiltDate : 30-01-2021
    @Description : Contract Trigger handler Class
    @Company : Trailhead
    @test: Covered by SM_ContractHandlerTest
*/
public class SM_chargentOrTr_Handler extends SM_TriggerHandler{

    public SM_chargentOrTr_Handler(String triggerName){
        super(triggerName);
    }

    override public void BeforeInsert() {
        // JSPA - Change transaction type from Authorization to Register Token
        SM_ErrorDescription_Helper.ErrorDescription(Trigger.new,null);
        updateTransactionType(Trigger.new);
    }

    override public void BeforeUpdate() {
        // MEMD - SMPII-12
        SM_ErrorDescription_Helper.ErrorDescription(Trigger.new,Trigger.old);
    }

    override public void BeforeDelete() {}

    override public void AfterInsert() {
        // JSPA - Update Chargent Order when this comes from a register token
        // MEMD - SMPII-12
        updateRegisterChargentOrder(Trigger.new);

        System.debug('Started Trigger ');
        /* Update the relatedContract */
        List<Contract> contractsToUpdateList = new List<Contract>();
        Try{
            Map<String,List<String>> idsMap = new Map<String,List<String>>();
            String trId = '';
            String orderId = '';
            for(sObject crObject: Trigger.newMap.values()){
                trId = String.valueOf(crObject.get('Id'));
                orderId = String.valueOf(crObject.get('ChargentOrders__Order__c'));
                System.debug(crObject);
                System.debug(trId);
                System.debug(orderId);
                if(!idsMap.containsKey(trId)){
                    idsMap.put(trId,new List<String>{orderId});
                }
                else{
                    idsMap.get(trId).add(orderId);
                }
            }
            System.debug(idsMap);
            if(idsMap.size()>0){
                PupulateRelatedContract(idsMap,Trigger.newMap);
            }

        }Catch(System.Exception ex){
            /* Call the TransactionLogHandler class method to create a log
               parameters need to pass in the method are System.Exception and the Handler ClassName
            */
            TransactionLogHandler.doHandleException(ex , 'contractTGRController');
        }
    }

    override public void AfterUpdate() {
    }

    override public void AfterDelete() {}


    override public void AfterUndelete() {}

    /************* Auxiliar methods *************/
    public static void updateTransactionType(List<ChargentOrders__Transaction__c> newRecords) {
        for (ChargentOrders__Transaction__c newRecord : newRecords) {
            if (newRecord.ChargentOrders__Type__c == 'Authorization' && newRecord.ChargentOrders__Amount__c == 0) newRecord.ChargentOrders__Type__c = 'Register Token';
        }
    }

    public static void updateRegisterChargentOrder(List<ChargentOrders__Transaction__c> newRecords) {
        List<ChargentOrders__ChargentOrder__c> chargentOrderToUpdate = new List<ChargentOrders__ChargentOrder__c>();
        for (ChargentOrders__Transaction__c record : newRecords) {
            if ((record.ChargentOrders__Type__c == 'Register Token' || record.ChargentOrders__Type__c == 'Authorization') && record.ChargentOrders__Amount__c == 0 && record.ChargentOrders__Order__c != null) {
                chargentOrderToUpdate.add(new ChargentOrders__ChargentOrder__c(
                    Id = record.ChargentOrders__Order__c,
                    SM_IsRegisterToken__c = true
                ));
            }
        }
        if (!chargentOrderToUpdate.isEmpty()) Database.update(chargentOrderToUpdate);
    }

    private void PupulateRelatedContract(Map<String,List<String>> ids, Map<Id, SObject> insertedData){
        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        Contract tmpCtr = new Contract();
        Map<String,Contract> toUpdate = new Map<String,Contract>();
        SM_Payment_Method__c tmpPaymentMethod = new SM_Payment_Method__c();
        map<Id,SM_Payment_Method__c> toInsertPaymentMethods = new map<Id,SM_Payment_Method__c>();
        ChargentOrders__ChargentOrder__c tmpChargentOrder = new ChargentOrders__ChargentOrder__c();
        map<Id,List<ChargentOrders__ChargentOrder__c>> approvedOrders = new map<Id,List<ChargentOrders__ChargentOrder__c>>();
        List<SM_Payment__c> payments = new List<SM_Payment__c>();
        Set<String> AccountId = new Set<String>();
        Map<String,Schema.SObjectType> globalDescribe =  Schema.getGlobalDescribe();
        String paymentStatus = '';
        String paymentCreditCardRecordType = globalDescribe.get('SM_Payment__c').getDescribe().getRecordTypeInfosByDeveloperName().get('Credit_Card').getRecordTypeId();
        structure.AdditionalFields = 'Contract__r.Status,Contract__r.SM_Payment_Method__c,Contract__r.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,'
                                     +'Contract__r.SM_Charged_AC_Amount__c,Contract__r.SM_Partially_Charged_AC_Fees__c,'
                                     +'Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,'
                                     +'Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c,'
                                     +'Contract__r.SM_Total_Charged_AC_Suscription__c,Contract__r.SM_Charged_SB_Fees__c,'
                                     +'Contract__r.SM_Partially_Charged_SB_Fees__c,Contract__r.SM_Charged_SB_Amount__c,'
                                     +'Contract__r.SM_Failed_SB_Fees__c,Contract__r.SM_Total_AC__c,Contract__r.AccountId,'
                                     +'SM_Failed_Payment__r.SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__r.SM_Payment_Type__c,'
                                     +'Contract__r.SM_Number_of_AC_Fees__c,Contract__r.SM_Charged_AC_Fees__c,Contract__r.SM_Failed_AC_Fees__c,'
                                     +'SM_Failed_Payment__r.SM_Original_Type__c,';
        structure.sObjectName = 'ChargentOrders__ChargentOrder__c';
        structure.whereClause = new map<String,List<object>>{'Id'=>new List<object>()};
        structure.orderByParent ='';
        for(String idData: ids.keySet()){
            structure.whereClause.get('Id').addAll(ids.get(idData));
        }
        map<Id,SObject> orders  = new Map<Id,SObject>(SM_Utils.getDynamicQuery(structure));
        System.debug(orders);
        List<ChargentOrders__Transaction__c> data = [SELECT ChargentOrders__Type__c,ChargentOrders__Order__c,ChargentOrders__Order__r.ChargentOrders__Card_Last_4__c,
                                                            ChargentOrders__Order__r.ChargentOrders__Card_Type__c,ChargentOrders__Order__r.ChargentOrders__Card_Year_Indicator__c,
                                                            ChargentOrders__Order__r.ChargentOrders__Credit_Card_Name__c,ChargentOrders__Order__r.SM_Fee_To_Collect__c,ChargentOrders__Order__r.ChargentOrders__Subtotal__c,
                                                            ChargentOrders__Order__r.ChargentOrders__Charge_Amount__c,ChargentOrders__Order__r.ChargentOrders__Payment_Received__c,
                                                            ChargentOrders__Response_Status__c,ChargentOrders__Order__r.ChargentOrders__UseTokenization__c,
                                                            ChargentOrders__Order__r.ChargentOrders__Card_Number__c,ChargentOrders__Tokenization__c,
                                                            ChargentOrders__Order__r.ChargentOrders__Card_Month_Indicator__c,
                                                            ChargentOrders__Order__r.Contract__r.AccountId,ChargentOrders__Order__r.Contract__c,
                                                            ChargentOrders__Order__r.SM_Apply_Penalty__c,
                                                            ChargentOrders__Order__r.SM_Penalty_value__c,
                                                            ChargentOrders__Order__r.SM_P_IVU_Municipal_Amount__c,
                                                            ChargentOrders__Order__r.SM_P_IVU_State_Amount__c
                                                        FROM ChargentOrders__Transaction__c
                                                        WHERE ID=:insertedData.keySet()];
        for(ChargentOrders__Transaction__c cOT: data){
            tmpCtr = new Contract();
            tmpChargentOrder = (ChargentOrders__ChargentOrder__c)orders.get(cOT.ChargentOrders__Order__c);
            tmpCtr= tmpChargentOrder.contract__r;
            if(cOT.ChargentOrders__Type__c=='Charge'){
                if(cOT.ChargentOrders__Response_Status__c =='Approved'){
                    paymentStatus = 'ACCEPTED';
                    // CJ 02-10-2021 logic is added to allow a contract to be activated if the chargent order  was a late paymen fee that was the result of an AC SFDCMP-389
                    if(tmpChargentOrder.SM_Payment_Type__c == 'AC' || (tmpChargentOrder.SM_Payment_Type__c == 'Late payment fee' && tmpChargentOrder.SM_Failed_Payment__r.SM_Original_Type__c == 'AC')){
                        System.debug(tmpCtr);
                        tmpCtr.SM_Failed_AC_Fees__c =0;
                        if(tmpCtr.SM_Charged_AC_Fees__c == null){
                            tmpCtr.Status = 'Payment Process';
                        }
                        tmpCtr.SM_Charged_AC_Fees__c = tmpCtr.SM_Charged_AC_Fees__c==null?0:tmpCtr.SM_Charged_AC_Fees__c;
                        tmpCtr.SM_Partially_Charged_AC_Fees__c = tmpCtr.SM_Partially_Charged_AC_Fees__c==null?0:tmpCtr.SM_Partially_Charged_AC_Fees__c;
                        tmpCtr.SM_Charged_AC_Amount__c = tmpCtr.SM_Charged_AC_Amount__c==null?0:tmpCtr.SM_Charged_AC_Amount__c;
                        if(tmpCtr.SM_Charged_AC_Amount__c == 0){
                            tmpCtr.SM_Payment_Received__c = true;
                        }
                        tmpCtr.SM_Charged_AC_Fees__c += 1;
                        tmpCtr.SM_Charged_AC_Amount__c += cOT.ChargentOrders__Order__r.SM_Apply_penalty__c ? (cOT.ChargentOrders__Order__r.ChargentOrders__Subtotal__c-cOT.ChargentOrders__Order__r.SM_Penalty_value__c) : cOT.ChargentOrders__Order__r.ChargentOrders__Subtotal__c;
                        if(cOT.ChargentOrders__Order__r.ChargentOrders__Payment_Received__c == 'Partial'){
                            tmpCtr.SM_Partially_Charged_AC_Fees__c += 1;
                        }
                        if(tmpCtr.SM_Charged_AC_Amount__c>= tmpCtr.SM_Total_AC__c){//Corregir el total no puede ser mayor al del contrato
                            tmpCtr.SM_AC_collected__c = true;
                            tmpCtr.StartDate = date.today();
                            tmpCtr.status = 'Activated';
                        }
                    }
                     // CJ 02-10-2021 logic is added to allow a contract to be activated if the chargent order  was a late paymen fee that was the result of an FEE SFDCMP-389
                    if(tmpChargentOrder.SM_Payment_Type__c == 'Subscription' || tmpChargentOrder.SM_Payment_Type__c == 'Fee' || 
                      (tmpChargentOrder.SM_Payment_Type__c == 'Late payment fee' 
                      && (tmpChargentOrder.SM_Failed_Payment__r.SM_Original_Type__c == 'Fee' || tmpChargentOrder.SM_Failed_Payment__r.SM_Original_Type__c == 'Subscription'))){
                        System.debug('Arrived');
                        approvedOrders.put(tmpCtr.Id,new List<ChargentOrders__ChargentOrder__c>{tmpChargentOrder});
                        tmpCtr.SM_Failed_SB_Fees__c = 0;
                        tmpCtr.SM_Charged_SB_Fees__c = tmpCtr.SM_Charged_SB_Fees__c==null?0:tmpCtr.SM_Charged_SB_Fees__c;
                        if(tmpCtr.status != 'Activated' && tmpCtr.SM_Charged_SB_Fees__c == 0){
                            tmpCtr.status = 'Activated';
                        }
                        tmpCtr.SM_Partially_Charged_SB_Fees__c = tmpCtr.SM_Partially_Charged_SB_Fees__c==null?0:tmpCtr.SM_Partially_Charged_SB_Fees__c;
                        tmpCtr.SM_Charged_SB_Amount__c = tmpCtr.SM_Charged_SB_Amount__c==null?0:tmpCtr.SM_Charged_SB_Amount__c;
                        tmpCtr.SM_Charged_SB_Fees__c +=1;
                        if(cOT.ChargentOrders__Order__r.ChargentOrders__Payment_Received__c == 'Partial'){
                            tmpCtr.SM_Partially_Charged_SB_Fees__c += 1;
                        }
                        tmpCtr.SM_Charged_SB_Amount__c += cOT.ChargentOrders__Order__r.ChargentOrders__Charge_Amount__c;
                    }
                    tmpCtr.SM_Total_Charged_AC_Suscription__c = tmpCtr.SM_Total_Charged_AC_Suscription__c==null?0:tmpCtr.SM_Total_Charged_AC_Suscription__c;

                    tmpCtr.SM_Total_Charged_AC_Suscription__c = tmpCtr.SM_Total_Charged_AC_Suscription__c+cOT.ChargentOrders__Order__r.ChargentOrders__Charge_Amount__c;
                }
                else if(cOT.ChargentOrders__Response_Status__c =='Declined' || cOT.ChargentOrders__Response_Status__c =='Error'){
                    paymentStatus = 'REJECTED';
                    System.debug('Arrived');
                    if(tmpChargentOrder.SM_Payment_Type__c == 'AC' || (tmpChargentOrder.SM_Payment_Type__c == 'Late payment fee' && tmpChargentOrder.SM_Failed_Payment__r.SM_Original_Type__c == 'AC')){
                        System.debug('Arrived');
                        tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c==null?0:tmpCtr.SM_Failed_AC_Fees__c;
                        tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c+1;
                        if(tmpCtr.SM_Failed_AC_Fees__c == tmpCtr.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c){
                            tmpCtr.Status = 'Cancelled';
                        }
                    }
                    else{
                        System.debug('Arrived');
                        if(tmpChargentOrder.SM_Payment_Type__c != 'Late payment fee') approvedOrders.put(tmpCtr.Id,new List<ChargentOrders__ChargentOrder__c>{tmpChargentOrder});
                        tmpCtr.SM_Failed_SB_Fees__c = tmpCtr.SM_Failed_SB_Fees__c==null?0:tmpCtr.SM_Failed_SB_Fees__c;
                        tmpCtr.SM_Failed_SB_Fees__c = tmpCtr.SM_Failed_SB_Fees__c+1;
                        if(tmpCtr.SM_Failed_SB_Fees__c == tmpCtr.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c){
                            tmpCtr.Status = 'Payment Rejection';
                        }
                    }
                }
                payments.add(
                    new sm_payment__c(
                        RecordTypeId = paymentCreditCardRecordType,
                        SM_Recurring__c = tmpChargentOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? true : false,
                        SM_Type__c = tmpChargentOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? tmpChargentOrder.SM_Payment_Type__c : 'Fee',
                        SM_Payment_Method__c = tmpCtr.SM_Payment_Method__c,
                        SM_Contract__c = tmpCtr.Id,
                        SM_Payment_Date__c =tmpChargentOrder.ChargentOrders__Next_Transaction_Date__c != null ? tmpChargentOrder.ChargentOrders__Next_Transaction_Date__c : tmpChargentOrder.ChargentOrders__Payment_Start_Date__c,
                        Payment_Status__c = paymentStatus,
                        SM_Chargent_Orders_Transaction__c = cOT.id,
                        SM_Fee_to_collect__c = tmpChargentOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || tmpChargentOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? tmpChargentOrder.SM_Fee_to_collect__c : null,
                        SM_Amount__c = tmpChargentOrder.ChargentOrders__Subtotal__c,
                        // CJ 26-09-2022 SMMCI-44
                        SM_P_IVU_State_Amount__c = cOT.ChargentOrders__Order__r.SM_P_IVU_State_Amount__c,
                        SM_P_IVU_Municipal_Amount__c = cOT.ChargentOrders__Order__r.SM_P_IVU_Municipal_Amount__c,
                        // SFDCMP-361
                        //SFDCMP-389 logic is modified CJ SM_Penalty_value__c,SM_Fee_value__c 05-10-2021
                        SM_Penalty_value__c = tmpChargentOrder.SM_Apply_penalty__c ? tmpChargentOrder.SM_Penalty_value__c : 0,
                        SM_Fee_value__c = tmpChargentOrder.SM_Apply_penalty__c ? (tmpChargentOrder.ChargentOrders__Subtotal__c-tmpChargentOrder.SM_Penalty_value__c) : tmpChargentOrder.ChargentOrders__Subtotal__c,
                        SM_Failed_payment__c = tmpChargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE ? tmpChargentOrder.SM_Failed_Payment__c : null,
                        //SMPII-7 CJ 12-10-2021
                        SM_Original_Type__c = tmpChargentOrder.SM_Payment_Type__c != SM_ChargentOrderHelper.paymentType.LATE_PAYMENT_FEE ? tmpChargentOrder.SM_Payment_Type__c : null
                    )
                );
            }
            cOT.Contract__c=tmpCtr.Id;
            cOT.ChargentOrders__Account__c = tmpCtr.AccountId;
            cOT.SM_Fee_to_collect__c = tmpChargentOrder.SM_Fee_to_collect__c;
            if(tmpCtr.Id != null){
                toUpdate.put(tmpCtr.Id,tmpCtr);
            }

        }
        if(toInsertPaymentMethods.size()>0){
            insert toInsertPaymentMethods.values();
            //Pass info to Contract
            for(String ctrid: toUpdate.keySet()){
                Id pId = toInsertPaymentMethods.get(ctrid).Id;
                if(pId != null){
                    toUpdate.get(ctrid).SM_Payment_Method__c = pId;
                }
            }
        }
        System.debug('The first 2 Mehtod');
        System.debug('The first 2 Mehtod');
        System.debug(approvedOrders);
        SM_BypassManager.disableValidationRules();
        update data;
        if(toUpdate.size()>0){
            update toUpdate.values();
        }
        if(payments.size()>0){
            insert payments;
        }
        if(approvedOrders.size()> 0){
            validateAndCalculateNextAssetFee(approvedOrders);
            System.debug(approvedOrders);
            List<ChargentOrders__ChargentOrder__c> ordersApproved = new List<ChargentOrders__ChargentOrder__c>();
            for(List<ChargentOrders__ChargentOrder__c> ordersUpdated : approvedOrders.values()){
                if(ordersUpdated != null){
                    ordersApproved.addAll(ordersUpdated);
                }
            }
            update ordersApproved;
        }
        SM_BypassManager.enableValidationRules();
    }
    private static void validateAndCalculateNextAssetFee( map<Id,List<ChargentOrders__ChargentOrder__c>> ordersPerContract){
        System.debug(ordersPerContract);
        Map<Id,List<ChargentOrders__ChargentOrder__c>> mapContractOrders = new map<Id,List<ChargentOrders__ChargentOrder__c>>();
        List<ChargentOrders__ChargentOrder__c> tempOders = new List<ChargentOrders__ChargentOrder__c>();
        List<ChargentOrders__ChargentOrder__c> orders = new List<ChargentOrders__ChargentOrder__c>();
        Id tempContractId = null;
        List<Double> fees = new List<Double>();
        List<Double> Previousfees = new List<Double>();
        Map<Id,Integer> feesByContract = new Map<Id,Integer>();
        List<SM_Asset_Fee__c> previousAndNextAssetsToUpdate = new List<SM_Asset_Fee__c>();
        List<ChargentOrders__ChargentOrder__c> finishedOrders = new List<ChargentOrders__ChargentOrder__c>();
        Map<String,String> ctrIdsDependeByCtrIdsMaster = new Map<String,String>();
        Set<String> idsContract = new Set<String>();
        for(Id contractId: ordersPerContract.keySet()){
            for(ChargentOrders__ChargentOrder__c order:ordersPerContract.get(contractId)){
                Previousfees.add(order.sm_Fee_To_Collect__C);
                order.sm_Fee_To_Collect__C = order.sm_Fee_To_Collect__C != null ? order.sm_Fee_To_Collect__C+1 : 0;
                fees.add(order.sm_Fee_To_Collect__C);
                orders.add(order);
                feesByContract.put(contractId, Integer.valueOf(order.sm_Fee_To_Collect__C));
                idsContract.add(contractId);
            }
        }
         // CJ 06/08/2022 SMMCI-27
         for(Contract ctr : [SELECT id, (SELECT ID,Collection_Main_Contract__c,Principal_Contract__c FROM Contracts1__r) FROM Contract WHERE ID IN: idsContract ]){
            if(!ctr.Contracts1__r.isEmpty()){
               for(Contract ctr1: ctr.Contracts1__r){
                   if(ctr1.Collection_Main_Contract__c == SM_ContractHelper.collectionMain.READY_FOR_COLLECTION){
                      ordersPerContract.put(ctr1.id,null);
                      ctrIdsDependeByCtrIdsMaster.put(ctr1.id, ctr1.Principal_Contract__c);
                   }
               }
            }
        }
        System.debug(Previousfees);
        System.debug(fees);
        System.debug(feesByContract);
        List<SM_Asset_Fee__c> previousAssetFees = [SELECT Id,SM_PrincipalContract__c,SM_Contract__c,SM_Position__c,SM_type__c FROM SM_Asset_Fee__c WHERE SM_Position__c in:Previousfees AND sm_Contract__c in:ordersPerContract.keySet() AND sm_Fee_To_Collect__c = true];
        List<SM_Asset_Fee__c> nextAssetFees = [SELECT Id,SM_PrincipalContract__c,SM_Contract__c,SM_Position__c,SM_Chargent_Order__r.ChargentOrders__Next_Transaction_Date__c FROM SM_Asset_Fee__c WHERE SM_Position__c in:fees AND sm_Contract__c in:ordersPerContract.keySet() AND sm_Fee_To_Collect__c = false];
        for(SM_Asset_Fee__c previousFee:previousAssetFees){
            Integer feeToCollect = previousFee.SM_PrincipalContract__c != null && feesByContract.containsKey(previousFee.SM_PrincipalContract__c)  ? (feesByContract.get(previousFee.SM_PrincipalContract__c)-1) :
                                  (feesByContract.get(previousFee.SM_Contract__c)-1);
            if(feeToCollect == previousFee.SM_Position__c)
            {
                if(previousFee.SM_type__c == 'Subscription'){
                    previousFee.sm_Fee_To_Collect__c = true;
                    previousFee.SM_Position__c+=1;
                    previousFee.SM_Position_Text__c= String.valueOf(previousFee.SM_Position__c);
                }
                else{
                    previousFee.sm_Fee_To_Collect__c = false;
                }
                previousFee.SM_Date__c = Date.valueOf(System.now());
                previousFee.SM_Status__c = 'Success';
                previousAndNextAssetsToUpdate.add(previousFee);
            }
        }
        for(SM_Asset_Fee__c nextAssetFee:nextAssetFees){
            Integer feeToCollect = nextAssetFee.SM_PrincipalContract__c != null && feesByContract.containsKey(nextAssetFee.SM_PrincipalContract__c)  ? feesByContract.get(nextAssetFee.SM_PrincipalContract__c) :
                                   feesByContract.get(nextAssetFee.SM_PrincipalContract__c);
            if(feeToCollect == nextAssetFee.SM_Position__c){
                nextAssetFee.sm_Fee_To_Collect__c = true;
                nextAssetFee.SM_Date__c = nextAssetFee.SM_Chargent_Order__r.ChargentOrders__Next_Transaction_Date__c;
                previousAndNextAssetsToUpdate.add(nextAssetFee);
            }
        }
        update previousAndNextAssetsToUpdate;

        AggregateResult[] amountsPerContract = [
            SELECT SUM(SM_Amount__c) Amount,SM_Position_Text__c Position,sm_Contract__c Contract
            FROM SM_Asset_Fee__c
            WHERE sm_Contract__c in:ordersPerContract.keySet() AND
                ((sm_Fee_To_Collect__c = true AND SM_Position__c in:fees) OR SM_Type__c = 'Subscription')
            GROUP BY sm_Contract__c,SM_Position_Text__c
        ];
        //Store the summary of all the asset Fees required in a map Contract,Amount
        map<Id,Map<Integer,Decimal>> mapAmountsPerContract = new map<Id,Map<Integer,Decimal>>();
        Id contractId = null;
        Double sumFees = null;
        Integer position =null;
        Double value =null;
        Map<Integer,Double> tmpMap = new Map<Integer,Double>();
        for(AggregateResult contractAmount: amountsPerContract){
            contractId = !ctrIdsDependeByCtrIdsMaster.isEmpty() && ctrIdsDependeByCtrIdsMaster.containsKey(String.valueOf(contractAmount.get('Contract'))) ? 
                          ctrIdsDependeByCtrIdsMaster.get(String.valueOf(contractAmount.get('Contract'))) : String.valueOf(contractAmount.get('Contract'));
            sumFees = Decimal.valueOf(String.valueOf(contractAmount.get('Amount')));
            position = Integer.valueOf(String.valueOf(contractAmount.get('Position')));
            if(mapAmountsPerContract.containsKey(contractId)){
                tmpMap = mapAmountsPerContract.get(contractId);
                if(tmpMap.containsKey(position)){
                    value = tmpMap.get(position);
                    value += sumFees;
                    mapAmountsPerContract.get(contractId).put(position,value);
                }
                else{
                    mapAmountsPerContract.get(contractId).put(
                        position, sumFees
                    );
                }
            }
            else{
                mapAmountsPerContract.put(contractId,
                    new Map<Integer,Double>{position=>sumFees}
                );
            }
        }
        //Store the orders related to the Contract--- Currently only suscription and it will be only one. but the method takes a list as per the standards
        for(ChargentOrders__ChargentOrder__c order :orders){
            tempContractId = order.Contract__c;
            if(mapContractOrders.containsKey(tempContractId)){
                mapContractOrders.get(tempContractId).add(order);
            }
            else{
                mapContractOrders.put(tempContractId,new List<ChargentOrders__ChargentOrder__c>{order});
            }
        }
        //Gets the amount to be populated in the order and fills it
        for(Id contractIdent : mapContractOrders.keySet()){
            Id contractIdTem = !ctrIdsDependeByCtrIdsMaster.isEmpty() && ctrIdsDependeByCtrIdsMaster.containsKey(contractIdent) ? ctrIdsDependeByCtrIdsMaster.get(contractIdent) : 
                                contractIdent;
            Integer currentFee = feesByContract.get(contractIdTem);
            System.debug(mapContractOrders.get(contractIdTem));
            for(ChargentOrders__ChargentOrder__c order : mapContractOrders.get(contractIdTem)){
                if(!mapAmountsPerContract.containsKey(contractIdTem)){
                    // JSPA - 09/17/2021
                    // TODO: Pending understand and fix it
                    // order.sm_Fee_To_Collect__C = order.sm_Fee_To_Collect__C-1;
                    // order.ChargentOrders__Payment_End_Date__c = Date.valueOf(System.now());
                    // order.ChargentOrders__Payment_Status__c = 'Stopped';
                }
                if(mapAmountsPerContract.containsKey(contractIdTem) && mapAmountsPerContract.get(contractIdTem).containsKey(currentFee)){
                    order.ChargentOrders__Subtotal__c = mapAmountsPerContract.get(contractIdTem).get(currentFee);
                    Decimal subtotal = (order.ChargentOrders__Subtotal__c*order.SM_P_IVU_Municipal_Amount__c)/100;
                    subtotal += (order.ChargentOrders__Subtotal__c*order.SM_P_IVU_State_Amount__c)/100;
                    System.debug(subtotal);
                    subtotal = subtotal.setScale(3);
                    order.ChargentOrders__Tax__c = subtotal;
                    order.ChargentOrders__Charge_Amount__c = order.ChargentOrders__Subtotal__c+subtotal;
                }
            }
        }
        ordersPerContract = mapContractOrders;
    }

   /* private void processRejectedPayments(Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap) {
        // Map<String, SM_Payment__c> paymentsToProcess = new Map<String, SM_Payment__c>();
        Set<String> paymentsToProcess = new Set<String>();
        for (Id newRecordId : newRecordsMap.keySet()) {
            system.debug('PPruebas22-->');
            ChargentOrders__ChargentOrder__c oldRecord = (ChargentOrders__ChargentOrder__c)oldRecordsMap.get(newRecordId);
            ChargentOrders__ChargentOrder__c newRecord = (ChargentOrders__ChargentOrder__c)newRecordsMap.get(newRecordId);
            if (SM_Utils.isChangedField(newRecord, oldRecord, 'ChargentOrders__Payment_Status__c') && newRecord.ChargentOrders__Payment_Status__c == 'Error') {
                newRecord.ChargentOrders__Payment_Status__c='Recurring';
            }
        }
    }*/
}