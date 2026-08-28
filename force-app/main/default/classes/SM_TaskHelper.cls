/**
 * @description       :
 * @author            : Jonathan S. Pachon Ariza -> jpachon@legal-credit.com
 * @group             :
 * @last modified on  : 10-28-2022
 * @last modified by  : Jonathan S. Pachon (JSPA)
 * Modifications Log
 * Ver   Date         Author                                                 Modification
 * 1.0   01-15-2021   Jonathan S. Pachon Ariza -> jpachon@legal-credit.com   Initial Version
**/
public without sharing class SM_TaskHelper {

    private static String processRT = SM_Utils.getRecordTypeIdByDeveloperName('Task', 'Process');
    public static RecordTypeEnum recordType = new RecordTypeEnum();
    public static StatusEnum status = new StatusEnum();

    // This class represents Enum to record type attribute (Developer name)
    public class RecordTypeEnum {
        public String five9 = 'Five9';
        public String reminder = 'Reminder';
    }

    // This class represents Enum to status attribute (Developer name)
    public class StatusEnum {
        public String open = 'Open';
        public String completed = 'Completed';
    }

    public static void createTaskToValidateErrorInUpgradedContract(String description) {
        String username = [SELECT Id FROM User WHERE Username =: System.label.UPGRADED_CONTRACT_TASK_OWNER_USERNAME]?.Id;
        String ownerId = String.isNotBlank(username) ? username : UserInfo.getUserId();
        Task taskToValidateError = new Task(
            OwnerId = ownerId,
            Subject = System.label.UPGRADED_CONTRACT_SUBJECT_TASK,
            Status = SM_TaskHelper.status.open,
            RecordTypeId = processRT,
            Priority = 'High',
            Description = description
        );
        insert taskToValidateError;
    }

    public static void createTaskToValidateErrorInUpgradedContract(String description, String contractId) {
        String username = [SELECT Id FROM User WHERE Username =: System.label.UPGRADED_CONTRACT_TASK_OWNER_USERNAME]?.Id;
        String ownerId = String.isNotBlank(username) ? username : UserInfo.getUserId();
        Task taskToValidateError = new Task(
            OwnerId = ownerId,
            Subject = System.label.UPGRADED_CONTRACT_SUBJECT_TASK,
            Status = SM_TaskHelper.status.open,
            RecordTypeId = processRT,
            Priority = 'High',
            Description = description,
            WhatId = contractId
        );
        insert taskToValidateError;
    }

}