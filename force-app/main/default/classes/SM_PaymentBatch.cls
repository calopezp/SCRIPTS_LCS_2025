/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 07-13-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   03-25-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
@SuppressWarnings('PMD.AvoidGlobalModifier')
global without sharing class SM_PaymentBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static String query;
    private static Set<String> paymentTypes = new Set<String>{SM_ACHOrderHelper.paymentType.SUBSCRIPTION, SM_ACHOrderHelper.paymentType.AC, SM_ACHOrderHelper.paymentType.FEE, SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE};
    private static Set<String> paymentStatus = new Set<String>{SM_ACHOrderHelper.paymentStatus.COMPLETED, SM_ACHOrderHelper.paymentStatus.CANCELED, SM_ACHOrderHelper.paymentStatus.STOPPED};
    private static Date dateToProcess = System.today().addDays(1);
    private List<SM_Payment__c> payments = new List<SM_Payment__c>();
	// private Id achRecordTypeId = Schema.getGlobalDescribe().get('SM_Payment__c').getDescribe().getRecordTypeInfosByDeveloperName().get('ACH').getRecordTypeId();
	private String achRecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
    public Database.QueryLocator start(Database.BatchableContext bc){
        query = 'SELECT Id, SM_Payment_Type__c, SM_Charge_Date__c, SM_Payment_Method__c, SM_Next_Transaction_Date__c, SM_Total__c, SM_Fee_to_collect__c, SM_Apply_penalty__c, SM_Penalty_value__c, SM_Failed_payment__c, ' +
                'SM_Contract__c, SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c, SM_Contract__r.SM_Payment_Method__c, SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c, ' +
                'SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c, SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c, ' +
                'SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c, ' +
                'SM_Contract__r.SM_Customer_Cancellation__c ' +
                'FROM SM_ACH_Order__c ' +
                'WHERE SM_Payment_Type__c IN :paymentTypes ' +
                'AND SM_Payment_Status__c NOT IN :paymentStatus ' +
                'AND SM_Next_Transaction_Date__c <= :dateToProcess ' +
                'AND SM_Contract__r.SM_Customer_Cancellation__c = false ';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        SM_PaymentHelper.createPayments((List<SM_ACH_Order__c>)scope);

        // for (SM_ACH_Order__c achOrder : (List<SM_ACH_Order__c>) scope) {
        //     // SFDCMP-325 - JSPA - Added SM_IVU_State__c & SM_IVU_Municipal__c fields to the creation of payment
        //     // TODO: Llamar el metodo del helper que crea el payment
        //     payments.add(new SM_Payment__c(
        //         RecordTypeId = achRecordTypeId,
        //         SM_Recurring__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? true : false,
        //         SM_Type__c = achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? achOrder.SM_Payment_Type__c : 'Fee',
        //         SM_Payment_Method__c = achOrder.SM_Contract__r.SM_Payment_Method__c,
        //         SM_Contract__c = achOrder.SM_Contract__c,
        //         SM_Payment_Date__c = achOrder.SM_Next_Transaction_Date__c,
        //         Payment_Status__c = SM_PaymentHelper.status.ACH_PENDING,
        //         SM_ACH_Account_Number__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_ACH_Account_Number__c == null ? 0 : Decimal.valueOf(achOrder.SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c),
        //         SM_ACH_Account_Routing_Number__c = achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c,
        //         SM_Routing_Number_Check_Digit__c = achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c,
        //         SM_Fee_to_collect__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? achOrder.SM_Fee_to_collect__c : null,
        //         SM_ACH_Order__c = achOrder.Id,
        //         SM_Amount__c = achOrder.SM_Total__c,
        //         SM_P_IVU_State_Amount__c = achOrder.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,
        //         SM_P_IVU_Municipal_Amount__c = achOrder.SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c,
        //         SM_Failed_payment__c = achOrder.SM_Failed_payment__c
        //     ));
        // }
    }

    public void finish(Database.BatchableContext bc){
        // if (!payments.isEmpty()) {
        //     List<Database.SaveResult> sr = Database.insert(payments);
        //     System.debug('sr: ' + JSON.serialize(sr));
        // }
    }

}