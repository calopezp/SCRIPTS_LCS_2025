/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 27/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
@IsTest
public with sharing class SM_FeePaymentToDependentContractTest {
    
    @TestSetup
    static void makeData(){

        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());

        /** Insert Account */
        Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail='legal_credit@gmail.com.invalid';
            insert account;

        //List of contracts to insert
        List<Contract> contractsToInsert = new List<Contract>();

        /** Create master contract */
        Contract master = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 45.68
        );
        insert master;

        /** Add dependent contracts */
        for(Integer i = 0; i < 5; i++){

            contractsToInsert.add(new Contract(
                AccountId = account.Id,
                Status = 'Draft',
                StartDate = Date.today(),
                ContractTerm = 8,
                Contract_Type__c = 'Dependent',
                Principal_Contract__c = master.Id,
                Collection_Main_Contract__c = 'Ready for collection',
                Contract_activation_form__c = 'Immediate activation	',
                SM_Requires_AC_Payment__c = true,
                SM_Payment_day__c = 5,
                SM_Frecuency__c = 'Monthly',
                SM_Total_ac__c = 20
            ));
        }

        insert contractsToInsert;
        
    }

    @IsTest
    static void clonePaymentsByAchOrderOk(){

        Contract master = [SELECT SM_Total_ac__c, AccountId FROM Contract WHERE Contract_Type__c = 'Master' limit 1];
        List<Contract> dependents = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent'];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'AC',
            SM_Next_Transaction_Date__c=System.toDay(),
            SM_Fee_to_collect__c = 3
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            SM_Type__c = SM_ACHOrderHelper.paymentType.FEE
        );
        insert masterPayment;

        masterPayment = [SELECT SM_ACH_Order__r.SM_Fee_to_collect__c, SM_Penalty_value__c FROM SM_Payment__c WHERE Id =: masterPayment.Id LIMIT 1];

        /** Create asset */
        List<Asset> assets = new List<Asset>();

        for (Integer i = 0; i < 3; i++) {
            
            assets.add(new Asset(
                Name = 'Asset Name_' + i,
                Status = SM_AssetHelper.status.ACTIVATED,
                AccountId = master.AccountId,
                SM_Contract__c = dependents[i].Id
            ));
        }
        insert assets;

        /** Create Asset fees */
        List<SM_Asset_Fee__c> assetFees = new List<SM_Asset_Fee__c>();

        for (Integer i = 0; i < 3; i++) {
            
            assetFees.add(new SM_Asset_Fee__c(
                SM_Asset__c = assets[i].Id,
                SM_Type__c = 'Fee',
                SM_Contract__c = dependents[i].Id,
                SM_Amount__c = 50,
                SM_Position__c = masterPayment.SM_ACH_Order__r.SM_Fee_to_collect__c -1
            ));
        }
        insert assetFees;

        Test.startTest();
            SM_FeePaymentToDependentContract paymentToDependent = new SM_FeePaymentToDependentContract(new Set<Id>{masterPayment.Id});
        Test.stopTest();

        List<Contract> dependentContracts = [SELECT 
                                                Id 
                                            FROM Contract 
                                            WHERE Contract_Type__c =: SM_ContractHelper.contractType.DEPENDENT 
                                            AND Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION
                                            AND SM_Requires_AC_Payment__c = true];

        List<SM_Payment__c> dependentPayments = [SELECT SM_Amount__c, SM_Penalty_value__c, SM_Fee_value__c FROM SM_Payment__c WHERE SM_Contract__c <>: master.Id];                                    

        System.assertEquals(3, dependentPayments.size(), 'Must be return 5 paymentsa related to dependent contracts');

        /** Check data from dependent payments */
        for (SM_Payment__c dependentPayment : dependentPayments) {

            System.assertEquals(50, dependentPayment.SM_Amount__c, 'Incorrect value to SM_Amount__c ');
            System.assertEquals((masterPayment.SM_Penalty_value__c / 3).setScale(2), dependentPayment.SM_Penalty_value__c, 'Incorrect value to SM_Penalty_value__c ');
            System.assertEquals(50, dependentPayment.SM_Fee_value__c, 'Incorrect value to SM_Fee_value__c ');
        }

        master = [SELECT Audit_Payments_Master_Contract__c FROM Contract WHERE Id =: master.Id limit 1];

        System.assertEquals(true, master.Audit_Payments_Master_Contract__c.contains('Inconsistency in the amount paid in installments'), 'Master don´t updated');

    }

    @IsTest
    static void clonePaymentsByAchOrderInsertOk(){

        Contract master = [SELECT SM_Total_ac__c, AccountId FROM Contract WHERE Contract_Type__c = 'Master' limit 1];
        List<Contract> dependents = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent'];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'AC',
            SM_Next_Transaction_Date__c=System.toDay(),
            SM_Fee_to_collect__c = 3
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            SM_Type__c = SM_ACHOrderHelper.paymentType.FEE,
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED
        );

        /** Create asset */
        List<Asset> assets = new List<Asset>();

        for (Integer i = 0; i < 3; i++) {
            
            assets.add(new Asset(
                Name = 'Asset Name_' + i,
                Status = SM_AssetHelper.status.ACTIVATED,
                AccountId = master.AccountId,
                SM_Contract__c = dependents[i].Id
            ));
        }
        insert assets;

        /** Create Asset fees */
        List<SM_Asset_Fee__c> assetFees = new List<SM_Asset_Fee__c>();

        for (Integer i = 0; i < 3; i++) {
            
            assetFees.add(new SM_Asset_Fee__c(
                SM_Asset__c = assets[i].Id,
                SM_Type__c = 'Fee',
                SM_Contract__c = dependents[i].Id,
                SM_Amount__c = 50,
                SM_Position__c = 1
            ));
        }
        insert assetFees;

        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        List<Contract> dependentContracts = [SELECT 
                                                Id 
                                            FROM Contract 
                                            WHERE Contract_Type__c =: SM_ContractHelper.contractType.DEPENDENT 
                                            AND Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION
                                            AND SM_Requires_AC_Payment__c = true];

        List<SM_Payment__c> dependentPayments = [SELECT SM_Amount__c, SM_Penalty_value__c, SM_Fee_value__c FROM SM_Payment__c WHERE SM_Contract__c <>: master.Id];                                    

        System.assertEquals(3, dependentPayments.size(), 'Must be return 3 paymentsa related to dependent contracts');

        /** Check data from dependent payments */
        for (SM_Payment__c dependentPayment : dependentPayments) {

            System.assertEquals(50, dependentPayment.SM_Amount__c, 'Incorrect value to SM_Amount__c ');
            System.assertEquals((masterPayment.SM_Penalty_value__c / 3).setScale(2), dependentPayment.SM_Penalty_value__c, 'Incorrect value to SM_Penalty_value__c ');
            System.assertEquals(50, dependentPayment.SM_Fee_value__c, 'Incorrect value to SM_Fee_value__c ');
        }

    }

    @IsTest
    static void clonePaymentsByAchOrderUpdatetOk(){

        Contract master = [SELECT SM_Total_ac__c, AccountId FROM Contract WHERE Contract_Type__c = 'Master' limit 1];
        List<Contract> dependents = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent'];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'AC',
            SM_Next_Transaction_Date__c=System.toDay(),
            SM_Fee_to_collect__c = 3
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            SM_Type__c = SM_ACHOrderHelper.paymentType.FEE
        );
        insert masterPayment;

        /** Create asset */
        List<Asset> assets = new List<Asset>();

        for (Integer i = 0; i < 3; i++) {
            
            assets.add(new Asset(
                Name = 'Asset Name_' + i,
                Status = SM_AssetHelper.status.ACTIVATED,
                AccountId = master.AccountId,
                SM_Contract__c = dependents[i].Id
            ));
        }
        insert assets;

        /** Create Asset fees */
        List<SM_Asset_Fee__c> assetFees = new List<SM_Asset_Fee__c>();

        for (Integer i = 0; i < 3; i++) {
            
            assetFees.add(new SM_Asset_Fee__c(
                SM_Asset__c = assets[i].Id,
                SM_Type__c = 'Fee',
                SM_Contract__c = dependents[i].Id,
                SM_Amount__c = 50,
                SM_Position__c = 1
            ));
        }
        insert assetFees;

        Test.startTest();
            masterPayment.Payment_Status__c = SM_PaymentHelper.status.ACCEPTED;
            update masterPayment;
        Test.stopTest();

        List<Contract> dependentContracts = [SELECT 
                                                Id 
                                            FROM Contract 
                                            WHERE Contract_Type__c =: SM_ContractHelper.contractType.DEPENDENT 
                                            AND Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION
                                            AND SM_Requires_AC_Payment__c = true];

        List<SM_Payment__c> dependentPayments = [SELECT SM_Amount__c, SM_Penalty_value__c, SM_Fee_value__c FROM SM_Payment__c WHERE SM_Contract__c <>: master.Id];                                    

        System.assertEquals(3, dependentPayments.size(), 'Must be return 3 paymentsa related to dependent contracts');

        /** Check data from dependent payments */
        for (SM_Payment__c dependentPayment : dependentPayments) {

            System.assertEquals(50, dependentPayment.SM_Amount__c, 'Incorrect value to SM_Amount__c ');
            System.assertEquals((masterPayment.SM_Penalty_value__c / 3).setScale(2), dependentPayment.SM_Penalty_value__c, 'Incorrect value to SM_Penalty_value__c ');
            System.assertEquals(50, dependentPayment.SM_Fee_value__c, 'Incorrect value to SM_Fee_value__c ');
        }

    }

    @IsTest
    static void clonePaymentsByChargentOk(){

        Contract master = [SELECT SM_Total_ac__c, AccountId FROM Contract WHERE Contract_Type__c = 'Master' limit 1];
        List<Contract> dependents = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent'];
        

        /** Create chargent */
        ChargentOrders__ChargentOrder__c chargent = new ChargentOrders__ChargentOrder__c(
                ChargentOrders__Payment_Frequency__c = 'Once',
                ChargentOrders__Payment_Method__c = 'Credit Card',
                ChargentOrders__Tokenization__c = '1929826725-1841993424',
                SM_Payment_Type__c = 'AC',
                Contract__c = master.Id
        );
        insert chargent;
        
        /** Create Chargent transaction */
        ChargentOrders__Transaction__c chargentTransaction = new ChargentOrders__Transaction__c(
            ChargentOrders__Type__c = 'Authorization',
            ChargentOrders__Response_Status__c = 'Approved',
            ChargentOrders__Tokenization__c = '091-29382-298292829229',
            Contract__c = master.Id,
            ChargentOrders__Order__c = chargent.Id
        );
        insert chargentTransaction;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_Chargent_Orders_Transaction__c = chargentTransaction.Id,
            SM_Fee_value__c = 10.68,
            SM_Type__c = SM_ACHOrderHelper.paymentType.LATE_PAYMENT_TYPE,
            SM_Original_Type__c = 'Fee',
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED
        );

        /** Create asset */
        List<Asset> assets = new List<Asset>();

        for (Integer i = 0; i < 3; i++) {
            
            assets.add(new Asset(
                Name = 'Asset Name_' + i,
                Status = SM_AssetHelper.status.ACTIVATED,
                AccountId = master.AccountId,
                SM_Contract__c = dependents[i].Id
            ));
        }
        insert assets;

        /** Create Asset fees */
        List<SM_Asset_Fee__c> assetFees = new List<SM_Asset_Fee__c>();

        for (Integer i = 0; i < 3; i++) {
            
            assetFees.add(new SM_Asset_Fee__c(
                SM_Asset__c = assets[i].Id,
                SM_Type__c = 'Fee',
                SM_Contract__c = dependents[i].Id,
                SM_Amount__c = 50,
                SM_Position__c = 1
            ));
        }
        insert assetFees;

        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        List<Contract> dependentContracts = [SELECT 
                                                Id 
                                            FROM Contract 
                                            WHERE Contract_Type__c =: SM_ContractHelper.contractType.DEPENDENT 
                                            AND Collection_Main_Contract__c =: SM_ContractHelper.collectionMain.READY_FOR_COLLECTION
                                            AND SM_Requires_AC_Payment__c = true];

        List<SM_Payment__c> dependentPayments = [SELECT SM_Amount__c, SM_Penalty_value__c, SM_Fee_value__c FROM SM_Payment__c WHERE SM_Contract__c <>: master.Id];                                    

        System.assertEquals(3, dependentPayments.size(), 'Must be return 3 paymentsa related to dependent contracts');

        /** Check data from dependent payments */
        for (SM_Payment__c dependentPayment : dependentPayments) {

            System.assertEquals(50, dependentPayment.SM_Amount__c, 'Incorrect value to SM_Amount__c ');
            System.assertEquals(0, dependentPayment.SM_Penalty_value__c, 'Incorrect value to SM_Penalty_value__c ');
            System.assertEquals(50, dependentPayment.SM_Fee_value__c, 'Incorrect value to SM_Fee_value__c ');
        }

    }
}