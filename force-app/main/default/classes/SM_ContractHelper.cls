/**
 * @description       : 
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 12/10/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                 Modification
 * 1.0   01-28-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
public without sharing class SM_ContractHelper {

    //Instances of enums
    public static StatusEnum status = new StatusEnum();
    public static WayOfContractEnum wayOfContract = new WayOfContractEnum();
    public static WayOfACPaymentEnum wayOfACPayment = new WayOfACPaymentEnum();
    public static ACFrequencyEnum acFrequency = new ACFrequencyEnum();
    public static ContractTypeEnum contractType = new ContractTypeEnum();
    public static CollectionMainEnum collectionMain = new CollectionMainEnum();
    public static CollectionActivationForm collectionActivationForm = new CollectionActivationForm();
    public static CollectionValidationOfConditions collectionValidationsConditions = new CollectionValidationOfConditions();
    public static AgreementStatusEnum AgreementStatusEnum = new AgreementStatusEnum();

    /** This class represents Enum to attribute status (Developer name) */
    public class StatusEnum {
        public String DRAFT = 'Draft';
        public String ACTIVATED = 'Activated';
        public String IN_APPROVAL_PROCESS = 'In Approval Process';
        public String SENT_FOR_SIGNATURE = 'Sent for signature';
        public String PAYMENT_PROCESS = 'Payment Process';
        public String PAYMENT_REJECTION = 'Payment Rejection';
        public String COMPLETE_INFORMATION = 'Complete information';
        public String DISCONTINUED = 'Discontinued';
        public String CANCELED = 'Cancelled';
        public String FINALIZED = 'Finalized';
    }

    /** This class represents Enum to attribute Way of Contract Payment (Developer name) */
    public class WayOfContractEnum {
        public String SUSCRIPTION = 'Subscription';
        public String FEES = 'Fees';
        public String NA = 'N/A';
    }
    
    /** This class represents Enum to attribute Way of AC Payment (Developer name) */
    public class WayOfACPaymentEnum {
        public String ONE_PAYMENT = 'One payment';
        public String FEES = 'Fees';
    }

    /** This class represents Enum to attribute Way of AC Payment (Developer name) */
    public class ACFrequencyEnum {
        public String DAILY = 'Daily';
        public String WEEKLY = 'Weekly';
        public String BIWEEKLY = 'Biweekly';
        public String MONTHLY = 'Monthly';
    }

    /** This class represents Enum to attribute Contract Type of Contract (Developer name) */
    public class ContractTypeEnum {
        public String DEPENDENT = 'Dependent';
        public String MASTER = 'Master';
        public String UNIQUE = 'Unique';
    }

    /** This class represents Enum to attribute Collection_Main_Contract__c of Contract (Developer name) */
    public class CollectionMainEnum {
        public String PENDING_DATA_CAPTURE = 'Pending data capture';
        public String READY_FOR_COLLECTION = 'Ready for collection';
    }

    /** This class represents Enum to attribute Contract_activation_form__c of Contract (Developer name) */
    public class CollectionActivationForm {
        public String FUTURE_ACTIVATION = 'Future activation with conditions';
        public String INMEDIATE_ACTIVATION = 'Immediate activation';
    }

    /** This class represents Enum to attribute Validation_of_conditions__c of Contract (Developer name) */
    public class CollectionValidationOfConditions {
        public String MEETS_THE_CONDITIONS = 'Meets the Conditions';
        public String WAITING_FOR_CONDITIONS = 'Waiting for conditions to be met';
    }

    /** This class represents Enum to attribute SM_Agreement_Status of Contract (Developer name) */
    public class AgreementStatusEnum {
        public String SIGNED = 'Signed';
        public String OUT_FOR_APPROVAL = 'Out for Approval';
        public String DRAFY = 'Draft';
        public String ACCEPTED = 'Accepted';
    }

    /**
    * @description This method return conga solution by contract id
    * @author jpachon@legal-credit.com | 02-02-2021
    * @param contractsById 
    * @return Map<Id, APXTConga4__Conga_Solution__c> 
    **/
    public static Map<Id, APXTConga4__Conga_Solution__c> getCongaSolutionSetupByContractId(Set<String> contractsById) {
        Map<Id, APXTConga4__Conga_Solution__c> congaSolutionByContractId = new Map<Id, APXTConga4__Conga_Solution__c>();
        for (Contract ct : [SELECT Id, SM_Process_automation_by_product_family__r.SM_Conga_Solution__r.APXTConga4__Button_body_field__c, SM_Process_automation_by_product_family__r.SM_Conga_Solution__r.APXTConga4__Composer_Parameters__c FROM Contract WHERE Id IN: contractsById]) {
            if(String.isNotBlank(ct.SM_Process_automation_by_product_family__r?.SM_Conga_Solution__c)) {
                congaSolutionByContractId.put(ct.Id, ct.SM_Process_automation_by_product_family__r.SM_Conga_Solution__r);
            }
        }
        return congaSolutionByContractId;
    }

    /**
    * @description this method creates the instance upon Contract
    * @author cjimenez@legal-credit.com | 31-01-2021 
    * @param agreemen
    **/
    public static Contract updateContract(String contractId){
        return new Contract(Id = contractId, Status = SM_ContractHelper.status.PAYMENT_PROCESS);
    }


    /**
    * @description This method return base url to Conga APi
    * @author jpachon@legal-credit.com | 10-02-2021
    * @return SM_ServiceInvokation
    **/
    public static SM_ServiceInvokation createRequestCongaAPI() {

        SM_ServiceInvokation requestSI = new SM_ServiceInvokation(false);
        SM_SetupWebService__mdt setup = [SELECT SM_EndPoint__c, SM_Method__c, SM_timeOut__c, SM_Integration__c 
                                            FROM SM_SetupWebService__mdt 
                                            WHERE DeveloperName = 'SM_Create_PDF_via_Conga_API' LIMIT 1];

        String sessionId = UserInfo.getSessionId();
        String serverUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/37.0/' + UserInfo.getOrganizationId();
        // String endPoint = setup.SM_EndPoint__c + '?sessionId=' + sessionId + '&serverUrl=' + EncodingUtil.urlEncode(serverUrl, 'UTF-8') + '&APIMODE=13';
        requestSI.endPoint = setup.SM_EndPoint__c + '?sessionId=' + sessionId + '&serverUrl=' + EncodingUtil.urlEncode(serverUrl, 'UTF-8') + '&APIMODE=13';

        // String method = setup.SM_Method__c;
        requestSI.method = setup.SM_Method__c;

        // Map<String, String> headers = null;
        // String request = '';
        requestSI.integrationName = setup.SM_Integration__c;

        // Integer timeout = Integer.valueOf(setup.SM_timeOut__c);
        requestSI.timeout = Integer.valueOf(setup.SM_timeOut__c);

        return requestSI;
    }

    /**
    * @description This method add additional params to url Conga API
    * @author jpachon@legal-credit.com | 10-02-2021
    * @return SM_ServiceInvokation
    **/
    public static void addAdditionalParamsToURLCongaAPI(SM_ServiceInvokation requestSI, Contract ct, String congaComposerParameters) {
        requestSI.endPoint += '&Id=' + ct.Id;
        requestSI.endPoint += '&ESMessage=' + EncodingUtil.urlEncode(System.label.SM_MESSAGE_AGREEMENT, 'UTF-8');
        // requestSI.endPoint += congaSolution.APXTConga4__Composer_Parameters__c.replaceAll('\r\n|\n|\r','')
        requestSI.endPoint += congaComposerParameters.replaceAll('\r\n|\n|\r','')
                        .replace('{!Contract.Id}',ct.Id)
                        .replace('{!Contract.Account}', EncodingUtil.urlEncode(ct.SM_Account_Name__c + ' - ' + ct.ContractNumber, 'UTF-8'))
                        .replace('{!Account.PersonEmail}', ct.SM_Email_to_send_contract__c);
        System.debug('requestSI: ' + requestSI);        
    }

    /**
    * @description This method get contract info required to conga api (see what fields are using in addAdditionalParamsToURLCongaAPI method)
    * @author jpachon@legal-credit.com | 10-02-2021
    * @param contractId
    * @return Contract
    **/
    public static Contract getRequiredInfoToCongaAPI(String contractId) {
        return [SELECT Id, SM_Account_Name__c, ContractNumber, SM_Email_to_send_contract__c FROM Contract WHERE Id =: contractId];
    }

    /**
    * @description This method get contracts by opportunity ids
    * @author jpachon@legal-credit.com | 02-13-2021
    * @param oppsId | Set<String>
    * @return contractsByOppId | Map<String, List<Contract>> 
    */
    public static Map<String, List<Contract>> getContractsByOppId(Set<String> oppIds) {
        System.debug('oppIds: ' + oppIds);
        Map<String, List<Contract>> contractsByOppId = new Map<String, List<Contract>>();
        for (Contract ct : [SELECT Id, Status, SM_Opportunity__c FROM Contract WHERE SM_Opportunity__c IN: oppIds]) {
            if (!contractsByOppId.containsKey(ct.SM_Opportunity__c)) {
                contractsByOppId.put(ct.SM_Opportunity__c, new List<Contract>());
            }
            contractsByOppId.get(ct.SM_Opportunity__c).add(ct);
        }
        System.debug('contractsByOppId: ' + JSON.serialize(contractsByOppId));
        return contractsByOppId;
    }

    /**
    * @description This method get contracts by ids with related chargent and ach orders
    * @author jpachon@legal-credit.com | 07-30-2021
    * @param contractIds | Set<String>
    * @return contractsById | Map<String,Contract>
    */
    public static Map<String,Contract> getContractWithOrders(Set<Id> contractIds) {
        Map<String,Contract> contractsById = new Map<String,Contract>([
            SELECT Id,
            (SELECT Id FROM ACH_Orders__r WHERE SM_Approval_Status__c =: SM_ACHOrderHelper.approvalStatus.PENDING_APPROVAL),
            (SELECT Id FROM Chargent_Orders__r WHERE SM_Approval_Status__c =: SM_ChargentOrderHelper.approvalStatus.PENDING_APPROVAL)
            FROM Contract
            WHERE Id IN :contractIds
        ]);
        return contractsById;
    }

    /**
    * @description This method get contracts by ids with related chargent and ach orders
    * @author jpachon@legal-credit.com | 07-30-2021
    * @param contractIds | Set<String>
    * @return contractsById | Map<String,Contract>
    */
    public static List<sObject> getContract(List<String>  sOIds){
        SM_Utils.DynamicQueryStructure structure = new SM_Utils.DynamicQueryStructure();
        structure.AdditionalFields = 'SM_Opportunity__r.SM_Company_Setting__c'
                                    +',SM_Payment_Method__r.SM_Chargent_Order__c'
                                    +',SM_Opportunity__r.SM_Company_Setting__r.SM_Gateway__c'
                                    +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c'
                                    +',SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,'
                                    +'SM_Process_automation_by_product_family__r.SM_Maximum_Number_Of_Failed_Transactions__c,';
        structure.sObjectName = 'Contract';
        structure.subqueryObj = 'Chargent_Orders__r';
        structure.whereClause = new map<String,List<object>>{'Id'=>(List<object>)sOIds};
        structure.childsWhereClause = new map<String,List<object>>{'SM_Payment_Type__c'=>new List<Object>{'Subscription','Fee'}};
        structure.orderByParent ='';
        List<sObject> objs  = SM_Utils.getDynamicQuery(structure);
        return objs;
    }

    /**
    * @description This method return map of dependent contracts to send to signature
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 12/10/2022 
    * @param masterContractIds 
    * @return Map<String, Contract> 
    **/
    public static Map<String, Contract> getDependetContractsToSignature(Set<Id> masterContractIds) {
 
        return new Map<String,Contract>([SELECT 
                                            ContractNumber, SM_Account_Name__c, SM_Email_to_send_contract__c
                                        FROM Contract
                                        WHERE Principal_Contract__c IN: masterContractIds
                                        AND Contract_activation_form__c =: SM_ContractHelper.collectionActivationForm.INMEDIATE_ACTIVATION
                                        AND Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION]);
    }

}