/**
 * @description       : Handlar Trigger Attachment
 * @author            : Camilo j. -> cjimenez@legal-credit.com
 * @group             : 
 * @last modified on  : 06-02-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                  Modification
 * 1.0   10-04-2021   Camilo j. Camilo Jimenez ->  cjimenez@legal-credit.com  Initial Version
**/
public with sharing class SM_AttachmentHandler extends SM_TriggerHandler {

public SM_AttachmentHandler(String triggerName){
    super(triggerName);
}

override public void asyncAfterInsert(){
    try {
        System.debug('Ready to execute future method - uploaAmazonS3');
        uploaAmazonS3(Trigger.newMap.keySet());
    } catch (Exception e) {
        System.debug('An error occurred in afterInsert Contract  '+ e.getTypeName() + ' ' + e.getMessage() + ' ' +e.getStackTraceString());
    }
}

/**
 * @description This method to Attachment 
 * @author cjimenez@legal-credit.com | 07-02-2021
 */
@Future (Callout=true)
public static void uploaAmazonS3(Set<ID> AttachmentByIds){
  List<SM_Cloud_Document__c> lstCloudDocumentInser=new List<SM_Cloud_Document__c>();
  List<attachment> lstAttachmentDelete=new List<attachment>();
  Map<String,Attachment> attacByAgree=new  Map<String,Attachment>();

  SM_CloudDocumentPath cloudDocumentPath=new SM_CloudDocumentPath();
  for(Attachment newAttachment:[SELECT id,Body,ContentType,Name,OwnerId,ParentId
                                                    FROM Attachment
                                                    WHERE id IN :AttachmentByIds] ){
     if(SM_Utils.getSObjectNameById((ID)newAttachment.ParentId).contains(SM_AttachmentHelper.objectNameEnum.AGREEMENT) && newAttachment.Name.contains(SM_AttachmentHelper.statusEnum.SIGNED)){
         attacByAgree.put(newAttachment.ParentId,newAttachment);
      }  
   }
    for(echosign_dev1__SIGN_Agreement__c agreement:[SELECT id,echosign_dev1__Contract__c,echosign_dev1__Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Abbreviated_Company__c
                                                    FROM echosign_dev1__SIGN_Agreement__c
                                                    WHERE id IN :attacByAgree.keySet()] ){
        String key=agreement.id;
        Attachment attachment=attacByAgree.containsKey(key) ? attacByAgree.get(key) : null ;
        if(attachment != null){
            String pathS3='';   
            String nameDocument=attachment.name.deleteWhitespace();
            pathS3=cloudDocumentPath.generatePath(SM_AttachmentHelper.documetType.AGREEMENTS,nameDocument,agreement.echosign_dev1__Contract__c,agreement.echosign_dev1__Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Abbreviated_Company__c);
            pathS3=cloudDocumentPath.bucket.bucketName+'/'+pathS3;
            pathS3=pathS3.deleteWhitespace();
            SM_RequestS3Helper helper = new SM_RequestS3Helper();
            HTTPResponse response = helper.uploadFilesToS3(attachment,nameDocument,pathS3,cloudDocumentPath.bucket);
            if(response!= null && response.getStatus() == 'OK' && response.getStatusCode() == 200){
                lstCloudDocumentInser.add(SM_AttachmentHelper.createCloudDocument(nameDocument,agreement.echosign_dev1__Contract__c,SM_AttachmentHelper.documetType.AGREEMENTS,pathS3,agreement.echosign_dev1__Contract__r.SM_Opportunity__r.SM_Company_Setting__r.SM_Abbreviated_Company__c));
                lstAttachmentDelete.add(attachment);
              }
         }                                                         
      }

      if(!lstCloudDocumentInser.isEmpty()){
         Database.insert(lstCloudDocumentInser);
            SM_S3StorageProviderRouter.routeUploads(lstCloudDocumentInser);
      }
      if(!lstAttachmentDelete.isEmpty()){
         Database.delete(lstAttachmentDelete);
      }
  }

}