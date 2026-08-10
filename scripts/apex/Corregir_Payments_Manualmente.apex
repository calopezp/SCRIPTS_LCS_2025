// Solución Manual: Modificar los 4 Payments para prevenir errores futuros
// Al cambiar SM_Receipt_Status__c, estos Payments NO serán procesados por el batch

System.debug('=====================================');
System.debug('CORRECCIÓN MANUAL DE PAYMENTS');
System.debug('=====================================');
System.debug('');

// Los 4 Payments que causaron el error
List<String> paymentIds = new List<String>{
    'a24UU000004PuHeYAK', // PY-01828866
    'a24UU000004Psm5YAC', // PY-01828865
    'a24UU000004PsPVYA0', // PY-01828864
    'a24UU000004PrV3YAK'  // PY-01828863
};

System.debug('Payments a corregir: ' + paymentIds.size());
System.debug('');

// Consultar los Payments actuales
List<SM_Payment__c> paymentsBeforeUpdate = [
    SELECT Id, Name,
           RecordType.DeveloperName,
           SM_ACH_Order__c,
           Payment_Status__c,
           SM_Receipt_Status__c,
           SM_Type__c,
           SM_Amount__c
    FROM SM_Payment__c
    WHERE Id IN :paymentIds
];

System.debug('========================================');
System.debug('ESTADO ANTES DE LA CORRECCIÓN');
System.debug('========================================');
for (SM_Payment__c p : paymentsBeforeUpdate) {
    System.debug('');
    System.debug('Payment: ' + p.Name);
    System.debug('  RecordType: ' + p.RecordType.DeveloperName);
    System.debug('  SM_ACH_Order__c: ' + p.SM_ACH_Order__c);
    System.debug('  Payment_Status__c: ' + p.Payment_Status__c);
    System.debug('  SM_Receipt_Status__c: ' + p.SM_Receipt_Status__c);
    System.debug('  SM_Type__c: ' + p.SM_Type__c);
    System.debug('  SM_Amount__c: ' + p.SM_Amount__c);
}

System.debug('');
System.debug('========================================');
System.debug('APLICANDO CORRECCIÓN');
System.debug('========================================');

// SOLUCIÓN: Cambiar SM_Receipt_Status__c para que el batch no los procese
List<SM_Payment__c> paymentsToUpdate = new List<SM_Payment__c>();

for (String paymentId : paymentIds) {
    SM_Payment__c payment = new SM_Payment__c(
        Id = paymentId,
        SM_Receipt_Status__c = 'SENT' // Marcar como enviado para excluir del batch
    );
    paymentsToUpdate.add(payment);
}

// Ejecutar el update
try {
    update paymentsToUpdate;
    System.debug('✅ SUCCESS: ' + paymentsToUpdate.size() + ' Payments actualizados correctamente');
    System.debug('');
    
    // Verificar el resultado
    List<SM_Payment__c> paymentsAfterUpdate = [
        SELECT Id, Name,
               RecordType.DeveloperName,
               SM_Receipt_Status__c,
               Payment_Status__c
        FROM SM_Payment__c
        WHERE Id IN :paymentIds
    ];
    
    System.debug('========================================');
    System.debug('ESTADO DESPUÉS DE LA CORRECCIÓN');
    System.debug('========================================');
    for (SM_Payment__c p : paymentsAfterUpdate) {
        System.debug('');
        System.debug('Payment: ' + p.Name);
        System.debug('  RecordType: ' + p.RecordType.DeveloperName);
        System.debug('  SM_Receipt_Status__c: ' + p.SM_Receipt_Status__c + ' ✅');
        System.debug('  Payment_Status__c: ' + p.Payment_Status__c);
    }
    
    System.debug('');
    System.debug('========================================');
    System.debug('RESUMEN');
    System.debug('========================================');
    System.debug('✅ Los 4 Payments han sido marcados con SM_Receipt_Status__c = "SENT"');
    System.debug('✅ Estos Payments YA NO serán procesados por el batch SM_PaymentBatch');
    System.debug('✅ No causarán más errores "Argument cannot be null"');
    System.debug('');
    System.debug('IMPORTANTE:');
    System.debug('- Esta es una solución temporal para estos 4 Payments específicos');
    System.debug('- Futuros Payments Credit Card SIN validación en el trigger causarán el mismo error');
    System.debug('- La solución definitiva requiere modificar el trigger SM_PaymentHandler');
    
} catch (Exception e) {
    System.debug('❌ ERROR al actualizar Payments:');
    System.debug('  Mensaje: ' + e.getMessage());
    System.debug('  Línea: ' + e.getLineNumber());
    System.debug('  Stack: ' + e.getStackTraceString());
}

System.debug('');
System.debug('=====================================');
System.debug('FIN CORRECCIÓN');
System.debug('=====================================');