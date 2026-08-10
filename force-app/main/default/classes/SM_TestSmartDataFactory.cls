/**
 * @description       : This class, build necesary data to test class
 * @author            : jpachon.ariza@legal-credit.com
 * @group             :
 * @last modified on  : 06-10-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                     Modification
 * 1.0   11-11-2020   jpachon.ariza@legal-credit.com   Initial Version
 * 1.1   18-01-2021   cjimenez@legal-credit.com   Initial Version
**/
public with sharing class SM_TestSmartDataFactory {

    /** The objects only created with basic fields and don´t insert in this class */

    /** Instances of objects */
    public static SM_Company_setting__c companySettingObj;
    public static SM_Company_setting__c companySettingObjGateWay;
    public static Lead leadObj;
    public static User userObj;
    public static Profile profileObj = [SELECT Id FROM Profile WHERE Name='Standard User'];
    public static Account personAccountObj;
    public static Opportunity opportunityObj;
    public static OpportunityLineItem opportunityLineItemObj;
    public static Five9LSP__Five9_List__c five9List;
    public static SM_Setup_calls_distribute__c setupCallDistributeObj;
    public static Five9LSP__Five9_LSP_Settings__c f9Settigs;
    public static SM_Dispute__c disputeObj;
    public static SM_SetupToken__c setupTokenObj;
    public static echosign_dev1__SIGN_Agreement__c agreementObj;
    public static Attachment attachmentObj;
    public static Contract contractObj;
    public static Process_automation_by_product_family__c processautomationProductfamilyObj;
    public static APXTConga4__Conga_Solution__c conga4CongaSolutionObj;
    public static Product2 productObj;
    public static Process_automation_by_product_family__c processAutomationObj;
    public static Id pricebookId;
    public static PricebookEntry pricebookEntryObj;
    public static SM_Payment_Method__c PaymentMethodObj;
    public static ChargentOrders__ChargentOrder__c ChargentOrdersObj;
    public static ChargentBase__Gateway__c gatewayObj;
    public static SM_GatewayErrors__c gatewayErrorObj;
    public static SM_GatewayErrors__c gatewayErrorObj101;
    public static List<SM_Required_Field_Info__c>  reqFields;
    public static Asset assetObj;
    public static SM_Simultaneous_Contract_Updates__c simultaneousContractObj;

    /** Get SM_Company_setting__c record */
    public static SM_Company_setting__c getCompanySetting(){
        if(companySettingObj == null){
            companySettingObj = new SM_Company_setting__c(
                SM_Fields_to_validate_duplicates__c = 'Email; Phone;',
                SM_Fields_to_validate_duplicates2__c = 'Phone',
                SM_Required_fields__c = 'Email; Phone',
                SM_Destination_Bussines_Unit__c = 'Legal credit solutions'

            );
        }
        return companySettingObj;
    }

    /** Get SM_Company_setting__c record */
    public static SM_Company_setting__c getCompanySettingPMethod(String gtId){
        if(companySettingObjGateWay == null){
            companySettingObjGateWay = new SM_Company_setting__c(
                SM_Fields_to_validate_duplicates__c = 'Email; Phone;',
                SM_Fields_to_validate_duplicates2__c = 'Phone',
                SM_Required_fields__c = 'Email; Phone',
                SM_Destination_Bussines_Unit__c = 'Legal credit solutions',
                SM_Gateway__c = gtId
            );
        }
        return companySettingObjGateWay;
    }

    /** Get Lead record */
    public static Lead getLead(){
        if(leadObj == null){
            leadObj = new Lead(
                FirstName = 'Test FirstName',
                LastName = 'Test LastName',
                SM_Destination_business_unit__c = 'Legal credit solutions',
                Status = SM_LeadHelper.leadStatusEnum.NEW_STATUS
            );
        }
        return leadObj;
    }

    /** Get User record */
    public static User getUser(){
        if(userObj == null){
            userObj = new User(
                Username = 'Test_@moneeUserName.com', LastName = 'Test LastName', Email = 'test_Email@monee.com', Alias = 'Alias',
                EmailEncodingKey='UTF-8',  LanguageLocaleKey='en_US', LocaleSidKey='en_US', TimeZoneSidKey='America/Los_Angeles', ProfileId = profileObj.Id
            );
        }
        return userObj;
    }

    /** Get person account record */
    public static Account getPersonAccount() {
        if (personAccountObj == null) {
            personAccountObj = new Account(
                //TO DO Create the personAccount recordtype
                //RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Account', SM_AccountHelper.recordType.personAccount),
                FirstName = 'FirstName PA',
                LastName = 'LastName PA'
            );
        }
        return personAccountObj;
    }

    /** Get opportunity record */
    public static Opportunity getOpportunity() {
        opportunityObj = new Opportunity(
            Name = 'Opp Name',
            CloseDate = System.today().addDays(30),
            StageName = SM_OpportunityHelper.stageName.newSage,
            Pricebook2Id = getPricebookId()
        );
        return opportunityObj;
    }

    /** Get OpportunityLineItem */
    public static OpportunityLineItem getOpportunityLineItem() {
        if (opportunityLineItemObj == null) {
            opportunityLineItemObj = new OpportunityLineItem(
                Product2Id = getProduct2().Id,
                PricebookEntryId = getPricebookEntry().id,
                Quantity = 10
            );
        }
        return opportunityLineItemObj;
    }

    /** get product2 */
    public static Product2 getProduct2() {
        if (productObj == null) {
            productObj = new Product2(
                Name = 'Laptop X200',
                Family = 'Hardware',
                Process_automation_by_product_family__c = getProccessAutomation().Id,
                SM_Requires_AC__c = true,
                SM_AC_value__c = 20000,
                SM_Way_to_pay__c = 'Subscription'
            );
            insert productObj;
        }
        return productObj;
    }

    /** get product2 */
    public static Product2 getProduct2ByRecordTypeName(String recordTypeName) {
        Product2 p2 = new Product2(
            Name = 'Laptop X200',
            Family = 'Hardware',
            Process_automation_by_product_family__c = getProccessAutomation().Id,
            SM_Requires_AC__c = true,
            SM_AC_value__c = 20000,
            SM_Way_to_pay__c = 'Subscription',
            recordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('Product2', recordTypeName)
        );
        insert p2;
        return p2;
    }

    /** get product2NoInsert */
    public static Product2 getproduct2NoInsert() {
        if (productObj == null) {
            productObj = new Product2(
                Name = 'Laptop X200',
                Family = 'Hardware',
                Process_automation_by_product_family__c = getProccessAutomation().Id,
                SM_Requires_AC__c = true,
                SM_AC_value__c = 20000
            );
        }
        return productObj;
    }

    /** Get pricebookId */
    public static Id getPricebookId() {
        if (pricebookId == null) {
            pricebookId = Test.getStandardPricebookId();
        }
        return pricebookId;
    }

    /** Get PricebookEntry */
    public static PricebookEntry getPricebookEntry() {
        if(pricebookEntryObj == null) {
            pricebookEntryObj = new PricebookEntry(
                Pricebook2Id = getPricebookId(),
                product2Id = getProduct2().Id,
                isActive = true,
                UnitPrice = 1000
            );
            insert pricebookEntryObj;
        }
        return pricebookEntryObj;
    }

    /** Get ProccessAutomation */
    public static Process_automation_by_product_family__c getProccessAutomation() {
        if(processAutomationObj == null) {
            processAutomationObj = new Process_automation_by_product_family__c(
                Name = 'Test proccess',
                SM_Generates_dispute__c = true,
                SM_Type_of_contract__c = 'Credit Rectification'
            );
        }
        return processAutomationObj;
    }

    /** Get five9 list record */
    public static Five9LSP__Five9_List__c getFive9List(String five9ListName, String controllingObjectName) {
        five9List = new Five9LSP__Five9_List__c(
            Name = five9ListName,
            Five9LSP__Controlling_Object__c = controllingObjectName,
            Five9LSP__Five9_Domain__c = 'Domain',
            Five9LSP__Five9_User_Name__c = 'UserName',
            Five9LSP__Five9_User_Password__c = '****',
            Five9LSP__API_URL__c = 'url'
        );
        return five9List;
    }

    /** Get setup calls distribute record to Five9 List */
    public static SM_Setup_calls_distribute__c getSetupCallDistribute(String recordTypeName, String companySettingId, String five9ListId, String objectName, String stageOrStatus, String disposition) {
        setupCallDistributeObj = new SM_Setup_calls_distribute__c(
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Setup_calls_distribute__c', recordTypeName),
            SM_Active__c = true,
            SM_Administration_Company__c = companySettingId,
            SM_Object__c = objectName,
            SM_Stage_or_Status__c = stageOrStatus,
            SM_Disposition__c = disposition
        );
        if (recordTypeName.equalsIgnoreCase('Five9 List')) {
            setupCallDistributeObj.SM_Five9_List__c = five9ListId;
        } else if (recordTypeName.equalsIgnoreCase('Reminder')) {
        }
        return setupCallDistributeObj;
    }

    /** Get setup calls distribute record to Reminder task*/
    public static SM_Setup_calls_distribute__c getReminderSetupCallDistribute(String companySettingId, String objectName, String stageOrStatus, String disposition, Integer quantityOfDailyReminders) {
        setupCallDistributeObj = new SM_Setup_calls_distribute__c(
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Setup_calls_distribute__c', SM_SetupCallsDistributeHelper.recordType.reminder),
            SM_Active__c = true,
            SM_Administration_Company__c = companySettingId,
            SM_Object__c = objectName,
            SM_Stage_or_Status__c = stageOrStatus,
            SM_Disposition__c = disposition,
            SM_Recurrence_Type__c = 'RecursDaily',
            SM_Quantity_Daily_Reminders__c = quantityOfDailyReminders,
            SM_Reminder_Hour__c = Time.newInstance(12, 0, 0, 0)
        );
        return setupCallDistributeObj;
    }

    // Get five9 LSP (Custom Settings) requiered to test five9 without using SeeAllData = true
    public static Five9LSP__Five9_LSP_Settings__c getFive9Settings() {
        f9Settigs = new Five9LSP__Five9_LSP_Settings__c(
            Name = 'LSPDEFAULT',
            Five9LSP__Statuses_to_retry__c = '\'pending\', \'715\', \'-1\', \'717\', \'-3\'',
            Five9LSP__API_Ongoing_Batch_Size__c = 1
        );
        return f9Settigs;
    }

    public static echosign_dev1__SIGN_Agreement__c getAgreement() {
        agreementObj = new echosign_dev1__SIGN_Agreement__c(
			Name = 'Insert Adobe Sign Agreement prueba',
			echosign_dev1__Message__c = 'Adobe Sign Agreement prueba',
			echosign_dev1__More_Recipients__c = 'daeshuro@gmail.com,',
			echosign_dev1__Recipient_Addresses__c = 'daeshuro@gmail.com,',
			echosign_dev1__RemindRecipient__c = 'Never',
			echosign_dev1__Status__c = 'Draft',
			echosign_dev1__SignatureOrder__c='Recipient signs, then I sign',
			echosign_dev1__SignatureType__c='e-Signature'
        );
        return agreementObj;
    }

    public static Attachment getAttachment(String agreementId){
        attachmentObj = new Attachment(
            Body = Blob.valueOf('Prueba'),
			Name= 'Prueba',
            ParentId = agreementId

        );
        return attachmentObj;
    }

    public static Contract getContract(String accountId,String idProcessautomation){
        contractObj = new Contract(
            AccountId = accountId,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            SM_Process_automation_by_product_family__c=idProcessautomation
        );
        return contractObj;
    }

    public static APXTConga4__Conga_Solution__c getConga4CongaSolutionObj(){
        conga4CongaSolutionObj = new APXTConga4__Conga_Solution__c(
        Name='LCS Contract Savera eSign',
        APXTConga4__Button_body_field__c = '/apex/APXTConga4__Conga_Composer?SolMgr=1&serverUrl={!API.Partner_Server_URL_370}&Id={!Contract.Id}&QueryId=[GetRI]0Q_000UAG465811%3Fpv0%3D{!Contract.Id}&TemplateId=0T_000UAG839466,0T_001UAG083429,0T_008UAG043625,0T_003UAG898589,0T_009UAG758560,0T_010UAG957337,0T_006UAG399870,0T_007UAG357023&DefaultPDF=1&ESVisible=1&ESSignatureType=2&ESRecipient1={!Account.PersonEmail}&OFN={!Contract.Account}',
        APXTConga4__Button_Link_API_Name__c = 'Conga_Composer_LCS_Contract_Savera_eSign',
        APXTConga4__Composer_Parameters__c = '&QueryId=[GetRI]0Q_000UAG465811%3Fpv0%3D{!Contract.Id}&TemplateId=0T_000UAG839466,0T_001UAG083429,0T_008UAG043625,0T_003UAG898589,0T_009UAG758560,0T_010UAG957337,0T_006UAG399870,0T_007UAG357023&DefaultPDF=1&ESVisible=1&ESSignatureType=2&ESRecipient1={!Account.PersonEmail}&OFN={!Contract.Account}',
        APXTConga4__Master_Object_Type__c='Contract',
        APXTConga4__Sample_Record_Name__c='00000101',
        APXTConga4__Sample_Record_Id__c='8001D000000Z7LAQA0'

    );
    return conga4CongaSolutionObj;
 }


    public static Process_automation_by_product_family__c getProcessautomationProductfamily(String idCompanySetting,String conga4CongaSolution){
            processautomationProductfamilyObj = new Process_automation_by_product_family__c(
            Company_setting__c = idCompanySetting,
            SM_Generates_dispute__c = true,
            SM_Maximum_Number_Of_Failed_Transactions__c = 2,
            SM_Type_of_contract__c='Legal Credit Solution',
            SM_Conga_Solution__c=conga4CongaSolution
        );
        return processautomationProductfamilyObj;
    }


      /** Get SM_Dispute__c record */
      public static SM_Dispute__c getDispute(){
        if(disputeObj == null){
            disputeObj = new SM_Dispute__c(
                SM_Status__c = 'New Case',
                SM_Init_Date__c = System.today(),
                SM_Next_Due_Date__c = System.today().addDays(30),
                SM_Assigned_Agent__c = 'Prueba'
            );
        }
        return disputeObj;
    }


      /** Get SM_SetupToken__c record */
      public static SM_SetupToken__c getSetupToken(){
        if(setupTokenObj == null){
            setupTokenObj = new SM_SetupToken__c(
                Name  = 'Token Native',
                SM_DurationMinutes__c = 30,
                SM_ExpirationDate__c =System.now().addHours(5),
                SM_ServiceName__c = 'SM_TokenNative',
                SM_Token__c=''
            );
        }
        return setupTokenObj;
    }


    /** Get SM_Payment_Method__c record */
    public static SM_Payment_Method__c getPaymentMethod(String AccountId, ChargentOrders__ChargentOrder__c chargentOrder){
        if(PaymentMethodObj == null){
            PaymentMethodObj = new SM_Payment_Method__c(
                SM_Account__c = AccountId,
                SM_Chargent_Order__c = chargentOrder.Id,
                SM_Credit_Card_expiration_year__c = chargentOrder.ChargentOrders__Card_Year_Indicator__c,
                SM_Credit_Card_expiration_month__c = chargentOrder.ChargentOrders__Card_Month_Indicator__c,
                SM_Credit_Card_Number__c = '**** **** **** '+chargentOrder.ChargentOrders__Card_Last_4__c,
                SM_Credit_Card_Franchise__c = chargentOrder.ChargentOrders__Card_Type__c,
                SM_Credit_Card_Name__c = chargentOrder.ChargentOrders__Credit_Card_Name__c,
                SM_Card_Token__c = chargentOrder.ChargentOrders__Tokenization__c
            );
        }
        return PaymentMethodObj;
    }

    /** Get ChargentOrders__ChargentOrder__c record */
    public static ChargentOrders__ChargentOrder__c getChargentorder(String AccountId, Contract ctr,  SM_Company_setting__c setting, String type){
        if(ChargentOrdersObj == null){
            ChargentOrdersObj = new ChargentOrders__ChargentOrder__c(
                ChargentOrders__Payment_Frequency__c = 'Once',
                ChargentOrders__Gateway__c = setting.SM_Gateway__c,
                ChargentOrders__Payment_Method__c = 'Credit Card',
                ChargentOrders__Payment_Start_Date__c = ctr.SM_AC_start_date__c,
                ChargentOrders__Tokenization__c = '1929826725-1841993424',
                SM_Payment_Type__c = type
            );
        }
        return ChargentOrdersObj;
    }
    /** Get ChargentOrders__ChargentOrder__c record */
    public static ChargentBase__Gateway__c getGateway(){
        if(gatewayObj == null){
            gatewayObj = new ChargentBase__Gateway__c(
                ChargentBase__Active__c	 = true,
                ChargentBase__Available_Card_Types__c = 'Visa;Mastercard;Discover;American Express',
                ChargentBase__Available_Currencies__c = 'United States dollar',
                ChargentBase__Available_Payment_Methods__c = 'Credit Card;eCheck',
                ChargentBase__Credit_Card_Data_Handling__c = 'Clear When Token Present',
                Name ='Authorize.net Test'
            );
        }
        return gatewayObj;
    }

    /**Get  SM_GatewayErrors__c record*/
    public static SM_GatewayErrors__c getGatewayError100(Id idGateway){
        if(gatewayErrorObj == null){
            gatewayErrorObj = new SM_GatewayErrors__c(
                Name    =   '100',
                SM_CodeError__c     = '100',
                SM_ErrorDescription__c  =   'Transaction was successful.',
                SM_Gateway__c   =   idGateway
            );
        }
        return gatewayErrorObj;
    }

    public static SM_GatewayErrors__c getGatewayError101(Id idGateway){
        if(gatewayErrorObj101 == null){
            gatewayErrorObj101 = new SM_GatewayErrors__c(
                Name    =   '101',
                SM_CodeError__c     = '101',
                SM_ErrorDescription__c  =   'Request is missing one or more required fields.',
                SM_Gateway__c   =   idGateway
            );
        }
        return gatewayErrorObj101;
    }

     /** Get ChargentOrders__ChargentOrder__c record */
     public static List<SM_Required_Field_Info__c> getRequiredFields(String companySettingId){
        if(reqFields == null){
            reqFields = new List<SM_Required_Field_Info__c>();
            SM_Required_Field_Info__c reqField = new SM_Required_Field_Info__c(
                SM_Company_Setting__c	 = companySettingId,
                SM_Api_Field_Name__c = 'SM_Start_date__c',
                Name = 'Subscription - SM Start date',
                SM_Process__c = 'AC - Full Payment',
                SM_Source_Object__c = 'Contract'
            );
            reqFields.add(reqField);
            SM_Required_Field_Info__c reqField2 =reqField.clone();
            reqField2.SM_Api_Field_Name__c = 'SM_Frecuency__c';
            reqField2.SM_Process__c = 'Subscription';
            reqFields.add(reqField2);
        }
        return reqFields;
    }
    public static SM_Conversion_Fields_Mapping__c getConversionFieldMappingObj(String companySettingId, String sourceObj, String targetObj, String sourceField, String targetField) {
        return new SM_Conversion_Fields_Mapping__c(
            SM_Company_Setting__c = companySettingId,
            SM_Source_Object__c = sourceObj,
            SM_Target_Object__c = targetObj,
            SM_Source_Field__c = sourceField,
            SM_Target_Field__c = targetField
        );
    }

    public static SM_Tracking_Inbound__c getTrackingInbound(String name){
        return new SM_Tracking_Inbound__c(
            Name = name
        );
    }

    public static Task getTask(){
        return new Task(
            Subject = 'Task 1'
        );
    }

    public static Asset getAsset(String accountId, String contractId){
        return new Asset(
            Name = 'Asset Name',
            Status = SM_AssetHelper.status.NEW_STATUS,
            AccountId = accountId,
            SM_Contract__c = contractId
        );
    }

    public static ContactPointAddress getContactPointAddress(String street, String city, String state, String postalCode, String country, String addressType){
        return new ContactPointAddress(
            Street = street,
            City = city,
            State = state,
            PostalCode = postalCode,
            Country = country,
            SM_Type__c = addressType,
            SM_Family_Member_Type__c = 'NA'
        );
    }

    public static SM_ACH_Order__c getACHOrder(String contractId){
        return new SM_ACH_Order__c(
            SM_Contract__c = contractId
        );
    }

    public static SM_Asset_Fee__c getAssetFee(String assetId) {
        return new SM_Asset_Fee__c(
            SM_Asset__c = assetId
        );
    }

    public static SM_Payment_Method__c getACHPaymentMethod(String accountId, String bankName) {
        return new SM_Payment_Method__c(
            SM_Account__c = accountId,
            SM_Active__c = true,
            ACH_Account_Type__c = 'Checking',
            ACH_Bank_Name__c = bankName,
            SM_ACH_Account_Number__c = '99999999',
            SM_ACH_Account_Routing_Number__c = '99999999',
            SM_ACH_Bank_Number__c = '99999999',
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment_Method__c', 'ACH')
        );
    }

    public static SM_Payment_Method__c getCreditCardPaymentMethod(String accountId, String franchise) {
        return new SM_Payment_Method__c(
            SM_Account__c = accountId,
            SM_Active__c = true,
            SM_Credit_Card_expiration_month__c = '04',
            SM_Credit_Card_expiration_year__c = '2099',
            SM_Credit_Card_Franchise__c = franchise,
            SM_Credit_Card_Number__c = '1234567890123456',
            RecordTypeId = SM_Utils.getRecordTypeIdByDeveloperName('SM_Payment_Method__c', 'Credit Card')
        );
    }

    public static SM_Payment__c getPayment(String contractId) {
        return new SM_Payment__c(
            SM_Contract__c = contractId,
            Payment_Status__c = 'ACH PENDING'
        );
    }

      /** Get ChargentOrders__ChargentOrder__c record */
      public static SM_Simultaneous_Contract_Updates__c getSimultaneousContract(String prat, String typesContracts){
        if(simultaneousContractObj == null){
            simultaneousContractObj = new SM_Simultaneous_Contract_Updates__c(
                SM_ProcessAutomationByProductFamily__c = prat,
                SM_TypesContractsUpdated__c = typesContracts,
                SM_Object__c = 'Contract',
                SM_FieldName__c = 'SM_Start_date__c'
            );
        }
        return simultaneousContractObj;
    }
}