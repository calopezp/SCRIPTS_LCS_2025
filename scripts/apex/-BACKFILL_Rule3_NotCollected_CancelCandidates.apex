// ============================================================
//  Backfill puntual: aplica Rule 3 (CLAUDE.md #2.2) a los payments
//  bloqueantes de los 38 contratos "candidatos a cancelar" que ya
//  superan 26 dias desde SM_Transmission_Date_ACH_File__c sin resolver
//  (PENDING). Corrido a peticion explicita del usuario, 2026-09-23.
//  Ver analisis completo en la conversacion / TEMP/ si se archivo ahi.
// ============================================================

Set<String> paymentNames = new Set<String>{
        'PY-01746807',
        'PY-01746804',
        'PY-01746830',
        'PY-01746831',
        'PY-01756809',
        'PY-01756637',
        'PY-01756825',
        'PY-01771607',
        'PY-01740249',
        'PY-01751750',
        'PY-01770740',
        'PY-01770742',
        'PY-01770737',
        'PY-01770735',
        'PY-01771623',
        'PY-01752505',
        'PY-01771645',
        'PY-01771774',
        'PY-01771757',
        'PY-01771636',
        'PY-01771814',
        'PY-01771874',
        'PY-01752580',
        'PY-01771815',
        'PY-01771862',
        'PY-01771734',
        'PY-01771777',
        'PY-01771647',
        'PY-01771748',
        'PY-01746966',
        'PY-01756777',
        'PY-01771865',
        'PY-01771775',
        'PY-01771660',
        'PY-01746886',
        'PY-01771652',
        'PY-01771786',
        'PY-01771875',
        'PY-01771816',
        'PY-01771659',
        'PY-01746900',
        'PY-01756830',
        'PY-01756705',
        'PY-01771861',
        'PY-01771749',
        'PY-01771669',
        'PY-01771817',
        'PY-01771782',
        'PY-01771868',
        'PY-01771850',
        'PY-01771679',
        'PY-01771797',
        'PY-01771843',
        'PY-01771678',
        'PY-01771753',
        'PY-01771783',
        'PY-01771819',
        'PY-01771869',
        'PY-01771762',
        'PY-01771720',
        'PY-01771842',
        'PY-01771793',
        'PY-01771750',
        'PY-01771691',
        'PY-01771780',
        'PY-01771823',
        'PY-01771866',
        'PY-01771761',
        'PY-01771832',
        'PY-01771788',
        'PY-01771760',
        'PY-01747004',
        'PY-01746933',
        'PY-01771820',
        'PY-01771697',
        'PY-01771768',
        'PY-01771776',
        'PY-01746935',
        'PY-01756831',
        'PY-01756743',
        'PY-01746687',
        'PY-01771708',
        'PY-01771830',
        'PY-01771886',
        'PY-01771784',
        'PY-01771754',
        'PY-01752573',
        'PY-01752532',
        'PY-01771845',
        'PY-01771794',
        'PY-01746962',
        'PY-01771767',
        'PY-01771744',
        'PY-01771800',
        'PY-01771852',
        'PY-01771848',
        'PY-01771795',
        'PY-01771763',
        'PY-01771743',
        'PY-01746997',
        'PY-01747017',
        'PY-01746969',
        'PY-01771779',
        'PY-01771730',
        'PY-01771864',
        'PY-01771751',
        'PY-01771821',
        'PY-01746994',
        'PY-01752555',
        'PY-01752554',
        'PY-01752575',
        'PY-01771985'
};

List<SM_Payment__c> payments = [
    SELECT Id, Name, SM_Check_Collection_Status__c, SM_Id_Salesforce_LCS__c
    FROM SM_Payment__c
    WHERE Name IN :paymentNames
];

System.debug('Payments encontrados: ' + payments.size() + ' (esperados: ' + paymentNames.size() + ')');

for (SM_Payment__c p : payments) {
    p.SM_Check_Collection_Status__c = 'NOT_COLLECTED';
    p.SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(
        p.SM_Id_Salesforce_LCS__c,
        'Backfill_Rule3_CancelCandidates',
        'PENDING mayor a 26 dias transmitido -> NOT_COLLECTED'
    );
}

update payments;

System.debug('==========================================================');
System.debug('Actualizados a NOT_COLLECTED: ' + payments.size());
System.debug('==========================================================');
