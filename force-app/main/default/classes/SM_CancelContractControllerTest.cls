/**
 * @description       : Test class of SM_CancelContractControllerTest
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : LCS
 * @last modified on  : 10-28-2022
 * @last modified by  : Jonathan S. Pachon (JSPA)
**/
@IsTest
public with sharing class SM_CancelContractControllerTest {

    private static String EMAIL_1 = 'legal_credit@gmail.com.invalid';

    @TestSetup
    static void makeData() {
        Test.startTest();
            insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
            Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail = 'legal_credit@gmail.com.invalid';
            insert account;
            ChargentBase__Gateway__c Gt = SM_TestSmartDataFactory.getGateway();
            insert Gt;
            SM_Company_setting__c companySettingObj = SM_TestSmartDataFactory.getCompanySettingPMethod(Gt.Id);
            insert companySettingObj;
            APXTConga4__Conga_Solution__c conga4CongaSolutionObj = SM_TestSmartDataFactory.getConga4CongaSolutionObj();
            insert conga4CongaSolutionObj;
            Process_automation_by_product_family__c processautomationProductfamilyObj = SM_TestSmartDataFactory.getProcessautomationProductfamily(companySettingObj.id,conga4CongaSolutionObj.id);
            processautomationProductfamilyObj.SM_Generates_dispute__c = true;
            insert processautomationProductfamilyObj;
            Opportunity oppToUpgraded = SM_TestSmartDataFactory.getOpportunity();
            oppToUpgraded.AccountId = account.Id;
            oppToUpgraded.SM_Company_Setting__c = companySettingObj.Id;
            insert oppToUpgraded;
            Opportunity newOpp = SM_TestSmartDataFactory.getOpportunity();
            newOpp.AccountId = account.Id;
            newOpp.SM_Company_Setting__c = companySettingObj.Id;
            insert newOpp;
            SM_Bank__c bank1 = new SM_Bank__c();
            bank1.Name = 'BANCO';
            bank1.SM_Routing_Number__c = '111111111';
            insert bank1;
            SM_Payment_Method__c paymentMethodACH1 = SM_TestSmartDataFactory.getACHPaymentMethod(account.Id, 'BANCO POPULAR');
            paymentMethodACH1.SM_Bank__c = bank1.Id;
            SM_Payment_Method__c paymentMethodACH2 = SM_TestSmartDataFactory.getACHPaymentMethod(account.Id, 'BANCO SANTANDER');
            paymentMethodACH2.SM_Bank__c = bank1.Id;
            insert new List<SM_Payment_Method__c>{paymentMethodACH1, paymentMethodACH2};
            Contract contractToUpgrade = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
            contractToUpgrade.SM_Generates_dispute__c = false;
            contractToUpgrade.SM_Opportunity__c = oppToUpgraded.Id;
            contractToUpgrade.SM_Email_to_send_contract__c = 'contractToUpgrade@yopmail.com';
            contractToUpgrade.SM_Payment_Method__c = paymentMethodACH1.Id;
            Contract contractCantUpgraded = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
            contractCantUpgraded.SM_Generates_dispute__c = false;
            contractCantUpgraded.SM_Opportunity__c = oppToUpgraded.Id;
            contractCantUpgraded.SM_Email_to_send_contract__c = 'contractCantUpgraded@yopmail.com';
            contractCantUpgraded.SM_Payment_Method__c = paymentMethodACH1.Id;
            insert new List<Contract>{contractToUpgrade, contractCantUpgraded};
            contractToUpgrade.Status = SM_ContractHelper.status.ACTIVATED;
            contractCantUpgraded.Status = SM_ContractHelper.status.ACTIVATED;
            SM_BypassManager.disableValidationRules();
            update new List<Contract>{contractToUpgrade, contractCantUpgraded};
            SM_BypassManager.enableValidationRules();
            // update contractToUpgrade;
            Contract newContract = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
            newContract.SM_Generates_dispute__c = false;
            newContract.SM_Opportunity__c = newOpp.Id;
            newContract.SM_Email_to_send_contract__c = 'newContract@yopmail.com';
            newContract.SM_UpgradedContract__c = contractToUpgrade.Id;
            newContract.SM_Payment_Method__c = paymentMethodACH1.Id;
            // insert newContract;
            Contract newContractWithoutCancelUpgradedContract = SM_TestSmartDataFactory.getContract(account.Id,processautomationProductfamilyObj.id);
            newContractWithoutCancelUpgradedContract.SM_Generates_dispute__c = false;
            newContractWithoutCancelUpgradedContract.SM_Opportunity__c = newOpp.Id;
            newContractWithoutCancelUpgradedContract.SM_Email_to_send_contract__c = 'newContractWithoutCancelUpgradedContract@yopmail.com';
            newContractWithoutCancelUpgradedContract.SM_UpgradedContract__c = contractCantUpgraded.Id;
            newContractWithoutCancelUpgradedContract.SM_Payment_Method__c = paymentMethodACH1.Id;
            // insert newContractWithoutCancelUpgradedContract;
            insert new List<Contract>{newContract, newContractWithoutCancelUpgradedContract};
            SM_SetupToken__c setupToken=SM_TestSmartDataFactory.getSetupToken();
            insert setupToken;
            SM_Dispute__c oldDispute=SM_TestSmartDataFactory.getDispute();
            oldDispute.SM_Contract__c=contractToUpgrade.id;
            oldDispute.SM_Case_Id__c = 'LCS9999-999999999999';
            // insert oldDispute;
            SM_Dispute__c newDispute=SM_TestSmartDataFactory.getDispute().clone();
            newDispute.SM_Contract__c=newContract.id;
            newDispute.SM_Case_Id__c = 'LCS9999-999999999998';
            // insert newDispute;
            SM_Dispute__c disputeNotUpgraded=SM_TestSmartDataFactory.getDispute().clone();
            disputeNotUpgraded.SM_Contract__c=contractCantUpgraded.id;
            disputeNotUpgraded.SM_Case_Id__c = 'LCS9999-999999999997';
            // insert disputeNotUpgraded;
            insert new List<SM_Dispute__c>{oldDispute, newDispute, disputeNotUpgraded};
            Product2 prd2  = new Product2(
                Name = 'Laptop X200',
                Family = 'Hardware',
                SM_Requires_AC__c = true,
                SM_AC_value__c = 20000,
                Process_automation_by_product_family__c = processautomationProductfamilyObj.Id
            );
            // insert prd2;
            Product2 prd2NotUpgraded  = new Product2(
                Name = 'Laptop X200',
                Family = 'Hardware',
                SM_Requires_AC__c = true,
                SM_AC_value__c = 20000,
                Process_automation_by_product_family__c = processautomationProductfamilyObj.Id
            );
            // insert prd2NotUpgraded;
            insert new List<Product2>{prd2, prd2NotUpgraded};
            Asset assetOfNewContract = SM_TestSmartDataFactory.getAsset(account.Id, newContract.Id);
            assetOfNewContract.Product2Id = prd2.Id;
            // insert assetOfNewContract;
            Asset ast = SM_TestSmartDataFactory.getAsset(account.Id, contractToUpgrade.Id);
            ast.Product2Id = prd2.Id;
            // insert ast;
            Asset astNotUpgraded = SM_TestSmartDataFactory.getAsset(account.Id, contractCantUpgraded.Id);
            astNotUpgraded.Product2Id = prd2NotUpgraded.Id;
            // insert astNotUpgraded;
            insert new List<Asset>{assetOfNewContract, ast, astNotUpgraded};
            SM_UpgradePolicy__c upgradePolicy = new SM_UpgradePolicy__c(
                SM_Active__c = true,
                SM_ProcessAutomationByProductFamily__c = processautomationProductfamilyObj.Id,
                SM_Product__c = prd2.Id
            );
            // insert upgradePolicy;
            SM_UpgradePolicy__c upgradePolicyNotUpgraded = new SM_UpgradePolicy__c(
                SM_Active__c = true,
                SM_ProcessAutomationByProductFamily__c = processautomationProductfamilyObj.Id,
                SM_Product__c = prd2NotUpgraded.Id
            );
            // insert upgradePolicyNotUpgraded;
            insert new List<SM_UpgradePolicy__c>{upgradePolicy, upgradePolicyNotUpgraded};
            SM_ProductLinkingRule__c prdLinkingRule1 = new SM_ProductLinkingRule__c(
                SM_PrincipalObject__c = 'Contract',
                SM_Field__c = 'Status',
                SM_Operator__c = 'equalsTo',
                SM_Condition__c = 'Activated',
                SM_Active__c = true,
                SM_TypeCondition__c = 'Text',
                SM_Type__c = 'Static',
                SM_UpgradePolicy__c = upgradePolicy.Id
            );
            // insert prdLinkingRule1;
            SM_ProductLinkingRule__c prdLinkingRule2 = new SM_ProductLinkingRule__c(
                SM_PrincipalObject__c = 'Contract',
                SM_Field__c = 'Status',
                SM_Operator__c = 'equalsTo',
                SM_Condition__c = 'Finalized',
                SM_Active__c = true,
                SM_TypeCondition__c = 'Text',
                SM_Type__c = 'Static',
                SM_UpgradePolicy__c = upgradePolicyNotUpgraded.Id
            );
            // insert prdLinkingRule2;
            insert new List<SM_ProductLinkingRule__c>{prdLinkingRule1, prdLinkingRule2};
            Task taskOnUpgradedContract = new Task(
                WhatId = contractToUpgrade.Id,
                Subject = 'Task on Upgraded Contract'
            );
            // insert taskOnUpgradedContract;
            Task taskOnNotUpgradedContract = new Task(
                WhatId = contractCantUpgraded.Id,
                Subject = 'Task on Not Upgraded Contract'
            );
            // insert taskOnNotUpgradedContract;
            insert new List<Task>{taskOnUpgradedContract, taskOnNotUpgradedContract};
            SM_Cloud_Document__c cloudDocumentOnUpgradedContract = new SM_Cloud_Document__c(
                SM_Contract__c = contractToUpgrade.Id,
                SM_Extension__c = 'pdf',
                Name = 'Cloud Document on Upgraded Contract'
            );
            // insert cloudDocumentOnUpgradedContract;
            SM_Cloud_Document__c cloudDocumentOnNotUpgradedContract = new SM_Cloud_Document__c(
                SM_Contract__c = contractCantUpgraded.Id,
                SM_Extension__c = 'pdf',
                Name = 'Cloud Document on Not Upgraded Contract'
            );
            // insert cloudDocumentOnNotUpgradedContract;
            insert new List<SM_Cloud_Document__c>{cloudDocumentOnUpgradedContract, cloudDocumentOnNotUpgradedContract};
            SM_ACH_Order__c achOrder = SM_TestSmartDataFactory.getACHOrder(contractToUpgrade.Id);
            achOrder.SM_Payment_Status__c = 'Initiated';
            achOrder.SM_Payment_Method__c = paymentMethodACH1.Id;
            achOrder.SM_Total__c = 69;
            achOrder.SM_Payment_Frequency__c = 'Monthly';
            achOrder.SM_Payment_Start_Date__c = System.today();
            achOrder.SM_Payment_End_Date__c = System.today();
            achOrder.SM_Next_Transaction_Date__c = System.today();
            // insert achOrder;
            SM_ACH_Order__c achOrderNotUpgraded = SM_TestSmartDataFactory.getACHOrder(contractCantUpgraded.Id);
            achOrder.SM_Payment_Status__c = 'Initiated';
            achOrderNotUpgraded.SM_Payment_Method__c = paymentMethodACH1.Id;
            achOrderNotUpgraded.SM_Total__c = 69;
            achOrderNotUpgraded.SM_Payment_Frequency__c = 'Monthly';
            achOrderNotUpgraded.SM_Payment_Start_Date__c = System.today();
            achOrderNotUpgraded.SM_Payment_End_Date__c = System.today();
            achOrderNotUpgraded.SM_Next_Transaction_Date__c = System.today();
            // insert achOrderNotUpgraded;
            insert new List<SM_ACH_Order__c>{achOrder, achOrderNotUpgraded};
            SM_Payment__c payment = SM_TestSmartDataFactory.getPayment(contractToUpgrade.Id);
            payment.SM_ACH_Order__c = achOrder.Id;
            payment.Payment_Status__c = 'REFUNDED';
            // insert payment;
            SM_Payment__c paymentNotUpgraded = SM_TestSmartDataFactory.getPayment(contractCantUpgraded.Id);
            paymentNotUpgraded.SM_ACH_Order__c = achOrderNotUpgraded.Id;
            // insert paymentNotUpgraded;
            insert new List<SM_Payment__c>{payment, paymentNotUpgraded};
            System.debug('payment: ' + JSON.serialize(payment));
            ChargentOrders__ChargentOrder__c cO = SM_TestSmartDataFactory.getChargentorder(Account.Id,contractToUpgrade,companySettingObj,'AC');
            co.ChargentOrders__Status__c = 'Initiated';
            co.ChargentOrders__Payment_Status__c = 'Recurring';
            co.ChargentOrders__Card_Type__c = 'Discover';
            co.ChargentOrders__Card_Month_Indicator__c = '01';
            co.ChargentOrders__Card_Last_4__c = '9999';
            co.ChargentOrders__Card_Year_Indicator__c = '2050';
            co.ChargentOrders__Billing_First_Name__c = 'John';
            co.ChargentOrders__Tokenization__c = '998877';
            co.Contract__c = contractToUpgrade.Id;
            co.ChargentOrders__Payment_Start_Date__c = System.today();
            insert cO;
            echosign_dev1__SIGN_Agreement__c agreement = SM_TestSmartDataFactory.getAgreement();
            agreement.echosign_dev1__Contract__c = contractToUpgrade.Id;
            insert agreement;
        Test.stopTest();
    }

    @IsTest
    static void activateNewContractAndCancelUpgradeContract() {
        System.debug('Executing activateNewContractAndCancelUpgradeContract');
        Test.startTest();
        Contract newContractToUpdate = [SELECT Id FROM Contract WHERE SM_Email_to_send_contract__c = 'newContract@yopmail.com'];
        newContractToUpdate.Status = SM_ContractHelper.status.ACTIVATED;
        SM_BypassManager.disableValidationRules();
        update newContractToUpdate;
        SM_BypassManager.enableValidationRules();
        Test.stopTest();
        // UpgradedContract
        Contract upgradedContract = [SELECT
                                        (SELECT Id, Status FROM Assets__r),
                                        (SELECT Id, SM_Status__c FROM Disputes__r),
                                        (SELECT Id, SM_Payment_Status__c FROM ACH_Orders__r),
                                        (SELECT Id, ChargentOrders__Status__c FROM Chargent_Orders__r),
                                        (SELECT Id, Payment_Status__c FROM Payment_Data__r),
                                        (SELECT Id, echosign_dev1__Status__c FROM echosign_dev1__R00N70000001hM2JEAU__r),
                                        (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                                            CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                                            RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                                            Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                                            Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                                            SM_Migration_Date__c, SM_Is_Migrated__c
                                            FROM Tasks),
                                        (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                                            SM_Opportunity__c, SM_Contract__c
                                            FROM SM_Cloud_Documents_Contract__r)
                                    FROM Contract
                                    WHERE SM_Email_to_send_contract__c = 'contractToUpgrade@yopmail.com'];
        System.debug('upgradedContract: ' + JSON.serialize(upgradedContract));
        System.debug('upgradedContract.Disputes__r: ' + JSON.serialize(upgradedContract.Disputes__r));
        System.assertEquals(1, upgradedContract.Assets__r.size(), 'The assets quantity are not the expected.');
        System.assertEquals(SM_AssetHelper.status.CANCELLED, upgradedContract.Assets__r[0].Status, 'The asset status is not the expected.');

        System.assertEquals(1, upgradedContract.Disputes__r.size(), 'The disputes quantity are not the expected.');
        System.assertEquals(SM_DisputeHelper.status.CANCELLED, upgradedContract.Disputes__r[0].SM_Status__c, 'The dispute status is not the expected.');

        System.assertEquals(1, upgradedContract.ACH_Orders__r.size(), 'The ach orders quantity are not the expected.');
        System.assertEquals(SM_ACHOrderHelper.paymentStatus.CANCELED, upgradedContract.ACH_Orders__r[0].SM_Payment_Status__c, 'The ach order status is not the expected.');

        System.assertEquals(1, upgradedContract.Chargent_Orders__r.size(), 'The chargent orders quantity are not the expected.');
        System.assertEquals(SM_ChargentOrderHelper.status.CANCELED, upgradedContract.Chargent_Orders__r[0].ChargentOrders__Status__c, 'The chargent order status is not the expected.');

        System.assertEquals(1, upgradedContract.Payment_Data__r.size(), 'The payments quantity are not the expected.');
        System.assertEquals('REFUNDED', upgradedContract.Payment_Data__r[0].Payment_Status__c, 'The payment status is not the expected.');

        System.assertEquals(1, upgradedContract.SM_Cloud_Documents_Contract__r.size(), 'The cloud documents quantity on upgraded contract are not the expected.');
        System.assertEquals('Cloud Document on Upgraded Contract', upgradedContract.SM_Cloud_Documents_Contract__r[0].Name, 'The cloud document name on upgraded contract is not the expected.');

        System.assertEquals(1, upgradedContract.Tasks.size(), 'The tasks quantity on upgraded contract are not the expected.');
        System.assertEquals('Task on Upgraded Contract', upgradedContract.Tasks[0].Subject, 'The task name on upgraded contract is not the expected.');

        System.assertEquals(1, upgradedContract.echosign_dev1__R00N70000001hM2JEAU__r.size(), 'The agreements quantity on upgraded contract are not the expected.');
        System.assertEquals('Cancelled / Declined', upgradedContract.echosign_dev1__R00N70000001hM2JEAU__r[0].echosign_dev1__Status__c, 'The task name on upgraded contract is not the expected.');
        // NewContract
        Contract newContract = [SELECT
                                    (SELECT Id, Status FROM Assets__r),
                                    (SELECT Id FROM Disputes__r),
                                    (SELECT Id FROM ACH_Orders__r),
                                    (SELECT Id FROM Chargent_Orders__r),
                                    (SELECT Id FROM Payment_Data__r),
                                    (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                                        CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                                        RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                                        Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                                        Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                                        SM_Migration_Date__c, SM_Is_Migrated__c
                                        FROM Tasks),
                                    (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                                        SM_Opportunity__c, SM_Contract__c
                                        FROM SM_Cloud_Documents_Contract__r)
                                FROM Contract
                                WHERE SM_Email_to_send_contract__c = 'newContract@yopmail.com'];
        System.assertEquals(1, newContract.SM_Cloud_Documents_Contract__r.size(), 'The cloud documents quantity on new contract are not the expected.');
        System.assertEquals('Cloud Document on Upgraded Contract', newContract.SM_Cloud_Documents_Contract__r[0].Name, 'The cloud document name on new contract is not the expected.');
        System.assertEquals(1, newContract.Tasks.size(), 'The tasks quantity on new contract are not the expected.');
        System.assertEquals('Task on Upgraded Contract', newContract.Tasks[0].Subject, 'The task name on new contract is not the expected.');
    }

    @IsTest
    static void activateNewContractAndCancelUpgradeContractCantUpgrade() {
        System.debug('Executing activateNewContractAndCancelUpgradeContract');
        Test.startTest();
        Contract newContractToUpdate = [SELECT Id FROM Contract WHERE SM_Email_to_send_contract__c = 'newContractWithoutCancelUpgradedContract@yopmail.com'];
        newContractToUpdate.Status = SM_ContractHelper.status.ACTIVATED;
        SM_BypassManager.disableValidationRules();
        update newContractToUpdate;
        SM_BypassManager.enableValidationRules();
        Test.stopTest();
        // UpgradedContract
        Contract notUpgradedContract = [SELECT
                                        (SELECT Id FROM Transaction_Log__r WHERE Process_Name__c = 'CancelUpgradedContract'),
                                        (SELECT Id, Status FROM Assets__r),
                                        (SELECT Id, SM_Status__c FROM Disputes__r),
                                        (SELECT Id, SM_Payment_Status__c FROM ACH_Orders__r),
                                        (SELECT Id, ChargentOrders__Status__c FROM Chargent_Orders__r),
                                        (SELECT Id, Payment_Status__c FROM Payment_Data__r),
                                        (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                                            CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                                            RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                                            Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                                            Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                                            SM_Migration_Date__c, SM_Is_Migrated__c
                                            FROM Tasks
                                            ORDER By CreatedDate ASC),
                                        (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                                            SM_Opportunity__c, SM_Contract__c
                                            FROM SM_Cloud_Documents_Contract__r)
                                    FROM Contract
                                    WHERE SM_Email_to_send_contract__c = 'contractCantUpgraded@yopmail.com'];
        System.debug('notUpgradedContract: ' + JSON.serialize(notUpgradedContract));
        System.debug('notUpgradedContract.Disputes__r: ' + JSON.serialize(notUpgradedContract.Disputes__r));

        System.assertEquals(1, notUpgradedContract.ACH_Orders__r.size(), 'The ach orders quantity on not upgraded contract are not the expected.');
        System.assertEquals('Initiated', notUpgradedContract.ACH_Orders__r[0].SM_Payment_Status__c, 'The ach order status on not upgraded contract is not the expected.');

        System.assertEquals(1, notUpgradedContract.SM_Cloud_Documents_Contract__r.size(), 'The cloud documents quantity on not upgraded contract are not the expected.');
        System.assertEquals('Cloud Document on Not Upgraded Contract', notUpgradedContract.SM_Cloud_Documents_Contract__r[0].Name, 'The cloud document name on not upgraded contract is not the expected.');

        System.assertEquals(2, notUpgradedContract.Tasks.size(), 'The tasks quantity on not upgraded contract are not the expected.');
        System.assertEquals('Task on Not Upgraded Contract', notUpgradedContract.Tasks[0].Subject, 'The task name on not upgraded contract is not the expected.');
        String errorDetail = 'Meets Upgrade Condition: Cannot upgrade - Upgraded Process Detail: ';
        System.assertEquals(String.format(System.label.SM_ERROR_CANCEL_UPGRADED_CONTRACT_PROCESS, new List<String>{notUpgradedContract.Id, errorDetail}), notUpgradedContract.Tasks[1].Description, 'The task is not the expected.');

        System.assertEquals(1, notUpgradedContract.Transaction_Log__r.size(), 'The logs quantity on not upgraded contract are not the expected.');


        // NewContract
        Contract newContract = [SELECT
                                    (SELECT Id, Status FROM Assets__r),
                                    (SELECT Id FROM Disputes__r),
                                    (SELECT Id FROM ACH_Orders__r),
                                    (SELECT Id FROM Chargent_Orders__r),
                                    (SELECT Id FROM Payment_Data__r),
                                    (SELECT Id, RecordTypeId, WhoId, WhatId, Subject, ActivityDate, Status, Priority, OwnerId, Description, CallDurationInSeconds, CallType, CallDisposition,
                                        CallObject, ReminderDateTime, IsReminderSet, RecurrenceStartDateOnly, RecurrenceEndDateOnly, RecurrenceTimeZoneSidKey, RecurrenceType, RecurrenceInterval,
                                        RecurrenceDayOfWeekMask, RecurrenceDayOfMonth, RecurrenceInstance, RecurrenceMonthOfYear, RecurrenceRegeneratedType, Five9__Five9SessionId__c,
                                        Five9__Five9TaskType__c, Five9ANI__c, Five9AgentExtension__c, Five9AgentName__c, Five9Agent__c, Five9CallType__c, Five9Campaign__c, Five9DNIS__c,
                                        Five9HandleTime__c, Five9InteractionDuration__c, Five9WrapTime__c, SM_Description_Filter__c, SM_TextAssignedTo__c, SM_Id_Salesforce_LCS__c,
                                        SM_Migration_Date__c, SM_Is_Migrated__c
                                        FROM Tasks),
                                    (SELECT OwnerId, Name, SM_Account__c, SM_Active__c, SM_Abbreviated_Company__c, SM_Extension__c, SM_File_Path__c, SM_Documet_Type__c, SM_Lead__c,
                                        SM_Opportunity__c, SM_Contract__c
                                        FROM SM_Cloud_Documents_Contract__r)
                                FROM Contract
                                WHERE SM_Email_to_send_contract__c = 'newContractWithoutCancelUpgradedContract@yopmail.com'];
        System.assertEquals(0, newContract.SM_Cloud_Documents_Contract__r.size(), 'The cloud documents quantity on new contract are not the expected.');
        System.assertEquals(0, newContract.Tasks.size(), 'The tasks quantity on new contract are not the expected.');
    }
}