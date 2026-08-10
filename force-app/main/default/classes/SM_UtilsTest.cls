/**
 * @description       : 
 * @author            : diego.jacanamijoy@gmail.com
 * @group             : 
 * @last modified on  : 01-18-2021
 * @last modified by  : diego.jacanamijoy@gmail.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-24-2020   diego.jacanamijoy@gmail.com   Initial Version
**/
@IsTest
public with sharing class SM_UtilsTest {
    
    @TestSetup
    static void makeData(){
        insert SM_TestSmartDataFactory.getCompanySetting();
    }
    
    @IsTest
    static void getSObjectNameByIdOk(){
        Lead lead = SM_TestSmartDataFactory.getLead();
        insert lead;
        Test.StartTest();
            String sObjectName = SM_Utils.getSObjectNameById(lead.Id);
        Test.StopTest();

        system.assertEquals('Lead',sObjectName, 'SObjectName incorrect');
    }

    @IsTest
    static void getSObjectNameByIdError(){
        Lead lead = SM_TestSmartDataFactory.getLead();
        Test.StartTest();
            String sObjectName = SM_Utils.getSObjectNameById(lead.Id);
        Test.StopTest();

        system.assertEquals('',sObjectName, 'must return empty');
    }

    @IsTest
    static void createSObjectOk(){
        Test.startTest();
            SObject so = SM_Utils.createSObject('Account');
        Test.stopTest();
        System.assertNotEquals(null, so, 'The result not must null');
    }

    @IsTest
    static void isChangedFieldOk(){
        Lead oldLead = SM_TestSmartDataFactory.getLead();
        oldLead.Phone = '312222344';
        Lead newLead = oldLead.clone();
        newLead.Phone = '312222333';
        Test.startTest();
            Boolean isChanged = SM_Utils.isChangedField(newLead, oldLead, new List<String>{'Phone'});
        Test.stopTest();
        System.assertEquals(true, isChanged, 'The result must is true');
    }
    
    @Istest
    static void getRecordTypeIdByDeveloperNameOk(){
        RecordType recordType = [SELECT Name FROM RecordType WHERE SobjectType = 'Account' LIMIT 1];
        Test.startTest();
            String result = SM_Utils.getRecordTypeIdByDeveloperName('Account', recordType.Name);
        Test.stopTest();
        System.assertEquals(result, recordType.Id, 'The result not must null');
    }

    @Istest
    static void getFieldsFromFieldSetOk(){
        Test.startTest();
            List<String> fields = SM_Utils.getFieldsFromFieldSet('Account', 'Account');
        Test.stopTest();
        System.assertNotEquals(null, fields, 'The result not must null');
    }

    @IsTest
    static void formatPhone(){
        String miPhone1 = '(310)-526-12-00';
        String miPhone2 = '310 526 12 00';
        String miPhone3 = '+310 526 12 00 ext 3';

        system.assertEquals('3105261200', SM_Utils.formatPhone(miPhone1), 'Invalid format from phone1');
        system.assertEquals('3105261200', SM_Utils.formatPhone(miPhone2), 'Invalid format from phone2');
        system.assertEquals('31052612003', SM_Utils.formatPhone(miPhone3), 'Invalid format from phone3');
    }

}