/**
 * @description       : 
 * @author            : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
 * @group             : 
 * @last modified on  : 26/08/2022
 * @last modified by  : Diego Jacanamijoy -> djacanamijoy@legal-credit.com
**/
public with sharing class SM_UpsertInvoiceByPayment {

    private Map<String, SM_PaymentHelper.PaymentWrapper> paymentByCustomKey = new Map<String, SM_PaymentHelper.PaymentWrapper>();
    private Map<String, Invoice__c> invoiceByCustomKey = new Map<String, Invoice__c>();
    private List<Invoice__c> invoicesToUpsert = new List<Invoice__c>();
    private List<SM_PaymentHelper.PaymentWrapper> paymentWrappers = new List<SM_PaymentHelper.PaymentWrapper>();
    private Map<Id, SObject> newRecordsMap;
    
    public SM_UpsertInvoiceByPayment(Set<Id> paymentIds, Map<Id, SObject> newRecordsMap) {

        this.newRecordsMap = newRecordsMap;

        /** Get payment wrappers */
        paymentWrappers = SM_PaymentHelper.getPaymentWrappers(paymentIds);

        /** Create maps to proccess records */
        createMapsByCustomkey();

        /** Upsert invoices */
        upsertInvoices();

        /** Relate invoices to payments */
        updateInvoiceInPayment();

    }

    /**
    * @description This method Create maps to proccess records
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    **/
    private void createMapsByCustomkey() {

        Set<String> keysToSearchInvoices = new Set<String>();//Custom keys to search invoices

        for (SM_PaymentHelper.PaymentWrapper paymentWrap : paymentWrappers) {
            
            /** Set Installment_number__c */
            if (Trigger.isInsert) {
                paymentWrap.payment.Installment_number__c = generateInstallmentNumber(paymentWrap);   
            }

            /** Key to search Invoices */
            String key = generateKey(paymentWrap);

            keysToSearchInvoices.add(key);
            paymentByCustomKey.put(key, paymentWrap);
        }

        /** Search invoices by InvoiceID__c "Custom key" */
        searchInvoicesByKey(keysToSearchInvoices);

        /** Check invices to create */
        checkInvoicesToCreate(keysToSearchInvoices);
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 24/08/2022 
    * @param paymentWrap 
    * @return String 
    **/
    private String generateKey(SM_PaymentHelper.PaymentWrapper paymentWrap) {

        String auxSeparator = (String)paymentWrap.payment.SM_Type__c == 'AC' ? '-AC-' : '-';

        return paymentWrap.payment.SM_Contract__r.ContractNumber + auxSeparator + paymentWrap.payment.Installment_number__c;
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 12/08/2022 
    * @param paymentWrap 
    * @return Decimal 
    **/
    private Decimal generateInstallmentNumber(SM_PaymentHelper.PaymentWrapper paymentWrap) {

        /** Return value dependent payment type AC or others */
        return (String)paymentWrap.payment.SM_Type__c == 'AC' ? generateInstallmentNumberAC(paymentWrap) : generateInstallmentNumberDontAC(paymentWrap);
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 12/08/2022 
    * @param paymentWrap 
    * @return Decimal 
    **/
    private Decimal generateInstallmentNumberDontAC(SM_PaymentHelper.PaymentWrapper paymentWrap) {

        /** Validations about SM_Fee_to_collect__c field from ACH order or Chargent */
        Decimal feeToCollect = (Decimal)paymentWrap.achOrChargentObj.get('SM_Fee_to_collect__c');

        /** Chargent ya no se utiliza; se removio la validacion de SM_Chargent_Orders_Transaction__r */
        // return feeToCollect <> null && feeToCollect > 0 ? paymentWrap.payment.SM_Chargent_Orders_Transaction__r <> null ? feeToCollect : feeToCollect - 1 : 0;
        return feeToCollect <> null && feeToCollect > 0 ? feeToCollect - 1 : 0;
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 24/08/2022 
    * @param paymentWrap 
    * @return Decimal 
    **/
    private Decimal generateInstallmentNumberAC(SM_PaymentHelper.PaymentWrapper paymentWrap) {

        /** Aux variables from related contract to payment */
        Date splitDate = (Date)paymentWrap.payment.SM_Contract__r.SM_AC_Split_Date__c;
        Boolean paymentRecived = (Boolean)paymentWrap.payment.SM_Contract__r.SM_Payment_Received__c;
        Boolean acCollected = (Boolean)paymentWrap.payment.SM_Contract__r.SM_AC_collected__c;
        Decimal result = 0;//Result

        /** Validate data to determinate result */
        if (splitDate == null || (paymentRecived && !acCollected)) {
            result = 1;
        } else if (paymentRecived && acCollected) {
            result = 2;
        }

        return result;
    }

    /**
    * @description This method Search invoices by InvoiceID__c "Custom key"
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    * @param keysToSearchInvoices 
    **/
    private void searchInvoicesByKey(Set<String> keysToSearchInvoices) {

        /** Search invoices by InvoiceID__c "Custom key" */
        for (Invoice__c invoice : [SELECT Name, InvoiceID__c, Expected_payment_date__c FROM Invoice__c WHERE InvoiceID__c IN: keysToSearchInvoices]) {
            
            /** Update invoice with payment data */
            invoicesToUpsert.add(updateInvoiceDataByPayment(paymentByCustomKey.get(invoice.InvoiceID__c), invoice));

            /** Add invoices to map */
            invoiceByCustomKey.put(invoice.InvoiceID__c, invoice);
        }
    }

    /**
    * @description This method Check invices to create, if key there isn´t in invoice map
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    * @param keysToSearchInvoices 
    **/
    private void checkInvoicesToCreate(Set<String> keysToSearchInvoices) {

        /** Check invices to create, if key there isn´t in invoice map */
        for (String key : keysToSearchInvoices) {
            
            if (!invoiceByCustomKey.containsKey(key)) {
                
                /** Create invoice with payment data and InvoiceID__c = custom key */
                Invoice__c invoiceAux = updateInvoiceDataByPayment(paymentByCustomKey.get(key), new Invoice__c(InvoiceID__c = key));
                invoicesToUpsert.add(invoiceAux);
                invoiceByCustomKey.put(key, invoiceAux);
            }
        }
    }

    /**
    * @description This method update invoice data from payment
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    * @param paymentWrap 
    * @param invoice 
    **/
    private Invoice__c updateInvoiceDataByPayment(SM_PaymentHelper.PaymentWrapper paymentWrap, Invoice__c invoice) {

        Map<String, String> invoiceStatusByPayment = new map<String, String>{
            'ACH PENDING'  => 'UNPAID',
            'ACH TRANSMITTED' => 'TRASMITTED',
            'TRANSMITTED REFUND' => 'TRANSMITTED REFUND',
            'ACH PENDING REFUND' => 'PENDING  REFUND',
            'REJECTED REFUND' => 'REJECTED REFUND',
            'REJECTED' => 'UNPAID',
            'CANCELLED' => 'CANCELLED',
            'ACCEPTED' => 'PAID',
            'REFERRAL' => 'REFERAL',
            'REFUNDED' => 'REFUNDED' 
        };

        Map<Integer,String> monthNames = new Map<Integer,String>{
            1 => 'JAN',
            2 => 'FEB',
            3 => 'MAR',
            4 => 'APR',
            5 => 'MAY',
            6 => 'JUN',
            7 => 'JUL',
            8 => 'AUG',
            9 => 'SEP',
            10 => 'OCT',
            11 => 'NOV',
            12 => 'DEC'
        };

        SObject relatedObject = paymentWrap.achOrChargentObj;
        SM_Payment__c payment = paymentWrap.payment;
        String fieldAux = null;

        /** Update invoice data */
        invoice.Net_amount__c = payment.SM_Amount__c; 
        invoice.IVU_State_Amount__c = payment.SM_P_IVU_State_Amount__c;
        invoice.IVU_Municipal_Amount__c = payment.SM_P_IVU_Municipal_Amount__c;
        
        if (invoice.Id == null) {
            invoice.Contract__c = payment.SM_Contract__c;    
        }
        
        invoice.Type__c = payment.SM_Type__c <> 'Late payment fee' ? payment.SM_Type__c : '';
        invoice.Penalty_value__c = payment.SM_Penalty_value__c;
        invoice.Fee_value__c = payment.SM_Fee_value__c;
        invoice.Status__c = invoiceStatusByPayment.get((String)this.newRecordsMap.get(payment.Id).get('Payment_Status__c'));
        invoice.Installment_number__c = payment.Installment_number__c;
        invoice.Payment_Method__c = payment.SM_Payment_Method__c;
        invoice.Billing_Email__c = payment.SM_Contract__r.SM_Email_to_send_contract__c;
        invoice.Approval_status__c = (String)relatedObject.get('SM_Approval_status__c');

        /** Fields with special validations */
        if (!invoice.isSet('Expected_payment_date__c') || invoice.Expected_payment_date__c == null) {
            invoice.Expected_payment_date__c = payment.SM_Payment_Date__c;
        }

        if (payment.Payment_Status__c == 'ACCEPTED') {
            invoice.Date_of_payment_received__c = payment.SM_Payment_Date__c;
        }

        fieldAux = getFieldByObject(relatedObject, 'Next_scheduled_payment_date__c');
        if ((String)relatedObject.get('SM_Payment_Type__c') == 'Late payment fee') {
            invoice.Next_scheduled_payment_date__c = (Date)relatedObject.get(fieldAux);
        }

        if (payment.SM_Failed_payment__c <> null) {
            invoice.Failed_payment__c = payment.SM_Failed_payment__c;
        }

        if ((Boolean)relatedObject.get('SM_Apply_penalty__c')) {
            invoice.Apply_penalty__c = true;
        }

        if (relatedObject.get('SM_Penalty_date__c') <> null) {

            /** Check Date or DateTime instance */
            if (relatedObject.get('SM_Penalty_date__c') instanceof Date) {
                invoice.Penalty_date__c = (Date)relatedObject.get('SM_Penalty_date__c');
            } else {
                Datetime auxdateTime = (DateTime)relatedObject.get('SM_Penalty_date__c');
                invoice.Penalty_date__c = auxdateTime.date();
            }
            
        }

        if ((String)relatedObject.get('SM_Reason_to_approve_exoneration__c') <> null) {
            invoice.Reason_to_approve_exoneration__c = (String)relatedObject.get('SM_Reason_to_approve_exoneration__c');
        }

        fieldAux = getFieldByObject(relatedObject, 'User_who_applies_the_penalty__c');
        if (fieldAux <> null) {
            invoice.User_who_applies_the_penalty__c = (Id)relatedObject.get(fieldAux);
        }

        /** Set name */
        if (String.isBlank(invoice.Name)) {

            String monthPrefix = invoice.Expected_payment_date__c <> null ? monthNames.get(invoice.Expected_payment_date__c.month()) : '';
            String year = invoice.Expected_payment_date__c <> null ? String.valueOf(invoice.Expected_payment_date__c.year()) : '';
            
            invoice.Name = invoice.Installment_number__c + '-' + monthPrefix + '-' + year;
        }

        return invoice;
    }

    /**
    * @description 
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 11/08/2022 
    * @param relatedObject 
    * @param invoiceField 
    * @return String 
    **/
    private String getFieldByObject(SObject relatedObject, String invoiceField) {

        String SOBJECT_TYPE = SM_Utils.getSObjectNameById((Id)relatedObject.get('Id'));
        String ACH_ORDER_TYPE = SM_ACH_Order__c.getSObjectType().getDescribe().getName();

        //calp Aug 2026 :: CHARGENT app is permanently disabled for this org; removed the
        //hardcoded ChargentOrders__ChargentOrder__c type reference that ran on every payment.
        /** Map fields from ACH Order */
        Map<String, String> fieldByInvoiceField = new Map<String, String>{
            ACH_ORDER_TYPE + '_' + 'User_who_applies_the_penalty__c' => 'SM_User_who_applies_the_penalty__c',
            ACH_ORDER_TYPE + '_' + 'Next_scheduled_payment_date__c' => 'SM_Payment_Start_Date__c'
        };

        return fieldByInvoiceField.get(SOBJECT_TYPE + '_' + invoiceField);
    }

    /**
    * @description This method upsert invoices
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    **/
    private void upsertInvoices() {

        if (!invoicesToUpsert.isEmpty()) {
            upsert invoicesToUpsert;
        }
    }

    /**
    * @description This method Search and relate invoice to payment
    * @author Diego Jacanamijoy -> djacanamijoy@legal-credit.com | 10/08/2022 
    **/
    private void updateInvoiceInPayment() {

        List<SM_Payment__c> paymentsToUpdate = new List<SM_Payment__c>();//Payment list to update

        /** Search and relate invoice to payment */
        for (String key : paymentByCustomKey.keySet()) {
            
            /** Check invoice map */
            if (invoiceByCustomKey.containsKey(key)) {

                /** Update value in transaction map */
                SM_Payment__c payment = Trigger.isInsert ? paymentByCustomKey.get(key).payment : (SM_Payment__c)this.newRecordsMap.get(paymentByCustomKey.get(key).payment.Id);
                payment.Installment_number__c = paymentByCustomKey.get(key).payment.Installment_number__c;
                /** Relate invoice to payment */
                payment.Invoice__c = invoiceByCustomKey.get(key).Id;

                paymentsToUpdate.add(payment);
            }
        }

        /** Check records to update */
        if (!paymentsToUpdate.isEmpty() && Trigger.isInsert) {
            update paymentsToUpdate;
        }
    }
}