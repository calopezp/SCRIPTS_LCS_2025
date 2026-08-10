/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
@IsTest
public with sharing class SM_UpsertInvoiceByPaymentTest {
    
    @TestSetup
    static void makeData(){

        insert new SM_Bypasser__c(SM_Disable_Validation_Rules__c = false, SetupOwnerId = UserInfo.getProfileId());
        
        /** Insert Account */
        Account account = SM_TestSmartDataFactory.getPersonAccount();
            account.PersonEmail='legal_credit@gmail.com.invalid';
            insert account;

        /** Create master contract */
        Contract master = new Contract(
            AccountId = account.Id,
            Status = 'Draft',
            StartDate = Date.today(),
            ContractTerm = 8,
            Contract_Type__c = 'Master',
            Collection_Main_Contract__c = 'Pending data capture',
            SM_Total_ac__c = 45.68
        );
        insert master;
    }

    @IsTest
    static void clonePaymentsByAchOrderOk(){

        Contract master = [SELECT SM_Total_ac__c, ContractNumber FROM Contract WHERE Contract_Type__c = 'Master' limit 1];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'Late payment fee',
            SM_Next_Transaction_Date__c = System.toDay(),
            SM_Penalty_date__c = System.toDay().addDays(4),
            SM_Payment_Start_Date__c = System.toDay().addDays(2),
            SM_Apply_penalty__c = true,
            SM_Reason_to_approve_exoneration__c = 'Family Emergency'
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 2,
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED,
            SM_Payment_Date__c = Date.newInstance(2022, 8, 25)
        );
        

        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        masterPayment = [SELECT Installment_number__c, Invoice__c FROM SM_Payment__c WHERE Id =: masterPayment.Id];

        List<Invoice__c> invoices = [ SELECT 
                                            Name, Net_amount__c, IVU_State_Amount__c, IVU_Municipal_Amount__c, Contract__c, Penalty_date__c, 
                                            Type__c, Penalty_value__c, Fee_value__c, Status__c, Installment_number__c, Apply_penalty__c, Reason_to_approve_exoneration__c, 
                                            Payment_Method__c, Billing_Email__c, Approval_status__c, InvoiceID__c, Next_scheduled_payment_date__c
                                        FROM Invoice__c];

        System.assertEquals(1, invoices.size(), 'Must be return one invoice record');
        String customKey = master.ContractNumber + '-' + masterPayment.Installment_number__c;
        System.assertEquals(customKey, invoices[0].InvoiceID__c, 'Invoice don´t updated');
        System.assertEquals('PAID', invoices[0].Status__c, 'Invoice status don´t updated');
        //System.assertEquals(System.toDay().addDays(2), invoices[0].Next_scheduled_payment_date__c, 'Invoice Next_scheduled_payment_date__c don´t updated');
        System.assertEquals(System.toDay().addDays(4), invoices[0].Penalty_date__c, 'Invoice Penalty_date__c don´t updated');
        System.assertEquals(true, invoices[0].Apply_penalty__c, 'Invoice Apply_penalty__c don´t updated');
        System.assertEquals('Family Emergency', invoices[0].Reason_to_approve_exoneration__c, 'Invoice Reason_to_approve_exoneration__c don´t updated');

        /** Check payment data */
        System.assertEquals(invoices[0].Id, masterPayment.Invoice__c, 'Invoice don´t related in payment');
       // System.assertEquals(invoices[0].Installment_number__c + '-' + 'AUG' + '-2022', invoices[0].Name, 'Invoice don´t related in payment');
    }

    @IsTest
    static void clonePaymentsByAchOrderFromACOk(){

        Contract master = [SELECT SM_Total_ac__c, ContractNumber FROM Contract WHERE Contract_Type__c = 'Master' limit 1];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'AC',
            SM_Next_Transaction_Date__c = System.toDay(),
            SM_Penalty_date__c = System.toDay().addDays(4),
            SM_Payment_Start_Date__c = System.toDay().addDays(2),
            SM_Apply_penalty__c = true,
            SM_Reason_to_approve_exoneration__c = 'Family Emergency'
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 2,
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED,
            SM_Type__c = 'AC'
        );
        

        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        masterPayment = [SELECT Installment_number__c, Invoice__c FROM SM_Payment__c WHERE Id =: masterPayment.Id];

        List<Invoice__c> invoices = [ SELECT 
                                            Net_amount__c, IVU_State_Amount__c, IVU_Municipal_Amount__c, Contract__c, Penalty_date__c, 
                                            Type__c, Penalty_value__c, Fee_value__c, Status__c, Installment_number__c, Apply_penalty__c, Reason_to_approve_exoneration__c, 
                                            Payment_Method__c, Billing_Email__c, Approval_status__c, InvoiceID__c, Next_scheduled_payment_date__c
                                        FROM Invoice__c];

        System.assertEquals(1, invoices.size(), 'Must be return one invoice record');
        String customKey = master.ContractNumber + '-AC-' + masterPayment.Installment_number__c;
        System.assertEquals(customKey, invoices[0].InvoiceID__c, 'Invoice don´t updated');
        System.assertEquals('PAID', invoices[0].Status__c, 'Invoice status don´t updated');
        System.assertEquals('AC', invoices[0].Type__c, 'Invoice Type__c don´t updated');
        System.assertEquals(System.toDay().addDays(4), invoices[0].Penalty_date__c, 'Invoice Penalty_date__c don´t updated');
        System.assertEquals(true, invoices[0].Apply_penalty__c, 'Invoice Apply_penalty__c don´t updated');
        System.assertEquals('Family Emergency', invoices[0].Reason_to_approve_exoneration__c, 'Invoice Reason_to_approve_exoneration__c don´t updated');

        /** Check payment data */
        System.assertEquals(invoices[0].Id, masterPayment.Invoice__c, 'Invoice don´t related in payment');
    }

    @IsTest
    static void clonePaymentsByAchOrderUpdateOk(){

        Contract master = [SELECT SM_Total_ac__c, ContractNumber FROM Contract WHERE Contract_Type__c = 'Master' limit 1];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'AC',
            SM_Next_Transaction_Date__c = System.toDay(),
            SM_Penalty_date__c = System.toDay().addDays(4),
            SM_Payment_Start_Date__c = System.toDay().addDays(2),
            SM_Apply_penalty__c = true,
            SM_Reason_to_approve_exoneration__c = 'Family Emergency'
        );
        insert achOrder;

         /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 2,
            Payment_Status__c = 'ACH PENDING',
            SM_Type__c = 'AC'
        );
        insert masterPayment;
        

        Test.startTest();
            masterPayment.Payment_Status__c = 'TRANSMITTED REFUND';
            update masterPayment;
        Test.stopTest();

        masterPayment = [SELECT Installment_number__c, Invoice__c FROM SM_Payment__c WHERE Id =: masterPayment.Id];

        List<Invoice__c> invoices = [ SELECT 
                                            Net_amount__c, IVU_State_Amount__c, IVU_Municipal_Amount__c, Contract__c, Penalty_date__c, 
                                            Type__c, Penalty_value__c, Fee_value__c, Status__c, Installment_number__c, Apply_penalty__c, Reason_to_approve_exoneration__c, 
                                            Payment_Method__c, Billing_Email__c, Approval_status__c, InvoiceID__c, Next_scheduled_payment_date__c
                                        FROM Invoice__c];

        System.assertEquals(1, invoices.size(), 'Must be return one invoice record');
        String customKey = master.ContractNumber + '-AC-' + masterPayment.Installment_number__c;
        System.assertEquals(customKey, invoices[0].InvoiceID__c, 'Invoice don´t updated');
        System.assertEquals('AC', invoices[0].Type__c, 'Invoice Type__c don´t updated');
        System.assertEquals(System.toDay().addDays(4), invoices[0].Penalty_date__c, 'Invoice Penalty_date__c don´t updated');
        System.assertEquals(true, invoices[0].Apply_penalty__c, 'Invoice Apply_penalty__c don´t updated');
        System.assertEquals('Family Emergency', invoices[0].Reason_to_approve_exoneration__c, 'Invoice Reason_to_approve_exoneration__c don´t updated');
        System.assertEquals('TRANSMITTED REFUND', invoices[0].Status__c, 'Invoice Status__c don´t updated');

        /** Check payment data */
        System.assertEquals(invoices[0].Id, masterPayment.Invoice__c, 'Invoice don´t related in payment');
    }

    @IsTest
    static void checkInstallmentNumberACHDontAC(){

        Contract master = [SELECT SM_Total_ac__c, ContractNumber FROM Contract WHERE Contract_Type__c = 'Master' limit 1];

        /** Create ACH order */
        SM_ACH_Order__c achOrder = new SM_ACH_Order__c(
            SM_Contract__c = master.Id,
            SM_Payment_Type__c = 'Late payment fee',
            SM_Next_Transaction_Date__c = System.toDay(),
            SM_Penalty_date__c = System.toDay().addDays(4),
            SM_Payment_Start_Date__c = System.toDay().addDays(2),
            SM_Apply_penalty__c = true,
            SM_Reason_to_approve_exoneration__c = 'Family Emergency'
        );
        insert achOrder;

        /** Create payment to master */
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_ACH_Order__c = achOrder.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Installment_number__c = 2,
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED,
            SM_Type__c = 'Late payment fee'
        );
        

        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        achOrder = [SELECT SM_Fee_to_collect__c FROM SM_ACH_Order__c WHERE Id =: achOrder.Id];

        masterPayment = [SELECT Installment_number__c, Invoice__c FROM SM_Payment__c WHERE Id =: masterPayment.Id];

       // System.assertEquals(achOrder.SM_Fee_to_collect__c - 1, masterPayment.Installment_number__c, 'Installment_number__c don´t correct');
        
    }

    /* Chargent ya no se utiliza; se removio el flujo de SM_Chargent_Orders_Transaction__c en generateInstallmentNumberDontAC
    @IsTest
    static void checkInstallmentNumberChargentDontAC(){

        Contract master = [SELECT SM_Total_ac__c, ContractNumber FROM Contract WHERE Contract_Type__c = 'Master' limit 1];

        Create chargent
        ChargentOrders__ChargentOrder__c chargent = new ChargentOrders__ChargentOrder__c(
                ChargentOrders__Payment_Frequency__c = 'Once',
                ChargentOrders__Payment_Method__c = 'Credit Card',
                ChargentOrders__Tokenization__c = '1929826725-1841993424',
                SM_Payment_Type__c = 'Late payment fee',
                Contract__c = master.Id
        );
        insert chargent;

        Create Chargent transaction
        ChargentOrders__Transaction__c chargentTransaction = new ChargentOrders__Transaction__c(
            ChargentOrders__Type__c = 'Authorization',
            ChargentOrders__Response_Status__c = 'Approved',
            ChargentOrders__Tokenization__c = '091-29382-298292829229',
            Contract__c = master.Id,
            ChargentOrders__Order__c = chargent.Id
        );
        insert chargentTransaction;

         Create payment to master
         SM_Payment__c masterPayment = new SM_Payment__c(
            SM_Amount__c = 35,
            SM_Contract__c = master.Id,
            SM_Chargent_Orders_Transaction__c = chargentTransaction.Id,
            SM_Penalty_value__c = 10.68,
            SM_Fee_value__c = 10.68,
            Payment_Status__c = SM_PaymentHelper.status.ACCEPTED
        );


        Test.startTest();
            insert masterPayment;
        Test.stopTest();

        chargent = [SELECT SM_Fee_to_collect__c FROM ChargentOrders__ChargentOrder__c WHERE Id =: chargent.Id];

        masterPayment = [SELECT Installment_number__c, Invoice__c FROM SM_Payment__c WHERE Id =: masterPayment.Id];

        System.assertEquals(chargent.SM_Fee_to_collect__c, masterPayment.Installment_number__c, 'Installment_number__c don´t correct');

    }
    */
}