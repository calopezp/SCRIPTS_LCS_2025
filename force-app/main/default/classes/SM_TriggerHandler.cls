/**
 * @description       : 
 * @author            : diego.jacanamijoy@gmail.com
 * @group             : 
 * @last modified on  : 07/10/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   11-19-2020   diego.jacanamijoy@gmail.com   Initial Version
**/
@SuppressWarnings('PMD.EmptyStatementBlock,PMD.ApexCRUDViolation')
public without sharing virtual class SM_TriggerHandler {

    public SM_Trigger_Panel__mdt triggerpanel;//Instance of metadata
    public static Boolean avoidAllHandlerExcecution = false;

    
    /**
    * @description Constructor of class
    * @author diego.jacanamijoy@gmail.com | 11-19-2020 
    * @param 
    **/
    public SM_TriggerHandler() {}

    /**
    * @description Constructor of class
    * @author diego.jacanamijoy@gmail.com | 11-19-2020 
    * @param triggerName 
    **/
    public SM_TriggerHandler(String triggerName) {
        getTriggerPanel(triggerName);
    }

    
    /**
    * @description This method get metadata by trigger name
    * @author diego.jacanamijoy@gmail.com | 11-19-2020 
    * @param triggerName 
    **/
    public void getTriggerPanel(String triggerName){
        try {
            triggerpanel =  [SELECT SM_ProcessOnAfterDelete__c, SM_ProcessOnAfterInsert__c, SM_ProcessOnAfterUpdate__c, 
                                SM_ProcessOnBeforeDelete__c, SM_ProcessOnBeforeInsert__c, SM_ProcessOnBeforeUpdate__c, SM_ProcessOnUnDelete__c
                        FROM SM_Trigger_Panel__mdt 
                        WHERE SM_TriggerName__c =: triggerName 
                        LIMIT 1];    
        } catch (DmlException e) {
            triggerpanel = null;
        }
    }

    /**
    * @description main method that will be called during execution
    * @author diego.jacanamijoy@gmail.com | 11-19-2020 
    **/
    @SuppressWarnings('PMD.CyclomaticComplexity')
    public void run() {
        // dispatch to the correct handler method
        if(Trigger.isExecuting && triggerpanel <> null && !avoidAllHandlerExcecution){
            if(triggerpanel.SM_ProcessOnBeforeInsert__c && Trigger.isInsert && Trigger.isBefore) {
                this.beforeInsert();
                this.asyncBeforeInsert();
            } else if(triggerpanel.SM_ProcessOnBeforeUpdate__c && Trigger.isUpdate && Trigger.isBefore) {
                this.beforeUpdate();
                this.asyncBeforeUpdate();
            } else if(triggerpanel.SM_ProcessOnBeforeDelete__c && Trigger.isDelete && Trigger.isBefore) {
                this.beforeDelete();
            } else if(triggerpanel.SM_ProcessOnAfterInsert__c && Trigger.isInsert && Trigger.isAfter) {
                this.afterInsert();
                this.asyncAfterInsert();
            } else if(triggerpanel.SM_ProcessOnAfterUpdate__c && Trigger.isUpdate && Trigger.isAfter) {
                this.afterUpdate();
                this.asyncAfterUpdate();
            } else if(triggerpanel.SM_ProcessOnAfterDelete__c && Trigger.isDelete && Trigger.isAfter) {
                this.afterDelete();
            } else if(triggerpanel.SM_ProcessOnUnDelete__c && Trigger.isUnDelete) {
                this.afterUndelete();
            }
        }
    }

    /** context-specific methods for override **/
    public virtual void beforeInsert(){}
    public virtual void beforeUpdate(){}
    public virtual void beforeDelete(){}
    public virtual void afterInsert(){}
    public virtual void afterUpdate(){}
    public virtual void afterDelete(){}
    public virtual void afterUndelete(){}
    //Asynchronous methods
    public virtual void asyncBeforeInsert(){}
    public virtual void asyncAfterInsert(){}
    public virtual void asyncBeforeUpdate(){}
    public virtual void asyncAfterUpdate(){}

}