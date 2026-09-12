/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-09-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   06-09-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
@IsTest
public with sharing class SM_AgreementHandlerTest {

	@IsTest
    static void updAgreement(){
        Test.startTest();
        echosign_dev1__SIGN_Agreement__c Agre = SM_TestSmartDataFactory.getAgreement();
		insert agre;
        Attachment at = SM_TestSmartDataFactory.getAttachment(Agre.Id);
		Insert at;

        Agre.echosign_dev1__Attachment_ID_Order2__c = at.Id;
        Agre.echosign_dev1__Status__c = 'Out for Signature';
        update agre;
        System.assertEquals('Out for Signature', [SELECT  id,echosign_dev1__Status__c FROM echosign_dev1__SIGN_Agreement__c where id =: agre.id].echosign_dev1__Status__c, 'Status Update');
        Test.stopTest();
    }
}