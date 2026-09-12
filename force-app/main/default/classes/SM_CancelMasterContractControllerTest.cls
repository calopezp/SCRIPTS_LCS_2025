/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 07/10/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
@IsTest
public with sharing class SM_CancelMasterContractControllerTest {

    @TestSetup
    static void makeData(){

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
            Collection_Main_Contract__c = 'Pending data capture'
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
                SM_Frecuency__c = 'Monthly'
            ));
        }

        insert contractsToInsert;

        Asset asset = SM_TestSmartDataFactory.getAsset(account.Id, master.Id);
        insert asset;
        
    }

    @IsTest
    static void cancelMaster() {

        Contract master = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Master' LIMIT 1];

        Test.startTest();
            System.enqueueJob(new SM_CancelMasterContractController(new Set<Id>{master.Id}));
        Test.stopTest();

        //System.assertEquals('Cancelled', [SELECT Status FROM Asset LIMIT 1].Status, 'Asset don´t cancelled');

        List<Contract> dependents = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent'];
        List<Contract> dependentsCanceled = [SELECT Id FROM Contract WHERE Contract_Type__c = 'Dependent' AND Status = 'Cancelled'];

        System.assertEquals(5, dependents.size(), 'Must be return 5 records dependent');
        //System.assertEquals(5, dependentsCanceled.size(), 'Must be return 5 records cancel and dependent');
    }
}