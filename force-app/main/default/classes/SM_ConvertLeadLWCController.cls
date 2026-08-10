/**
 * @description       : Helper class of convert lead process from button on lead object
 * @author            : jpachon@legal-credit.com
 * @group             : 
 * @last modified on  : 02-22-2021
 * @last modified by  : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   12-03-2020   jpachon@legal-credit.com   Initial Version
**/
public without sharing class SM_ConvertLeadLWCController {

    public static SM_ConvertLeadLWCController.ResultWrapper result;

    @AuraEnabled
    public static SM_ConvertLeadLWCController.ResultWrapper executeConvertLead(String leadId){
        result = new SM_ConvertLeadLWCController.ResultWrapper();
        try {
            Lead record = SM_ConvertLeadLWCHelper.getInfoLead(leadId);
            if (record == null) {
                result.setError('Error searching lead info');
            } else {
                // Call process to identify if exists any account created
                List<Account> accounts = SM_ConvertLeadLWCHelper.getDuplicatesAccountsByLead(record);
                result.setSuccess(record, accounts, null);
            }
        } catch (Exception e) {
            result.setError(e.getMessage());
        }
        System.debug('result: ' + JSON.serialize(result));
        return result;
    }

    @AuraEnabled
    public static SM_ConvertLeadLWCController.ResultWrapper convertLeadToAccount(String leadId, String companySettingId){
        result = new SM_ConvertLeadLWCController.ResultWrapper();
        Savepoint sp = Database.setSavePoint();
        try {
            Map<String, String> leadToAccountMap = SM_ConvertLeadLWCHelper.getFieldsMappingToConvertRecord(companySettingId, 'Lead', 'Account');
            if (!leadToAccountMap.isEmpty()) {
                Account newAccount = SM_ConvertLeadLWCHelper.createAccount(leadId, leadToAccountMap);
                Database.SaveResult sr = Database.insert(newAccount, false);
                if (sr.isSuccess()) {
                    setAccountInTrackingInbound(leadId, newAccount.Id);
                    result.accounts = new List<Account>{newAccount};
                    Map<String, String> leadToOppMap = SM_ConvertLeadLWCHelper.getFieldsMappingToConvertRecord(companySettingId, 'Lead', 'Opportunity');
                    Opportunity newOpp = SM_ConvertLeadLWCHelper.createOpportunity(leadId, newAccount.Id, companySettingId, leadToOppMap);
                    Database.SaveResult srOpp = Database.insert(newOpp, false);
                    if (srOpp.isSuccess()) {
                        //Update data from lead in opportunity
                        SM_ConvertLeadLWCHelper.copyLeadDataToOpportunity(leadId, newOpp.Id);
                        Database.LeadConvertResult lcr = convertIntoAccount(leadId, newAccount.Id);
                        if (lcr.isSuccess()) {
                            result.setSuccess(null, new List<Account>{newAccount}, newOpp);                            
                        } else {
                            Database.rollback(sp);
                            result.setError(getErrorMessages(lcr.getErrors()));
                        }
                    } else {
                        Database.rollback(sp);
                        result.setError(getErrorMessages(srOpp.getErrors()));
                    }
                } else {
                    Database.rollback(sp);
                    result.setError(getErrorMessages(sr.getErrors()));
                }
            } else {
                Database.rollback(sp);
                result.setError('There is no fields mapping to convertion process');
            }
        } catch (Exception e) {
            Database.rollback(sp);
            result.setError(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SM_ConvertLeadLWCController.ResultWrapper createOpportunity(String leadId, String accountId, String companySettingId){
        result = new SM_ConvertLeadLWCController.ResultWrapper();
        Savepoint sp = Database.setSavePoint();
        try {
            Map<String, String> leadToOppMap = SM_ConvertLeadLWCHelper.getFieldsMappingToConvertRecord(companySettingId, 'Lead', 'Opportunity');
            Opportunity newOpp = SM_ConvertLeadLWCHelper.createOpportunity(leadId, accountId, companySettingId, leadToOppMap);
            System.debug('createOpportunity - newOpp: ' + JSON.serialize(newOpp));
            Database.SaveResult sr = Database.insert(newOpp, false);
            if (sr.isSuccess()) {
                setAccountInTrackingInbound(leadId, accountId);
                SM_ConvertLeadLWCHelper.copyLeadDataToOpportunity(leadId, newOpp.Id);
                Database.LeadConvertResult lcr = convertIntoAccount(leadId, accountId);
                if (lcr.isSuccess()) {
                    result.setSuccess(null, null, newOpp);                    
                } else {
                    String errorMessage = getErrorMessages(lcr.getErrors());
                    //validate error type
                    if(errorMessage.contains('DUPLICATES_DETECTED')){
                        result.setSuccess(null, null, newOpp);
                    }else {
                        Database.rollback(sp);
                        result.setError(errorMessage);   
                    }
                }
            } else {
                Database.rollback(sp);
                result.setError(getErrorMessages(sr.getErrors()));
            }
        } catch (Exception e) {
            result.setError(e.getMessage());
        }
        return result;
    }

    @AuraEnabled
    public static SM_ConvertLeadLWCController.ResultWrapper updateTrackingInboundRecordsAndConvertLead(String leadId, String accountId, String opportunityId){
        result = new SM_ConvertLeadLWCController.ResultWrapper();
        Savepoint sp = Database.setSavePoint();
        try {
            setAccountInTrackingInbound(leadId, accountId);
            SM_ConvertLeadLWCHelper.copyLeadDataToOpportunity(leadId, opportunityId);
            Database.LeadConvertResult lcr = convertIntoAccount(leadId, accountId);
            if (lcr.isSuccess()) {
                result.setSuccess(null, null, null);
            } else {
                String errorMessage = getErrorMessages(lcr.getErrors());
                //validate error type
                if(errorMessage.contains('DUPLICATES_DETECTED')){
                    result.setSuccess(null, null, null);
                }else {
                    Database.rollback(sp);
                    result.setError(errorMessage);   
                }
            }
        } catch (Exception e) {
            result.setError(e.getMessage());
        }
        return result;
    }

    /**
    * @description This method update old data of account
    * @author diego.jacanamijoy@gmail.com | 01-06-2021 
    * @param leadId 
    * @param account 
    * @param companyName 
    **/
    @AuraEnabled
    public static void updateOldAccount(String leadId, Account account,String companyName, String opportunityId){
        Lead lead;
        Opportunity opp;
        try {
            //Get company setting
            SM_Company_setting__c companySetting = SM_CompanySettingHelper.getCompanySettingByName(companyName);
            //Get fields  to mapping Lead -> Account
            Map<String, String> leadToAccountMap = SM_ConvertLeadLWCHelper.getFieldsMappingToConvertRecord(companySetting.Id, 'Lead', 'Account');
            //Get fields  to mapping Lead -> Opportunity - SFDCMP-196
            Map<String, String> leadToOpportunityMap = SM_ConvertLeadLWCHelper.getFieldsMappingToConvertRecord(companySetting.Id, 'Lead', 'Opportunity');
            //Get Account
            String accountFields = String.join(leadToAccountMap.values(), ',') ;
            String accountQuery = 'SELECT ' + accountFields + ' FROM Account WHERE Id = \'' + account.Id + '\'';
            account = SM_AccountHelper.getAccountsByDinamicQuery(accountQuery)[0];
            // Get Oppoortunity - SFDCMP-196
            String opportunityFields = String.join(leadToOpportunityMap.values(), ',') ;
            String opportunityQuery = 'SELECT ' + opportunityFields + ' FROM Opportunity WHERE Id = \'' + opportunityId + '\'';
            opp = SM_OpportunityHelper.getOpportunitiesByDinamicQuery(opportunityQuery)[0];
            //Get Lead - SFDCMP-196            
            Set<String> leadSetFields = leadToAccountMap.keySet().clone();
            leadSetFields.addAll(leadToOpportunityMap.keySet());
            String leadFields = String.join(new List<String>(leadSetFields), ',') ;
            String leadQuery = 'SELECT ' + leadFields + ' FROM Lead WHERE Id = \'' + leadId + '\'';
            lead = SM_LeadHelper.getLeasByDinamicQuery(leadQuery)[0];
            //Update account
            SM_LeadHelper.updateOldRecord(lead, account, leadToAccountMap);
            update account;
            // Update opportunity - SFDCMP-196
            SM_LeadHelper.updateOldRecord(lead, opp, leadToOpportunityMap);
            update opp;
            
            //delete Lead
            delete new Lead(Id = leadId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static String getErrorMessages(List<Database.Error> errors) {
        List<String> errorMsg = new List<String>();
        for (Database.Error err : errors) {
            System.debug(err.getStatusCode() + ': ' + err.getMessage());
            errorMsg.add(err.getStatusCode() + ': ' + err.getMessage());
        }
        return String.join(errorMsg, ',');
    }

    private static void setAccountInTrackingInbound(String leadId, String accountId) {
        List<SM_Tracking_Inbound__c> recordsToUpdate = SM_ConvertLeadLWCHelper.getTrackingInboundToUpdate(leadId, accountId);
        if (!recordsToUpdate.isEmpty()) {
            List<Database.SaveResult> updatedRecords = Database.update(recordsToUpdate, false);
        }
    }

    private static Database.LeadConvertResult convertIntoAccount(String leadId, String accountId) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setAccountId(accountId);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus('Converted');
        return Database.convertLead(lc, false);
    }

    public class ResultWrapper {
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public Lead leadObj;
        @AuraEnabled
        public List<Account> accounts;
        @AuraEnabled
        public Opportunity opp;
        @AuraEnabled
        public String errorMessage;

        public void setError(String errorMessage) {
            this.isSuccess = false;
            this.errorMessage = errorMessage;
        }

        public void setSuccess(Lead leadObj, List<Account> accounts, Opportunity opp) {
            this.isSuccess = true;
            this.leadObj = leadObj;
            this.accounts = accounts;
            this.opp = opp;
        }
    }
}