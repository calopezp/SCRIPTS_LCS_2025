/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   03-27-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
 * 1.2   09-07-2026   Juan Duarte / Carlos Lopez -> Ajustes por cancelacion de CHARGENT
 **/
public without sharing class SM_PaymentHelper {

    private static map<String, SObject> sobjectByPayment = new Map<String, SObject>();//To update data, when after context

    //Instances of enums
    public static StatusEnum status = new StatusEnum();
    public static ReceiptStatusEnum receiptStatus = new ReceiptStatusEnum();
    public static TokenizationStatusEnum tokenizationStatus = new TokenizationStatusEnum();

    //calp Aug 2026 :: CHARGENT app is permanently disabled for this org; runtime FLS checks
    //don't reflect managed package license revocation, so this is hard-disabled instead.
    private static Boolean hasChargentObjectAccess() {
        return false;
    }

    /** This class represents Enum to attribute Status (Developer name) */
    public class StatusEnum {
        public final String ACH_PENDING = 'ACH PENDING';
        public final String ACH_TRANSMITTED = 'ACH TRANSMITTED';
        public final String REJECTED = 'REJECTED';
        public final String ACCEPTED = 'ACCEPTED';
    }

    public class ReceiptStatusEnum {
        public final String PENDING_TO_SEND = 'Pending to Send';
        public final String SENT = 'Sent';
        public final String UPLOADED_TO_S3 = 'Uploaded to S3';
    }

    public class TokenizationStatusEnum {
        public final String ERROR = 'Error';
        public final String PENDING = 'Pending';
        public final String TOKENIZED = 'Tokenized';
    }

    /**
    * @description This method send payment receipt
    * @author jpachon@legal-credit.com | 05-08-2021
    * @param recordsToProcess (List<EmailWrapper>)
    **/
    @Future(callout=true)
    public static void sendPaymentReceipts(String recordsToProcessJSON) {
        List<EmailWrapper> recordsToProcess = (List<EmailWrapper>)JSON.deserialize(recordsToProcessJSON, List<EmailWrapper>.class);
        Blob pdfBlob;
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        Messaging.SingleEmailMessage message;
        for (EmailWrapper record : recordsToProcess) {
            if(record.hasAttachment) pdfBlob = SM_PaymentHelper.getBlobFromPDF(record.sObjectId, record.sourceObject);
            if (pdfBlob == null) continue;
            record.documentBlob = pdfBlob;
            message = SM_PaymentHelper.buildSingleMessage(record);
            messages.add(message);
        }
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
        System.debug('results: ' + results);
        // SM_PaymentHelper.processRecordsAfterSendEmails('uploadDocument', null, recordsToProcess);
        System.debug('Ready to execute queueable - SM_SendPaymentNotificationQueueable - uploadDocument');
        System.enqueueJob(new SM_SendPaymentNotificationQueueable('uploadDocument', null, recordsToProcess));
    }

    /**
    * @description This method create Blob from VF
    * @author jpachon@legal-credit.com | 05-08-2021
    * @param sObjectId (String)
    * @param sourceObject (String)
    **/
    public static Blob getBlobFromPDF(String sObjectId, String sourceObject) {
        String pageName = '';
        switch on sourceObject {
            when  'Contract'{
                pageName = 'SM_PaymentReceiptPDF';
            }
            when else {
                System.debug('Option not implemented');
            }
        }
        if (String.isNotBlank(pageName)) {
            Pagereference pr = new Pagereference('/apex/' + pageName);
            pr.getParameters().put('id', sObjectId);
            if(!Test.isRunningTest()) {
                return pr.getContentAsPdf();
            } else {
                return Blob.valueOf('Unit test');
            }
        }
        return null;
    }

    /**
    * @description This method create single message object
    * @author jpachon@legal-credit.com | 05-08-2021
    * @param record (EmailWrapper)
    **/
    public static Messaging.SingleEmailMessage buildSingleMessage(SM_PaymentHelper.EmailWrapper record) {
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.toaddresses = new String[]{record.toAddress};
        message.setSubject(record.subject);
        message.setPlainTextBody(record.body);
        message.setHtmlBody(record.body);
        message.setSaveAsActivity(true);
        message.setWhatId(record.sourceObjectId);
        if(record.hasAttachment) setEmailAttachment(message, record);
        return message;
    }

    /**
    * @description This method set email attachment to an email message
    * @author jpachon@legal-credit.com | 05-08-2021
    * @param record (EmailWrapper)
    **/
    public static void setEmailAttachment(Messaging.SingleEmailMessage message, SM_PaymentHelper.EmailWrapper record) {
        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName(record.documentName);
        efa.setBody(record.documentBlob);
        efa.setContentType('application/pdf');
        message.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
    }

    @Future(callout=true)
    public static void processRecordsAfterSendEmails(String wrapperJSON) {
        System.debug('Executing SM_PaymentHelper.processRecordsAfterSendEmails');
        List<EmailWrapper> records = (List<EmailWrapper>)JSON.deserialize(wrapperJSON, List<EmailWrapper>.class);
        SM_CloudDocumentPath cloudDocumentPath = new SM_CloudDocumentPath();
        List<SM_Cloud_Document__c> lstCloudDocumentInser = new List<SM_Cloud_Document__c>();
        for (EmailWrapper record : records) {
            System.debug('record: ' + record);
            SM_Cloud_Document__c cloudDocument = SM_PaymentHelper.createCloudDocument(cloudDocumentPath, record);
            if(cloudDocument != null) lstCloudDocumentInser.add(cloudDocument);
        }
        List<Database.SaveResult> sr;
        System.debug('lstCloudDocumentInser: ' + lstCloudDocumentInser);
        System.debug('lstCloudDocumentInser: ' + lstCloudDocumentInser.size());
        if(!lstCloudDocumentInser.isEmpty()){
            sr = Database.insert(lstCloudDocumentInser);
            System.debug('lstCloudDocumentInser - sr: ' + sr);
        }
    }

    public static SM_Cloud_Document__c createCloudDocument(SM_CloudDocumentPath cloudDocumentPath, EmailWrapper record) {
        String pathS3 = '';
        pathS3 = cloudDocumentPath.generatePath(record.documentType, record.documentName, record.sObjectId, record.abbreviatedCompany);
        pathS3 = cloudDocumentPath.bucket.bucketName+'/'+pathS3;
        pathS3 = pathS3.deleteWhitespace();
        SM_RequestS3Helper helper = new SM_RequestS3Helper();
        HTTPResponse response = helper.uploadFilesToS3(new Attachment(Body = record.documentBlob, Name = record.documentName), '', pathS3, cloudDocumentPath.bucket);
        if(response != null && response.getStatus() == 'OK' && response.getStatusCode() == 200){
            return SM_AttachmentHelper.createCloudDocument(pathS3.substring(pathS3.lastIndexOf('/') + 1), record.sourceObjectId, record.documentType, pathS3, record.abbreviatedCompany);
        }
        return null;
    }

     /**
    * @description 
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 23/06/2021 
    * @param achOrders 
    **/
    @AuraEnabled
    public static SM_Payment__c createPayment(String achOrderId){
        try {
            SM_ACH_Order__c achOrder = [SELECT Id, SM_Payment_Type__c, SM_Charge_Date__c, SM_Payment_Method__c, SM_Next_Transaction_Date__c, SM_Total__c, SM_Fee_to_collect__c, SM_Failed_payment__c,
                SM_Contract__c, SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c, SM_Contract__r.SM_Payment_Method__c, SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c,
                SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c, SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_State_Amount__c,
                SM_Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_IVU_Municipal_Amount__c, SM_Penalty_value__c, SM_Apply_penalty__c,
                SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c,
                SM_Contract__r.SM_Customer_Cancellation__c
                FROM SM_ACH_Order__c
                WHERE Id = :achOrderId LIMIT 1];

                if (achOrder.SM_Contract__r.SM_Customer_Cancellation__c) {
                    throw new AuraHandledException('No se puede generar el payment: el contrato está en proceso de Customer Cancellation.');
                }

                List<SM_Payment__c> result = createPayments(new List<SM_ACH_Order__c>{achOrder});
                if(!result.isEmpty()){
                    return result[0];
                }
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        return null;
    }
    
    /**
    * @description 
    * @author Diego Jacanamijoy -> diego.jacanamijoy@gmail.es | 23/06/2021 
    * @param achOrders 
    **/
    public static List<SM_Payment__c> createPayments(List<SM_ACH_Order__c> achOrders){
        List<SM_Payment__c> payments = new List<SM_Payment__c>(); 
        for (SM_ACH_Order__c achOrder : achOrders) {
            System.debug('achOrder: ' + achOrder);
            payments.add(new SM_Payment__c(
                RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH'),
                SM_Recurring__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? true : false,
                SM_Type__c = achOrder.SM_Payment_Type__c != SM_ACHOrderHelper.paymentType.SUBSCRIPTION ? achOrder.SM_Payment_Type__c : 'Fee',
                SM_Payment_Method__c = achOrder.SM_Contract__r.SM_Payment_Method__c,
                SM_Contract__c = achOrder.SM_Contract__c,
                SM_Payment_Date__c = achOrder.SM_Next_Transaction_Date__c,
                Payment_Status__c = SM_PaymentHelper.status.ACH_PENDING,
                SM_ACH_Account_Number__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_ACH_Account_Number__c == null ? 0 : Decimal.valueOf(achOrder.SM_Contract__r.SM_Payment_Method__r.SM_ACH_Account_Number__c),
                SM_ACH_Account_Routing_Number__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_Routing_Number__c == null ? '' : achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number__c,
                SM_Routing_Number_Check_Digit__c = achOrder?.SM_Contract__r?.SM_Payment_Method__r?.SM_Routing_Number_Check_Digit__c == null ? null : Integer.valueOf(achOrder.SM_Contract__r.SM_Payment_Method__r.SM_Routing_Number_Check_Digit__c),
                SM_Fee_to_collect__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION || achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.FEE ? achOrder.SM_Fee_to_collect__c : null,
                SM_ACH_Order__c = achOrder.Id,
                SM_Amount__c = achOrder.SM_Total__c,
                //SMMCI-45 CJ 16-09-2022
                SM_P_IVU_State_Amount__c = achOrder.SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUStateAmount__c,
                SM_P_IVU_Municipal_Amount__c = achOrder.SM_Contract__r.SM_Process_automation_by_product_family__r.SM_IVUMunicipalAmount__c,
                SM_Penalty_value__c = achOrder.SM_Apply_penalty__c && achOrder.SM_Penalty_value__c > 0 ? achOrder.SM_Penalty_value__c : 0,
                SM_Fee_value__c = achOrder.SM_Apply_penalty__c ? achOrder.SM_Total__c - achOrder.SM_Penalty_value__c : achOrder.SM_Total__c,
                SM_Failed_payment__c = achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE ? achOrder.SM_Failed_payment__c : null,
                //SMPII-9 CJ 12-10-2021
                SM_Original_Type__c = achOrder.SM_Payment_Type__c <> 'Late payment fee' ? achOrder.SM_Payment_Type__c : null
            ));
        }

        if(!payments.isEmpty()){
            insert payments;
        }
        return payments;
    }

    /**
    * @description This method set field SM_Fee_to_collect__c in ACh order or Chergent records of type Late payment fee
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 22/08/2022 
    * @param sObjects 
    **/
    public static void setFeeToCollectFromFailetPayment(SObject[] sObjects) {

        if (!hasChargentObjectAccess()) {
            return;
        }

        Set<String> failedPaymentIds = new Set<String>();
        Set<String> chargenIds = new Set<String>();

        /** Iterate and validate new records */
        for (SObject so : sObjects) {
            
            String paymentType = (String)so.get('SM_Payment_Type__c');
            String failedPayment = (String)so.get('SM_Failed_Payment__c');

            /** Validate payment type and related payment failed */
            if (String.isNotBlank(paymentType) && paymentType == SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE && failedPayment <> null) {
                
                /** Payment ids to query */
                failedPaymentIds.add(failedPayment);

                if (Trigger.isExecuting && Trigger.isAfter) {
                    /** Chargent ids to future method */
                    chargenIds.add((String)so.get('Id'));   
                }

                /** Map for related later the Installment_number__c field */
                sobjectByPayment.put(failedPayment, so);
            }
        }

        if (!Trigger.isExecuting || Trigger.isBefore) {
            
            for (SM_Payment__c payment : [SELECT Installment_number__c FROM SM_Payment__c WHERE Id IN: failedPaymentIds]) {
            
                sobjectByPayment.get(payment.Id).put('SM_Fee_to_collect__c', payment.Installment_number__c);
            }
        } else if(!System.isBatch()){

            /** Only update data when is after */
            updateFeeToCollect(chargenIds);
        }
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 26/08/2022 
    **/
    @future
    public static void updateFeeToCollect(Set<String> chargenIds) {

        //Juan Duarte Jul 2026 :: Ajuste de Chargent
        if (!hasChargentObjectAccess()) {
            return;
        }

        List<ChargentOrders__ChargentOrder__c> chargentstoUpdate = new List<ChargentOrders__ChargentOrder__c>();

        for (ChargentOrders__ChargentOrder__c chargent : [SELECT SM_Failed_Payment__r.Installment_number__c FROM ChargentOrders__ChargentOrder__c WHERE Id IN: chargenIds]) {
            
            chargent.SM_Fee_to_collect__c = chargent.SM_Failed_Payment__r.Installment_number__c;
            chargentstoUpdate.add(chargent);
        }

        if (!chargentstoUpdate.isEmpty()) {
            update chargentstoUpdate;
        }
    }

    /**
    * @description This method get PaymentWrapper records
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    * @param paymentIds 
    * @return List<PaymentWrapper> 
    **/
    public static List<PaymentWrapper> getPaymentWrappers(Set<Id> paymentIds){

        /** Instance of PaymentWrapper */
        List<PaymentWrapper> paymenWrappers = new List<PaymentWrapper>();

        List<SM_Payment__c> payments = [SELECT 
                                        SM_P_IVU_State_Amount__c, SM_P_IVU_Municipal_Amount__c, SM_Type__c, SM_Failed_payment__c, Payment_Status__c, Installment_number__c, SM_Payment_Method__c
                                        , SM_Payment_Date__c, SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.SM_Email_to_send_contract__c, SM_Amount__c, SM_Penalty_value__c, SM_Fee_value__c
                                        , SM_Contract__r.SM_AC_collected__c, SM_Contract__r.SM_Payment_Received__c, SM_Contract__r.SM_AC_Split_Date__c
                                        , SM_ACH_Order__r.SM_Fee_to_collect__c, SM_ACH_Order__r.SM_User_who_applies_the_penalty__c, SM_ACH_Order__r.SM_Apply_penalty__c, SM_ACH_Order__r.SM_Penalty_date__c
                                        , SM_ACH_Order__r.SM_Approval_status__c, SM_ACH_Order__r.SM_Reason_to_approve_exoneration__c, SM_ACH_Order__r.SM_Payment_Start_Date__c, SM_ACH_Order__r.SM_Payment_Type__c
                                    FROM SM_Payment__c 
                                    WHERE Id IN :paymentIds];

        for (SM_Payment__c payment : payments) {
            SObject relatedObj = payment.SM_ACH_Order__r != null
                ? (SObject)payment.SM_ACH_Order__r
                : (SObject)new SM_ACH_Order__c();

            paymenWrappers.add(new PaymentWrapper(payment, relatedObj));
        }

        return paymenWrappers;
    }

    /** Wrapper Payment with ACH order or Chargent */
    public class PaymentWrapper {

        public SM_Payment__c payment;
        public SObject achOrChargentObj;//Instance of ACH order or Chargent

        public PaymentWrapper(SM_Payment__c payment, SObject achOrChargentObj){

            this.payment = payment;
            this.achOrChargentObj = achOrChargentObj;
        }
    }


    public class EmailWrapper {
        public String toAddress {get;set;}
        public String subject {get;set;}
        public String body {get;set;}
        public String documentType {get;set;}
        public String documentName {get;set;}
        public String sObjectId {get;set;}
        public String sourceObject {get;set;}
        public String sourceObjectId {get;set;}
        public Boolean hasAttachment {get;set;}
        public String abbreviatedCompany {get;set;}
        public Blob documentBlob {get;set;}

        public EmailWrapper(String toAddress, String subject, String body, String documentType, String documentName, String sObjectId, String sourceObject, String sourceObjectId, Boolean hasAttachment, String abbreviatedCompany){
            this.toAddress = toAddress;
            this.subject = subject;
            this.body = body;
            this.documentType = documentType;
            this.documentName = documentName;
            this.sObjectId = sObjectId;
            this.sourceObject = sourceObject;
            this.sourceObjectId = sourceObjectId;
            this.hasAttachment = hasAttachment;
            this.abbreviatedCompany = abbreviatedCompany;
        }
    }
}