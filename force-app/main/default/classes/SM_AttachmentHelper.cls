/**
 * @description       : Helper  SM_AttachmentHandler
 * @author            : Camilo j. -> cjimenez@legal-credit.com
 * @group             : 
 * @last modified on  : 10-04-2021
 * @last modified by  : Camilo j. Camilo Jimenez ->  cjimenez@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                                                  Modification
 * 1.0   10-04-2021   Camilo j. Camilo Jimenez ->  cjimenez@legal-credit.com  Initial Version
**/
public with sharing class SM_AttachmentHelper {
      //Instances of enums
    public static DocumetTypeEnum  documetType  = new DocumetTypeEnum();
    public static ObjectNameEnum   objectNameEnum = new ObjectNameEnum();
    public static StatusEnum statusEnum = new StatusEnum();

    /** This class represents Enum to attribute status (Developer name) */
    public class DocumetTypeEnum {
        public String AGREEMENTS = 'Agreements';
        public String IDENTIFICATION = 'Identification Documents';
        public String OTHERS = 'Others Documents';
    }

     /** This class represents Enum to attribute status (Developer name) */
     public class  ObjectNameEnum {
        public String AGREEMENT = 'echosign_dev1__SIGN_Agreement__c';
    }

     /** This class represents Enum to attribute status (Developer name) */
     public class  StatusEnum {
        public String SIGNED = 'signed';
    }

    public static SM_Cloud_Document__c createCloudDocument(String nameDocument,String idObjct,String documetType,String pathS3,String abbreviatedCompany){ 
        String extFile=nameDocument.substring(nameDocument.lastIndexOf('.') + 1).toLowerCase();
        String provider = SM_S3StorageProviderResolver.resolveProviderByRecordId(idObjct);
        SM_Cloud_Document__c cloudDocumen= new SM_Cloud_Document__c();
        cloudDocumen.Name=nameDocument;
        cloudDocumen.SM_File_Path__c=pathS3;
        cloudDocumen.SM_Documet_Type__c=documetType;
        cloudDocumen.SM_Extension__c=extFile;
        cloudDocumen.SM_Active__c=true;
        cloudDocumen.SM_Contract__c=idObjct;  
        cloudDocumen.SM_Abbreviated_Company__c=abbreviatedCompany;
        cloudDocumen.SM_Storage_Provider__c = provider;
        cloudDocumen.SM_Storage_Status__c = 'Uploaded';
        cloudDocumen.SM_Storage_Last_Sync_At__c = System.now();

        Integer separatorIndex = String.isBlank(pathS3) ? -1 : pathS3.indexOf('/');
        if (separatorIndex > 0) {
            cloudDocumen.SM_Storage_Bucket__c = pathS3.substring(0, separatorIndex);
            cloudDocumen.SM_Storage_Object_Key__c = pathS3.substring(separatorIndex + 1);
        } else {
            cloudDocumen.SM_Storage_Object_Key__c = pathS3;
        }

        return cloudDocumen;
      }

}