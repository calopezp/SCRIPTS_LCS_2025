// CREAR EL PAYMETN PRO CONTRACARGO
/*  Dato de Ingreso el codigo de autorizacion EXACTO, con este busca el transaction aprobado y genera un payment con esos datos en NEGATIVO
    - El código de autorización se encuentra en el campo ChargentOrders__Authorization__c del objeto ChargentOrders__Transaction__c, por lo que se debe buscar un registro con ese valor.

                SELECT
                RecordTypeId,              //Credit Card
                Payment_Status__c,  //REFUNDED
                SM_Reason_for_refund__c,  //CONTRA CARGO
                SM_Contract__c,        // ME
                SM_Amount__c,        // *-1
                SM_Payments_refunded__c, // ESTE PAYMETN ID
                SM_Type__c,                              // ME
                SM_Original_Type__c,            // ME
                SM_Penalty_value__c ,           // ME      *-1
                SM_Fee_value__c,                 // ME      *-1

                Id, Name, SM_Payment_Due_Date__c  , SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__c
                FROM SM_Payment__c
                WHERE SM_Chargent_Orders_Transaction__c IN (SELECT Id
                FROM ChargentOrders__Transaction__c
                WHERE ChargentOrders__Authorization__c = '802051')
*/

STRING AutorizacionCode = '802051'; // Código de autorización a buscar

List<SM_Payment__c> paymentOriginal = [
    SELECT
        // Datos para el nuevo Payment (CONTRACARGO)
        RecordTypeId,                                   //Credit Card
        Payment_Status__c,                              //REFUNDED
        SM_Reason_for_refund__c,                        //CONTRA CARGO
        SM_Contract__c,                                 
        SM_Amount__c,                                   // *-1
        SM_Payments_refunded__c,                        // ID DE ESTE PAYMENT
        SM_Type__c,
        SM_Original_Type__c,
        SM_Penalty_value__c ,                           // *-1
        SM_Fee_value__c,                                //*-1
        SM_Payment_Due_Date__c,
        SM_Payment_Date__c,
        SM_Payment_execution_date__c,
        // DATOS PARA CONSULTA Y VERIFICACIÓN
        Id,                                             // SE DEBE REGISTRAR EN SM_Payments_refunded__c
        Name, SM_Chargent_Orders_Transaction__r.ChargentOrders__Order__c, SM_Chargent_Orders_Transaction__r.ChargentOrders__Card_Last_4__c
        
                FROM SM_Payment__c
                WHERE SM_Chargent_Orders_Transaction__c IN (
                        SELECT Id FROM ChargentOrders__Transaction__c WHERE ChargentOrders__Authorization__c = :AutorizacionCode)
];

if (paymentOriginal.isEmpty()) {
    System.debug(' → ❌ No se encontró ningún pago con el código de autorización proporcionado.');
} else {
    System.debug(' → ✅ Pago encontrado ' + ' Fecha Cobro ' + '            Monto   ' + '     Últimas 4 ' + '      Autorización ' + ' Payment Date ');
    System.debug(' →     ' + paymentOriginal[0].Name + '       ' + paymentOriginal[0].SM_Payment_execution_date__c.date() + '     ' + paymentOriginal[0].SM_Amount__c + '        ' + paymentOriginal[0].SM_Chargent_Orders_Transaction__r.ChargentOrders__Card_Last_4__c + '         ' + AutorizacionCode + '       ' + paymentOriginal[0].SM_Payment_Date__c.date());
    
    // Aquí se debe crear el nuevo Payment con los datos obtenidos, asegurándose de que el monto sea negativo y que se relacione correctamente con el contrato y la transacción original.

    SM_Payment__c newPayment = new SM_Payment__c();
        newPayment.RecordTypeId = paymentOriginal[0].RecordTypeId; // Credit Card
        newPayment.Payment_Status__c = 'REFUNDED';
        newPayment.SM_Reason_for_refund__c = 'CONTRA CARGO';
        newPayment.SM_Contract__c = paymentOriginal[0].SM_Contract__c;
        newPayment.SM_Amount__c = paymentOriginal[0].SM_Amount__c * -1; // Monto en negativo
        newPayment.SM_Payments_refunded__c = paymentOriginal[0].Id; // Relación con el pago original
        newPayment.SM_Type__c = paymentOriginal[0].SM_Type__c;
        newPayment.SM_Original_Type__c = paymentOriginal[0].SM_Original_Type__c;
        newPayment.SM_Penalty_value__c = paymentOriginal[0].SM_Penalty_value__c * -1; // Penalty en negativo
        newPayment.SM_Fee_value__c = paymentOriginal[0].SM_Fee_value__c * -1; // Fee en negativo
        newPayment.SM_Payment_Due_Date__c = paymentOriginal[0].SM_Payment_execution_date__c.date(); // Fecha de ejecución del contracargo (puede ajustarse según necesidades)
        newPayment.SM_Is_Migrated__c = true;
        newPayment.SM_Payment_Date__c = paymentOriginal[0].SM_Payment_execution_date__c.date(); // Fecha del contracargo (puede ajustarse según necesidades)
    insert newPayment;

// 🔄 Actualización posterior al insert
SM_Payment__c upd = new SM_Payment__c(
    Id = newPayment.Id,
    SM_Payment_Due_Date__c = paymentOriginal[0].SM_Payment_execution_date__c.date(),
    SM_Is_Migrated__c = true,
    SM_Payment_Date__c = paymentOriginal[0].SM_Payment_execution_date__c.date()
);

update upd;

// 🔍 Recuperar el Name del nuevo Payment
SM_Payment__c newPaymentFull = [
    SELECT Id, Name
    FROM SM_Payment__c
    WHERE Id = :newPayment.Id
    LIMIT 1
];

System.debug(' → ✅ Nuevo pago de contracargo creado: ID = ' + newPaymentFull.Id + ' • Name = ' + newPaymentFull.Name);
}


