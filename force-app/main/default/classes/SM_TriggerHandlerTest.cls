/**
 * @description       :
 * @author            : diego.jacanamijoy@gmail.com
 * @group             :
 * @last modified on  : 06-12-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                        Modification
 * 1.0   11-26-2020   diego.jacanamijoy@gmail.com   Initial Version
**/
@IsTest
public without sharing class SM_TriggerHandlerTest {

    @TestSetup
    static void makeData(){
        //Cevergae insert methods company setting
        insert SM_TestSmartDataFactory.getCompanySetting();
    }

    @IsTest
    static void updateMehods(){
        SM_Company_setting__c companySetting = [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1];
        Test.StartTest();
            companySetting.SM_Destination_Bussines_Unit__c = 'Legal credit solutions';
            update companySetting;
            companySetting = [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1];
            System.assertEquals('Legal credit solutions', companySetting.SM_Destination_Bussines_Unit__c, 'Record is not updated');
        Test.StopTest();
    }

    @IsTest
    static void deleteMehods(){
        SM_Company_setting__c companySetting = [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1];
        Test.StartTest();
            delete companySetting;
            System.assertEquals(0, [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1].size(), 'Record is not deleted');
        Test.StopTest();
    }

    @IsTest
    static void unDeleteMehods(){
        SM_Company_setting__c companySetting = [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1];
        delete companySetting;
        Test.StartTest();
            undelete companySetting;
            companySetting = [SELECT  SM_Destination_Bussines_Unit__c FROM SM_Company_setting__c LIMIT 1];
            System.assertNotEquals(null, companySetting.Id, 'Record is not undeleted');
        Test.StopTest();
    }
}