// ============================================================
//  Excepcion PUNTUAL autorizada por el usuario 2026-09-23: aplicar
//  NOT_COLLECTED a los 7 contratos PENDING_ACH_PAYMENT que estan en
//  EXACTAMENTE 26 dias transmitidos (no el umbral estricto ">26 dias" de
//  la Rule 3, CLAUDE.md #2.2) -- 1 dia antes de calificar por timeout.
//  NO es el comportamiento estandar de validate_pending_payments.py (ese
//  sigue exigiendo >26 dias); esto es un ajuste manual de una sola vez,
//  a peticion explicita, igual que la excepcion de codigo definitivo ya
//  documentada. El contrato 00317915 (9 dias) queda fuera a proposito.
// ============================================================

Map<Id, String> paymentReasons = new Map<Id, String>{
    'a24UU000005GDODYA4' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R08), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005GDOEYA4' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R08), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005GDOIYA4' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R08), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TAYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R01), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TIYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R08), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TJYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R01), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TKYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R01), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TNYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R08), 1 dia antes del umbral estricto >26 de Rule 3.',
    'a24UU000005H8TVYA0' => 'Excepcion puntual autorizada 2026-09-23: 26 dias transmitido (R01), 1 dia antes del umbral estricto >26 de Rule 3.'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, SM_Check_Collection_Status__c, SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE Id IN :paymentReasons.keySet()
];

System.debug('Payments encontrados: ' + payments.size() + ' (esperados: ' + paymentReasons.size() + ')');

for (SM_Payment__c p : payments) {
    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
    p.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(
        p.SM_Id_Salesforce_LCS__c,
        'Excepcion_26D_CancelCandidates',
        paymentReasons.get(p.Id)
    );
}

update payments;

System.debug('==========================================================');
System.debug('Actualizados a NOT_COLLECTED: ' + payments.size());
System.debug('==========================================================');
