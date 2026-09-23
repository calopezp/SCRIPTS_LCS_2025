// ============================================================
//  Diagnostico + fix aislado: 5 contratos donde CancelarContratosRunner
//  reporto OK en Chargebee (invoices VOIDED + Subscription CANCELLED,
//  ya verificado en vivo, NO se repite ese callout) pero el Contract en
//  Salesforce se quedo sin Status=Cancelled / Reason / Fecha. Un registro
//  por DML (no bulk) para aislar el error real, no el bulk-masking.
// ============================================================

Map<String, Date> contractDates = new Map<String, Date>{
    '00317881' => Date.newInstance(2026, 9, 11),
    '00317928' => Date.newInstance(2026, 9, 11),
    '00317948' => Date.newInstance(2026, 9, 11),
    '00317970' => Date.newInstance(2026, 9, 11),
    '00318036' => Date.newInstance(2026, 9, 11)
};
String reason = 'Does not comply with Payments';

List<Contract> contracts = [
    SELECT Id, ContractNumber, Status, SM_Reason_for_cancellation__c, SM_Cancellation_Date__c
    FROM Contract WHERE ContractNumber IN :contractDates.keySet()
];

for (Contract c : contracts) {
    System.debug('--- ' + c.ContractNumber + ' ---');
    try {
        Contract upd = new Contract(
            Id                             = c.Id,
            Status                         = 'Cancelled',
            SM_Reason_for_cancellation__c  = reason,
            SM_Cancellation_Date__c        = contractDates.get(c.ContractNumber)
        );
        update upd;
        System.debug('OK: Status+Reason+Fecha actualizados en un solo DML.');
    } catch (Exception e) {
        System.debug('FALLO combinado: ' + e.getMessage());
        try {
            Contract updStatusOnly = new Contract(Id = c.Id, Status = 'Cancelled');
            update updStatusOnly;
            System.debug('OK aislado: Status solo SI se pudo actualizar.');
        } catch (Exception e2) {
            System.debug('FALLO Status solo tambien: ' + e2.getMessage());
        }
    }
}

System.debug('=== RE-QUERY FINAL ===');
for (Contract c : [SELECT ContractNumber, Status, SM_Reason_for_cancellation__c, SM_Cancellation_Date__c FROM Contract WHERE ContractNumber IN :contractDates.keySet()]) {
    System.debug(c.ContractNumber + ' | Status=' + c.Status + ' | Reason=' + c.SM_Reason_for_cancellation__c + ' | Fecha=' + c.SM_Cancellation_Date__c);
}
