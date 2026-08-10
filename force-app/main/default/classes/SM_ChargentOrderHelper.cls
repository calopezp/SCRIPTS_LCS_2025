/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 09-26-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   07-02-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
 * 1.1   12-10-2021   Camilo J. Jiemenz B ->    cjimenez@legal-credit.com   Initial Version
**/
public without sharing class SM_ChargentOrderHelper {

    //Instances of enums
    public static PaymentStatusEnum paymentStatus = new PaymentStatusEnum();
    public static PaymentTypeEnum paymentType = new PaymentTypeEnum();
    public static PurposeOfPaymentEnum purposeOfPayment = new PurposeOfPaymentEnum();
    public static StatusEnum status = new StatusEnum();
    public static PaymentStopEnum paymentStop = new PaymentStopEnum();
    public static ApprovalStatusEnum approvalStatus = new ApprovalStatusEnum();
    public static PaymentFrequencyEnum paymentFrequency = new PaymentFrequencyEnum();

    /** This class represents Enum to attribute Payment Status (Developer name) */
    public class PaymentStatusEnum {
        public final String RECURRING = 'Recurring';
        public final String COMPLETE = 'Complete';
        public final String STOPPED = 'Stopped';
        public final String ERROR = 'Error';
        public final String CANCELED='Canceled';
        public final String AUTOMATED_COLLECTION = 'Automated Collection';
    }

    public class PaymentTypeEnum {
        public final String AC = 'AC';
        public final String SUBSCRIPTION = 'Subscription';
        public final String FEE = 'Fee';
        public final String REGISTER_TOKEN = 'Register Token';
        public final String LATE_PAYMENT_FEE = 'Late payment fee';
    }

    public class PurposeOfPaymentEnum {
        public final String CONTRACT_FEE = 'Contract fee';
        public final String COLLECT_STR = 'Collect';
    }

    public class StatusEnum {
        public final String INITIATED = 'Initiated';
        public final String COMPLETE = 'Complete';
        public final String CANCELED = 'Canceled';
    }

    public class PaymentStopEnum {
        public final String DATE_STR = 'Date';
        public final String COUNT = 'Count';
        public final String BALANCE_DUE = 'Balance Due';
        public final String UNENDINGD = 'Unending';
    }

    public class ApprovalStatusEnum {
        public final String ACCEPTED = 'Accepted';
        public final String PENDING_APPROVAL = 'Pending approval';
        public final String REJECTED = 'Rejected';
    }

    public class PaymentFrequencyEnum {
        public final String ONCE = 'Once';
    }


    @AuraEnabled
    public static ResponseWrapper chargeChargentOrder(String chargentOrderId, String nextTransactionDate) {
        System.debug('-----> ' + nextTransactionDate);
        try {
            ResponseWrapper response;
            System.debug('RecordId: ' + chargentOrderId);
            String json = '{"ObjectId":"' + chargentOrderId +  '"}';
            // json = String.format(json, new List<String>{chargentOrderId});
            System.debug('json: ' + json);
            ChargentOrders.TChargentOperations.TChargentResult result = ChargentOrders.tChargentOperations.ChargeOrder_ClickJSON(json);
            System.debug('result: ' + result);
            if (result.Status == 'OK' && String.isNotBlank(result.TransactID)) {
                ChargentOrders__Transaction__c transactionCreated = getTransactionCreated(result.TransactID);
                if (transactionCreated.ChargentOrders__Response_Status__c == 'Approved') {
                    update new ChargentOrders__Transaction__c(Id = result.TransactID, ChargentOrders__Recurring__c = true);
                    updateChargentOrder(chargentOrderId, nextTransactionDate);
                    response = new ResponseWrapper(true, 'Charge succesfully');
                } else {
                    update new ChargentOrders__ChargentOrder__c(Id = chargentOrderId, ChargentOrders__Payment_Status__c = 'Error');
                    String message = transactionCreated.ChargentOrders__Response_Status__c + ': '
                        + transactionCreated.ChargentOrders__Response_Message__c
                        + ' - Show transaction record for more details';
                    response = new ResponseWrapper(false, message);
                }
            } else {
                throw new AuraHandledException('An unexpected error has occured');
            }
            return response;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static ChargentOrders__Transaction__c getTransactionCreated(String transactinId) {
        return[
            SELECT ChargentOrders__Response_Status__c, ChargentOrders__Response_Message__c
            FROM ChargentOrders__Transaction__c
            WHERE Id =: transactinId];
    }

    private static void updateChargentOrder(String chargentOrderId, String nextTransactionDate) {
        ChargentOrders__ChargentOrder__c chargentOrder = [
            SELECT Id, ChargentOrders__Payment_Status__c, ChargentOrders__Payment_Stop__c, ChargentOrders__Payment_Count__c,
            ChargentOrders__Transaction_Count_Recurring__c, ChargentOrders__Next_Transaction_Date__c,
            ChargentOrders__Payment_Start_Date__c, SM_Payment_Type__c, ChargentOrders__Charge_Date__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Id =: chargentOrderId
        ];
        if (String.isNotBlank(nextTransactionDate)) {
            List<String> dateValues = nextTransactionDate.split('-');
            chargentOrder.ChargentOrders__Next_Transaction_Date__c = Date.newInstance(Integer.valueOf(dateValues[0]), Integer.valueOf(dateValues[1]), Integer.valueOf(dateValues[2]));
        }
        // This apply to AC Chargent Orders
        if (chargentOrder.ChargentOrders__Payment_Stop__c == SM_ChargentOrderHelper.paymentStop.COUNT
            && chargentOrder.ChargentOrders__Payment_Count__c == 1) {
            chargentOrder.ChargentOrders__Payment_Status__c = SM_ChargentOrderHelper.paymentStatus.COMPLETE;
        }
        // This apply to first and middle payments of Fix Term Chargent Orders
        if (chargentOrder.ChargentOrders__Transaction_Count_Recurring__c < chargentOrder.ChargentOrders__Payment_Count__c) {
            if (chargentOrder.ChargentOrders__Next_Transaction_Date__c != null) {
                if (chargentOrder.ChargentOrders__Charge_Date__c != null) {
                    chargentOrder.ChargentOrders__Next_Transaction_Date__c =
                        Date.newInstance(
                            chargentOrder.ChargentOrders__Next_Transaction_Date__c.year(),
                            chargentOrder.ChargentOrders__Next_Transaction_Date__c.month(),
                            Integer.valueOf(chargentOrder.ChargentOrders__Charge_Date__c)
                        );
                }
                // CJ 30-10-2021 SMPII-46
                chargentOrder.ChargentOrders__Next_Transaction_Date__c = chargentOrder.ChargentOrders__Next_Transaction_Date__c.addMonths(1);
                chargentOrder.ChargentOrders__Payment_Start_Date__c= chargentOrder.ChargentOrders__Next_Transaction_Date__c;
                chargentOrder.ChargentOrders__Charge_Date__c = String.valueOf(chargentOrder.ChargentOrders__Next_Transaction_Date__c.day());
            } else if (chargentOrder.ChargentOrders__Payment_Start_Date__c != null) {
                if (chargentOrder.ChargentOrders__Charge_Date__c != null) {
                    chargentOrder.ChargentOrders__Next_Transaction_Date__c =
                        Date.newInstance(
                            chargentOrder.ChargentOrders__Payment_Start_Date__c.year(),
                            chargentOrder.ChargentOrders__Payment_Start_Date__c.month(),
                            Integer.valueOf(chargentOrder.ChargentOrders__Charge_Date__c)
                        );
                }
                // CJ 30-10-2021 SMPII-46
                chargentOrder.ChargentOrders__Next_Transaction_Date__c = chargentOrder.ChargentOrders__Payment_Start_Date__c.addMonths(1);
                chargentOrder.ChargentOrders__Payment_Start_Date__c= chargentOrder.ChargentOrders__Next_Transaction_Date__c;
                chargentOrder.ChargentOrders__Charge_Date__c = String.valueOf(chargentOrder.ChargentOrders__Next_Transaction_Date__c.day());
            }
        }
        // This apply to the last payment of Fix Term Chargent Orders
        if (chargentOrder.ChargentOrders__Transaction_Count_Recurring__c == chargentOrder.ChargentOrders__Payment_Count__c) {
            chargentOrder.ChargentOrders__Payment_Status__c = SM_ChargentOrderHelper.paymentStatus.COMPLETE;
        }
        // This apply to all payments of Subs Chargent Orders
        if (chargentOrder.SM_Payment_Type__c == SM_ChargentOrderHelper.paymentType.SUBSCRIPTION) {
            if (chargentOrder.ChargentOrders__Next_Transaction_Date__c != null) {
                if (chargentOrder.ChargentOrders__Charge_Date__c != null) {
                    chargentOrder.ChargentOrders__Next_Transaction_Date__c =
                        Date.newInstance(
                            chargentOrder.ChargentOrders__Next_Transaction_Date__c.year(),
                            chargentOrder.ChargentOrders__Next_Transaction_Date__c.month(),
                            Integer.valueOf(chargentOrder.ChargentOrders__Charge_Date__c)
                        );
                }
                // CJ 30-10-2021 SMPII-46
                chargentOrder.ChargentOrders__Next_Transaction_Date__c = chargentOrder.ChargentOrders__Next_Transaction_Date__c.addMonths(1);
                chargentOrder.ChargentOrders__Payment_Start_Date__c= chargentOrder.ChargentOrders__Next_Transaction_Date__c;
                chargentOrder.ChargentOrders__Charge_Date__c = String.valueOf(chargentOrder.ChargentOrders__Next_Transaction_Date__c.day());
            } else if (chargentOrder.ChargentOrders__Payment_Start_Date__c != null) {
                if (chargentOrder.ChargentOrders__Charge_Date__c != null) {
                    chargentOrder.ChargentOrders__Next_Transaction_Date__c =
                        Date.newInstance(
                            chargentOrder.ChargentOrders__Payment_Start_Date__c.year(),
                            chargentOrder.ChargentOrders__Payment_Start_Date__c.month(),
                            Integer.valueOf(chargentOrder.ChargentOrders__Charge_Date__c)
                        );
                }
                chargentOrder.ChargentOrders__Next_Transaction_Date__c = chargentOrder.ChargentOrders__Payment_Start_Date__c.addMonths(1);
                chargentOrder.ChargentOrders__Payment_Start_Date__c= chargentOrder.ChargentOrders__Next_Transaction_Date__c;
                chargentOrder.ChargentOrders__Charge_Date__c = String.valueOf(chargentOrder.ChargentOrders__Next_Transaction_Date__c.day());
            }
        }
        update chargentOrder;
    }

    /**
    * @description Method to get quantity of chargent orders in approval pending status by contract Id
    * @author Jonathan Pachon -> diego.jacanamijoy@gmail.es | 07-25-2021
    * @param Set<Id> contractIds
    * @return Map<String,Integer>
    **/
    public static Map<String,Integer> getPendingApprovalChargentOrders(Set<Id> contractIds) {
        Map<String,Integer> qtyOfPendingApprovalByContractId = new Map<String,Integer>();
        for (ChargentOrders__ChargentOrder__c chargentOrder : [SELECT Id, Contract__c FROM ChargentOrders__ChargentOrder__c WHERE Contract__c IN: contractIds AND SM_Approval_Status__c =: SM_ChargentOrderHelper.approvalStatus.PENDING_APPROVAL]) {
            if (String.isNotBlank(chargentOrder.Contract__c) && !qtyOfPendingApprovalByContractId.containsKey(chargentOrder.Contract__c) ) qtyOfPendingApprovalByContractId.put(chargentOrder.Contract__c, 0);
            qtyOfPendingApprovalByContractId.put(chargentOrder.Contract__c, qtyOfPendingApprovalByContractId.get(chargentOrder.Contract__c) + 1);
        }
        return qtyOfPendingApprovalByContractId;
    }

    /**
    * @description Method to create chargent order record
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 19/07/2021g
    * @param paymentMethod
    * @return ChargentOrders__ChargentOrder__c
    **/
    public static ChargentOrders__ChargentOrder__c createChargentOrder(SM_Payment_Method__c paymentMethod){

        Contract contract;//First related contract

        //If not has related contracts return null
        if(!paymentMethod.Contracts__r.isEmpty()){
            contract = paymentMethod.Contracts__r[0];
        }else{
            return null;
        }

        ChargentOrders__ChargentOrder__c chargentOrder = new ChargentOrders__ChargentOrder__c(
            ChargentOrders__Charge_Amount__c = 0,
            ChargentOrders__Billing_First_Name__c = paymentMethod.SM_Account__r.FirstName,
            ChargentOrders__Billing_Last_Name__c = paymentMethod.SM_Account__r.LastName,
            ChargentOrders__Billing_Address__c = contract.SM_Billing_Address__r?.Street,
            ChargentOrders__Billing_City__c = contract.SM_Billing_Address__r?.City,
            ChargentOrders__Billing_State__c = contract.SM_Billing_Address__r?.State,
            ChargentOrders__Billing_Zip_Postal__c = contract.SM_Billing_Address__r?.PostalCode,
            ChargentOrders__Billing_Country__c = contract.SM_Billing_Address__r?.Country,
            ChargentOrders__Account__c = contract.AccountId,
            ChargentOrders__Gateway__c = contract.SM_Opportunity__r?.SM_Company_Setting__r?.SM_Gateway__c,
            Contract__c = contract.Id,
            SM_Payment_Type__c = paymentType.REGISTER_TOKEN,
            ChargentOrders__Payment_Start_Date__c = System.today().addDays(1),
            ChargentOrders__Payment_Method__c = 'Credit Card',
            ChargentOrders__Payment_Status__c = 'Recurring'
            );

        return chargentOrder;
    }



      /**
    * @description Method to create chargent order record
    * @author Camilo Jimenez ->cjimenez@legal-credit.com | 30/09/2021
    * @param id,isApplyingDaysCollectedPenalty,nextTransactionDate,chargeDate,paymentStatus,paymentCount
    * @return ChargentOrders__ChargentOrder__c
    **/
    public static ChargentOrders__ChargentOrder__c updateChargentOrderError(String id,Boolean isApplyingDaysCollectedPenalty,Date nextTransactionDate,String chargeDate,String paymentStatus){
        return new ChargentOrders__ChargentOrder__c( id = id
                                                    //,SM_IsApplyingDaysCollectedPenalty__c = isApplyingDaysCollectedPenalty
                                                    ,ChargentOrders__Next_Transaction_Date__c = nextTransactionDate
                                                    ,ChargentOrders__Charge_Date__c = chargeDate
                                                    ,ChargentOrders__Payment_Status__c = paymentStatus);
    
    }

    /**
    * @description Inner clas to tokenization process
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 16/07/2021
    **/
    public class ChargentWrapper {
        String ObjectId;
        String CardMonth;
        String CardYear;
        String CardType;
        String CardNumber;
        String PaymentMethod;
        Double ChargeAmount;
        String CardSecurity;
        String BillingFirst;
        String BillingLast;
        String BillingAddress;
        String BillingCity;
        String BillingState;
        String BillingZip;
        String BillingCountry;
        Boolean RegisterTokenOnly;

        public ChargentWrapper(SM_Payment_Method__c paymentMethod) {

            this.ObjectId = paymentMethod.SM_Chargent_Order__c <> null ? paymentMethod.SM_Chargent_Order__c : paymentMethod.SM_Chargent_Order__r.Id;
            this.CardMonth = SM_ChargentOrderHelper.validateEmptyvalues('CardMonth', paymentMethod.SM_Credit_Card_expiration_month__c);
            this.CardYear = SM_ChargentOrderHelper.validateEmptyvalues('CardYear', paymentMethod.SM_Credit_Card_expiration_year__c);
            this.CardType = SM_ChargentOrderHelper.validateEmptyvalues('CardType', paymentMethod.SM_Credit_Card_Franchise__c);
            this.CardNumber = SM_ChargentOrderHelper.validateEmptyvalues('CardNumber', paymentMethod.SM_Credit_Card_Number__c);
            this.PaymentMethod = SM_ChargentOrderHelper.validateEmptyvalues('PaymentMethod', paymentMethod.SM_Payment_Type__c);
            this.ChargeAmount = paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Charge_Amount__c;
            this.CardSecurity = SM_ChargentOrderHelper.validateEmptyvalues('CardSecurity', paymentMethod.SM_Credit_Card_CVV__c);
            this.BillingFirst = SM_ChargentOrderHelper.validateEmptyvalues('BillingFirst', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_First_Name__c);
            this.BillingLast = SM_ChargentOrderHelper.validateEmptyvalues('BillingLast', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_Last_Name__c);
            this.BillingAddress = SM_ChargentOrderHelper.validateEmptyvalues('BillingAddress', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_Address__c);
            this.BillingCity = SM_ChargentOrderHelper.validateEmptyvalues('BillingCity', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_City__c);
            this.BillingState = SM_ChargentOrderHelper.validateEmptyvalues('BillingState', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_State__c);
            this.BillingZip = SM_ChargentOrderHelper.validateEmptyvalues('BillingZip', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_Zip_Postal__c);
            this.BillingCountry = SM_ChargentOrderHelper.validateEmptyvalues('BillingCountry', paymentMethod.SM_Chargent_Order__r?.ChargentOrders__Billing_Country__c);
            this.RegisterTokenOnly = true;
        }
    }

    /**
    * @description
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 21/07/2021
    * @param fieldName
    * @param fieldvalue
    * @return String
    **/
    public static String validateEmptyvalues(String fieldName, String fieldvalue){

        if(String.isBlank(fieldvalue)){
            throw new TokenizedException('The field ' + fieldName +' cannot be empty');
        }
        return fieldvalue;
    }

    public class TokenizedException extends Exception {}//Custom exception to tokenization

    public class ResponseWrapper {
        @AuraEnabled
        public Boolean success {get;set;}
        @AuraEnabled
        public String message {get;set;}

        public ResponseWrapper(Boolean success, String message){
            this.success = success;
            this.message = message;
        }
    }
}