/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 05-24-2022
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   03-26-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
public without sharing class SM_ACHOrderHelper {

    //Instances of enums
    public static PaymentTypeEnum paymentType = new PaymentTypeEnum();
    public static PaymentStatusEnum paymentStatus = new PaymentStatusEnum();
    public static PaymentFrequencyEnum paymentFrequency = new PaymentFrequencyEnum();
    public static PaymentConditionEnum paymentCondition = new PaymentConditionEnum();
    public static PaymentMethodEnum paymentMethodEnum = new PaymentMethodEnum();
    public static ApprovalStatusEnum approvalStatus = new ApprovalStatusEnum();


    /** This class represents Enum to attribute Payment Type (Developer name) */
    public class PaymentTypeEnum {
        public final String SUBSCRIPTION = 'Subscription';
        public final String AC = 'AC';
        public final String FEE = 'Fee';
        public final String LATE_PAYMENT_TYPE = 'Late payment fee';
    }

    /** This class represents Enum to attribute Payment Status (Developer name) */
    public class PaymentStatusEnum {
        public final String COMPLETED = 'Completed';
        public final String CANCELED = 'Canceled';
        public final String INITIATED = 'Initiated';
        public final String STOPPED = 'Stopped';
        public final String PENDING = 'Pending';
        public final String CREATED = 'Created';
    }

    /** This class represents Enum to attribute Payment Frequency (Developer name) */
    public class PaymentFrequencyEnum {
        public final String ONCE = 'Once';
        public final String DAILY = 'Daily';
        public final String WEEKLY = 'Weekly';
        public final String BIWEEKLY = 'Biweekly';
        public final String MONTHLY = 'Monthly';
        public final String BIMONTHLY = 'Bimonthly';
        public final String QUARTERLY = 'Quarterly';
        public final String SEMIANNUAL = 'Semiannual';
        public final String ANNUAL = 'Annual';
        public final String BIENNIAL = 'Biennial';
    }

    /** This class represents Enum to attribute Payment Condition (Developer name) */
    public class PaymentConditionEnum {
        public final String FIXED_VALUE = 'Fixed value';
        public final String DYNAMIC = 'Dynamic';
    }

      /** This class represents Enum to attribute Payment Condition (Developer name) */
      public class PaymentMethodEnum {
        public final String ACH = 'ACH';
        public final String CREDIT_CARD = 'Credit Card';
    }

    /** This class represents Enum to attribute Approval Status (Developer name) */
    public class ApprovalStatusEnum {
        public final String ACCEPTED = 'Accepted';
        public final String PENDING_APPROVAL = 'Pending approval';
        public final String REJECTED = 'Rejected';
    }

    /**
    * @description return ACH Orders by dinamic SOQL
    * @author jpachon@legal-credit.com | 04-09-2021
    * @param query
    * @return Map<String, SM_ACH_Order__c>
    **/
    public static Map<String, SM_ACH_Order__c> getACHOrdersByIds(Set<String> achOrderIds){
        Map<String, SM_ACH_Order__c> achOrdersById;
        try{
            achOrdersById = new Map<String, SM_ACH_Order__c>([
                SELECT Id, SM_Payment_Condition__c, SM_Payment_End_Date__c, SM_Fee_to_collect__c, SM_Quantity_of_scheduled_fees__c, SM_Payment_Frequency__c, SM_Next_Transaction_Date__c, SM_Payment_Status__c,
                SM_Payment_Type__c, SM_Failed_AC_Transactions__c, SM_Failed_Transactions__c, SM_Contract__c, SM_Contract__r.Status,
                (SELECT Id, SM_Amount__c FROM Payments__r)
                FROM SM_ACH_Order__c
                WHERE ID IN :achOrderIds]);
        }catch(QueryException e){
            achOrdersById = new Map<String, SM_ACH_Order__c>();
        }
        return achOrdersById;
    }

       /**
    * @description return Contract by dinamic SOQL
    * @author cjimene@legal-credit.com | 29-06-2021
    * @param query
    * @return Map<String, Contract>
    **/
    public static Map<String, Contract> getContractByIds(Set<String> contractIds){
        Map<String, Contract> contractById;
        try{
            contractById = new Map<String, Contract>([
                SELECT Id, SM_Agreement_Status__c,SM_Payment_methods__c, Status,
                (SELECT Id, SM_Payment_Date__c FROM Payment_Data__r),
                (SELECT Id FROM ACH_Orders__r)
                FROM  Contract
                WHERE ID IN :contractIds]);
        }catch(QueryException e){
            contractById = new Map<String, Contract>();
        }
        return contractById;
    }
}