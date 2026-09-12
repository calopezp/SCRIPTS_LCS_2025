/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * @group             :
 * @last modified on  : 06-12-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com
 * Modifications Log
 * Ver   Date         Author                                                Modification
 * 1.0   06-12-2021   Jonathan S. Pachon Ariza -> jpachon.ariza@gmail.com   Initial Version
**/
@IsTest
public without sharing class SM_AttachmentHelperTest {

    @IsTest
    static void testCreateDocument(){
        Test.startTest();
            String nameDocument = 'contract.pdf';
            // String idObjct = ;
            String documetType = 'documentType';
            String pathS3 = 'pathS3';
            String abbreviatedCompany = 'LCS';
            SM_Cloud_Document__c cloudDocument = SM_AttachmentHelper.createCloudDocument(nameDocument, null, documetType, pathS3, abbreviatedCompany);
        Test.stopTest();
    }
}