/*
    @Author : Santiago Rojas
    @BuiltDate : 30-01-2021
    @Description : Contract Payments handles class
    @Company : Trailhead
*/
public class SM_paymentTGR_Handler extends SM_TriggerHandler{

    public SM_paymentTGR_Handler(String triggerName){
        super(triggerName);
    }

    override public void BeforeInsert() {}

    override public void BeforeUpdate() {}

    override public void BeforeDelete() {}

    override public void AfterInsert() {

    }

    override public void AfterUpdate() {
        System.debug('Started Trigger ');
        /* Update the relatedContract */
        List<Contract> contractsToUpdateList = new List<Contract>();
        Try{
            Map<String,List<String>> idsMap = new Map<String,List<String>>();
            String trId = '';
            String orderId = '';
            for(sObject crObject: Trigger.newMap.values()){
                trId = String.valueOf(crObject.get('Id'));
                if(crObject.get('Payment_Status__c')!= Trigger.oldMap.get(trId).get('Payment_Status__c')){
                    orderId = String.valueOf(crObject.get('SM_ACH_Order__c'));
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

    override public void AfterDelete() {}


    override public void AfterUndelete() {}

    private void PupulateRelatedContract(Map<String,List<String>> ids, Map<Id, SObject> insertedData){
        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        Contract tmpCtr = new Contract();
        List<Contract> toUpdate = new List<Contract>();
        SM_Payment_Method__c tmpPaymentMethod = new SM_Payment_Method__c();
        map<Id,SM_Payment_Method__c> toInsertPaymentMethods = new map<Id,SM_Payment_Method__c>();
        SM_ACH_Order__c tmpACHOrder = new SM_ACH_Order__c();
        Set<String> AccountId = new Set<String>();
        structure.AdditionalFields = 'SM_Contract__r.Status,SM_Contract__r.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,'
                                    +'SM_Contract__r.SM_Charged_AC_Amount__c,SM_Contract__r.SM_Partially_Charged_AC_Fees__c,'
                                    +'SM_Contract__r.SM_Total_Charged_AC_Suscription__c,SM_Contract__r.SM_Charged_SB_Fees__c,'
                                    +'SM_Contract__r.SM_Partially_Charged_SB_Fees__c,SM_Contract__r.SM_Charged_SB_Amount__c,'
                                    +'SM_Contract__r.SM_Failed_SB_Fees__c,SM_Contract__r.SM_Total_AC__c,SM_Contract__r.AccountId,'
                                    +'SM_Contract__r.SM_Number_of_AC_Fees__c,SM_Contract__r.SM_Charged_AC_Fees__c,SM_Contract__r.SM_Failed_AC_Fees__c,'
                                    +'SM_Failed_payment__r.SM_ACH_Order__r.SM_Payment_Type__c,'
                                    +'SM_Failed_payment__r.SM_Original_Type__c,';
        structure.sObjectName = 'SM_ACH_Order__c';
        structure.whereClause = new map<String,List<object>>{'Id'=>new List<object>()};
        structure.orderByParent ='';
        for(String idData: ids.keySet()){
            structure.whereClause.get('Id').addAll(ids.get(idData));
        }
        map<Id,SObject> orders  = new Map<Id,SObject>(SM_Utils.getDynamicQuery(structure));
        System.debug(orders);
        List<SM_Payment__c> data = [SELECT SM_ACH_Order__c,Payment_Status__c,SM_ACH_Order__r.SM_Total__c, SM_Fee_value__c
                                                        FROM SM_Payment__c
                                                        WHERE ID=:insertedData.keySet()];
        for(SM_Payment__c cOT: data){
            tmpCtr = new Contract();
            tmpACHOrder = (SM_ACH_Order__c)orders.get(cOT.SM_ACH_Order__c);
            tmpCtr= tmpACHOrder.SM_Contract__r;
            // SMPII-148
            if (!tmpCtr.Status.equals(SM_ContractHelper.status.FINALIZED) && !tmpCtr.Status.equals(SM_ContractHelper.status.CANCELED)) {
                if(cOT.Payment_Status__c =='ACCEPTED'){
                    if(tmpACHOrder.SM_Payment_Type__c == 'AC'){
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
                        tmpCtr.SM_Charged_AC_Amount__c += cOT.SM_ACH_Order__r.SM_Total__c;
                        if(tmpCtr.SM_Charged_AC_Amount__c>= tmpCtr.SM_Total_AC__c){
                            tmpCtr.SM_AC_collected__c = true;
                            //tmpCtr.SM_Start_date__c = date.today();
                            tmpCtr.StartDate = date.today();
                            tmpCtr.status = 'Activated';
                        }
                    }
                    if(tmpACHOrder.SM_Payment_Type__c == 'Subscription' || tmpACHOrder.SM_Payment_Type__c == 'Fee'){
                        System.debug('Arrived');

                        tmpCtr.SM_Failed_SB_Fees__c = 0;
                        tmpCtr.SM_Charged_SB_Fees__c = tmpCtr.SM_Charged_SB_Fees__c==null?0:tmpCtr.SM_Charged_SB_Fees__c;
                        if(tmpCtr.status != 'Activated' && tmpCtr.SM_Charged_SB_Fees__c == 0){
                            tmpCtr.status = 'Activated';
                        }
                        tmpCtr.SM_Partially_Charged_SB_Fees__c = tmpCtr.SM_Partially_Charged_SB_Fees__c==null?0:tmpCtr.SM_Partially_Charged_SB_Fees__c;
                        tmpCtr.SM_Charged_SB_Amount__c = tmpCtr.SM_Charged_SB_Amount__c==null?0:tmpCtr.SM_Charged_SB_Amount__c;
                        tmpCtr.SM_Charged_SB_Fees__c +=+1;
                        tmpCtr.SM_Charged_SB_Amount__c += cOT.SM_ACH_Order__r.SM_Total__c;
                    }
                    // SFDCMP-367
                    //SMPII-7 CJ 12-10-2021 logic is removed so that it does not validate the failed payment
                    if (tmpACHOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE && tmpACHOrder.SM_Failed_payment__r?.SM_Original_Type__c != null) {
                        if (tmpACHOrder.SM_Failed_payment__r?.SM_Original_Type__c == 'AC') {
                            tmpCtr.SM_Failed_AC_Fees__c =0;
                            if(tmpCtr.SM_Charged_AC_Fees__c == null){
                                tmpCtr.Status = 'Payment Process';
                            }
                            // SM_Charged_AC_Fees__c:   Number of AC fees collected
                            tmpCtr.SM_Charged_AC_Fees__c = tmpCtr.SM_Charged_AC_Fees__c == null ? 0 : tmpCtr.SM_Charged_AC_Fees__c;
                            tmpCtr.SM_Charged_AC_Fees__c += 1;
                            // SM_Charged_AC_Amount__c: AC Collected value
                            tmpCtr.SM_Charged_AC_Amount__c = tmpCtr.SM_Charged_AC_Amount__c==null?0:tmpCtr.SM_Charged_AC_Amount__c;
                            if(tmpCtr.SM_Charged_AC_Amount__c == 0){
                                tmpCtr.SM_Payment_Received__c = true;
                            }
                            tmpCtr.SM_Charged_AC_Amount__c += cOT.SM_Fee_value__c != null ? cOT.SM_Fee_value__c : 0;
                            if(tmpCtr.SM_Charged_AC_Amount__c >= tmpCtr.SM_Total_AC__c){
                                tmpCtr.SM_AC_collected__c = true;
                                //tmpCtr.SM_Start_date__c = date.today();
                                tmpCtr.StartDate = date.today();
                                tmpCtr.status = 'Activated';
                            }
                            // This field is not being used
                            // tmpCtr.SM_Partially_Charged_AC_Fees__c = tmpCtr.SM_Partially_Charged_AC_Fees__c==null?0:tmpCtr.SM_Partially_Charged_AC_Fees__c;
                        }
                    }
                    // SFDCMP-367
                    tmpCtr.SM_Total_Charged_AC_Suscription__c = tmpCtr.SM_Total_Charged_AC_Suscription__c==null?0:tmpCtr.SM_Total_Charged_AC_Suscription__c;

                    tmpCtr.SM_Total_Charged_AC_Suscription__c = tmpCtr.SM_Total_Charged_AC_Suscription__c+cOT.SM_ACH_Order__r.SM_Total__c;
                }
                else if(cOT.Payment_Status__c =='REJECTED'){
                    System.debug('Arrived');
                    if(tmpACHOrder.SM_Payment_Type__c == 'AC'){
                        System.debug('Arrived');
                        tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c==null?0:tmpCtr.SM_Failed_AC_Fees__c;
                        tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c+1;
                        if(tmpCtr.SM_Failed_AC_Fees__c == tmpCtr.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c){
                            tmpCtr.Status = 'Cancelled';
                        }
                    }
                    if (tmpACHOrder.SM_Payment_Type__c == 'Subscription' || tmpACHOrder.SM_Payment_Type__c == 'Fee'){
                        System.debug('Arrived');
                        tmpCtr.SM_Failed_SB_Fees__c = tmpCtr.SM_Failed_SB_Fees__c==null?0:tmpCtr.SM_Failed_SB_Fees__c;
                        tmpCtr.SM_Failed_SB_Fees__c = tmpCtr.SM_Failed_SB_Fees__c+1;
                        if(tmpCtr.SM_Failed_SB_Fees__c == tmpCtr.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c){
                            tmpCtr.Status = 'Payment Rejection';
                        }
                    }
                    if (tmpACHOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE && tmpACHOrder.SM_Failed_payment__r?.SM_ACH_Order__r?.SM_Payment_Type__c != null) {
                        if (tmpACHOrder.SM_Failed_payment__r.SM_ACH_Order__r.SM_Payment_Type__c == 'AC') {
                            tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c==null?0:tmpCtr.SM_Failed_AC_Fees__c;
                            tmpCtr.SM_Failed_AC_Fees__c = tmpCtr.SM_Failed_AC_Fees__c+1;
                            if(tmpCtr.SM_Failed_AC_Fees__c == tmpCtr.SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c){
                                tmpCtr.Status = 'Cancelled';
                            }
                        }
                    }
                }
                if(tmpCtr.Id != null){
                    toUpdate.add(tmpCtr);
                }
            }
        }
        if(toInsertPaymentMethods.size()>0){
            insert toInsertPaymentMethods.values();
            //Pass info to Contract
            for(Contract ctr: toUpdate){
                Id pId = toInsertPaymentMethods.get(ctr.Id).Id;
                if(pId != null){
                    ctr.SM_Payment_Method__c = pId;
                }
            }
        }

        SM_BypassManager.disableValidationRules();
        update data;
        if(toUpdate.size()>0){
            update toUpdate;
        }
        SM_BypassManager.enableValidationRules();
    }


}