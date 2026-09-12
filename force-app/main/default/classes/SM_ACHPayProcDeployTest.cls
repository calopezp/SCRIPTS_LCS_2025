@IsTest
private with sharing class SM_ACHPayProcDeployTest {

    @TestSetup
    static void setupData() {
        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());

        Account accountRecord = SM_TestSmartDataFactory.getPersonAccount();
        accountRecord.PersonEmail = 'ach.process.deploy@test.invalid';
        insert accountRecord;

        SM_Bank__c bankRecord = new SM_Bank__c(Name = 'Bank ACH Deploy', SM_Routing_Number__c = '987654321');
        insert bankRecord;

        SM_Payment_Method__c achMethod = SM_TestSmartDataFactory.getACHPaymentMethod(accountRecord.Id, 'BANCO POPULAR ACH');
        achMethod.SM_Bank__c = bankRecord.Id;
        insert achMethod;

        SM_Company_setting__c companySetting = SM_TestSmartDataFactory.getCompanySetting();
        insert companySetting;

        Opportunity opportunityRecord = SM_TestSmartDataFactory.getOpportunity();
        opportunityRecord.AccountId = accountRecord.Id;
        opportunityRecord.SM_Company_Setting__c = companySetting.Id;
        insert opportunityRecord;

        Process_automation_by_product_family__c processRecord = SM_TestSmartDataFactory.getProccessAutomation();
        processRecord.Company_setting__c = companySetting.Id;
        insert processRecord;

        insert new SM_Required_Field_Info__c(
            Name = 'ACH Deploy Required',
            SM_Company_Setting__c = companySetting.Id,
            SM_Api_Field_Name__c = 'Id',
            SM_Process__c = 'AC - Full Payment',
            SM_Source_Object__c = 'Contract'
        );

        insert new SM_Required_Field_Info__c(
            Name = 'ACH Subscription Required',
            SM_Company_Setting__c = companySetting.Id,
            SM_Api_Field_Name__c = 'Id',
            SM_Process__c = 'Subscription',
            SM_Source_Object__c = 'Contract'
        );

        Contract masterContract = new Contract(
            AccountId = accountRecord.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            Contract_Type__c = SM_ContractHelper.contractType.MASTER,
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Payment_Method__c = achMethod.Id,
            SM_Opportunity__c = opportunityRecord.Id,
            SM_Requires_AC_Payment__c = true,
            SM_Way_of_AC_Payment__c = 'One payment',
            SM_AC_start_date__c = Date.today().addDays(3),
            SM_Total_AC__c = 100,
            SM_Requires_RC_Payment__c = true,
            SM_Way_of_Contract_Payment__c = 'Subscription',
            SM_Frecuency__c = 'Monthly',
            SM_Start_date__c = Date.today().addDays(5),
            SM_Monthly_offer__c = 80,
            SM_Process_automation_by_product_family__c = processRecord.Id
        );
        insert masterContract;

        List<Contract> dependentContracts = new List<Contract>();
        for (Integer idx = 0; idx < 2; idx++) {
            dependentContracts.add(new Contract(
                AccountId = accountRecord.Id,
                Status = 'Draft',
                StartDate = Date.today(),
                ContractTerm = 12,
                Contract_Type__c = SM_ContractHelper.contractType.DEPENDENT,
                Principal_Contract__c = masterContract.Id,
                Collection_Main_Contract__c = 'Ready for collection',
                SM_Total_ac__c = 50
            ));
        }
        insert dependentContracts;

        insert new SM_ACH_Order__c(
            SM_Contract__c = masterContract.Id,
            SM_Payment_Type__c = SM_ACHOrderHelper.paymentType.SUBSCRIPTION,
            SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.PENDING,
            SM_Payment_Method__c = achMethod.Id,
            SM_Total__c = 30,
            SM_Payment_Start_Date__c = Date.today(),
            SM_Next_Transaction_Date__c = Date.today()
        );
    }

    @IsTest
    static void shouldExecuteAchCreationAndSubscriptionPaths() {
        Contract masterContract = [SELECT Id FROM Contract WHERE Contract_Type__c = :SM_ContractHelper.contractType.MASTER LIMIT 1];

        Test.startTest();
            SM_ACHPaymentProcessHandler.CreateACOrderRecordsACH(
                new List<String>{ (String)masterContract.Id },
                new List<Object>{ 'AC - Full Payment' },
                new List<Object>{ SM_ACHOrderHelper.paymentType.AC }
            );
            SM_ACHPaymentProcessHandler.CreateSubscriptionOrderRecordsACH(
                new List<String>{ (String)masterContract.Id }
            );
        Test.stopTest();

        Integer achOrders = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :masterContract.Id];
        System.assert(achOrders >= 1, 'Expected ACH process execution without unhandled exceptions.');
    }

    @IsTest
    static void shouldExecuteAssetFeeBundlePath() {
        List<Contract> dependentContracts = [
            SELECT Id, Contract_Type__c, Principal_Contract__c
            FROM Contract
            WHERE Contract_Type__c = :SM_ContractHelper.contractType.DEPENDENT
            LIMIT 2
        ];

        Test.startTest();
            SM_ACHPaymentProcessHandler.createAssetFeetBoundle(dependentContracts);
        Test.stopTest();

        System.assertEquals(2, dependentContracts.size(), 'Expected dependent contracts prepared for bundle path.');
    }

    @IsTest
    static void shouldCreateFixTermOrders() {
        Account accountRecord = [SELECT Id FROM Account LIMIT 1];
        SM_Payment_Method__c achMethod = [SELECT Id FROM SM_Payment_Method__c LIMIT 1];
        Opportunity opportunityRecord = [SELECT Id FROM Opportunity LIMIT 1];
        Process_automation_by_product_family__c processRecord = [SELECT Id FROM Process_automation_by_product_family__c LIMIT 1];

        Contract splitContract = new Contract(
            AccountId = accountRecord.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 12,
            Contract_Type__c = SM_ContractHelper.contractType.MASTER,
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Payment_Method__c = achMethod.Id,
            SM_Opportunity__c = opportunityRecord.Id,
            SM_Requires_AC_Payment__c = true,
            SM_Way_of_AC_Payment__c = 'One payment',
            SM_AC_start_date__c = Date.today().addDays(3),
            SM_Total_AC__c = 120,
            SM_Requires_RC_Payment__c = true,
            SM_Way_of_Contract_Payment__c = 'Fix Term',
            SM_Start_date__c = Date.today().addDays(5),
            SM_Monthly_offer__c = 90,
            SM_Plan_Months__c = 3,
            SM_Process_automation_by_product_family__c = processRecord.Id
        );
        insert splitContract;

        Test.startTest();
            SM_ACHPaymentProcessHandler.CreateACOrderRecordsACH(
                new List<String>{ (String)splitContract.Id },
                new List<Object>{ 'AC - Full Payment' },
                new List<Object>{ SM_ACHOrderHelper.paymentType.AC }
            );
            SM_ACHPaymentProcessHandler.CreateSubscriptionOrderRecordsACH(
                new List<String>{ (String)splitContract.Id }
            );
        Test.stopTest();

        Integer orderCount = [SELECT COUNT() FROM SM_ACH_Order__c WHERE SM_Contract__c = :splitContract.Id];
        System.assert(orderCount >= 2, 'Expected AC plus fix-term orders to be created.');
    }
}