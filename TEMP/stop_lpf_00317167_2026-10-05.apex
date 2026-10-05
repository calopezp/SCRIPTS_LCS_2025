// Contrato 00317167 (Jose R Garcia Atanacio) - 2026-10-05
// Cliente posible cancelacion (nota Raiza, Contract Monitoring). Pedido por Carlos:
// detener las LPF de Jun/Jul/Ago y borrar sus payments ACH PENDING para que no se transmita nada.
Set<String> ORDER_NAMES = new Set<String>{'ACH-27245', 'ACH-27870', 'ACH-28297'};
Set<String> PAYMENT_NAMES = new Set<String>{'PY-01916621', 'PY-01916628', 'PY-01916634'};
String NOTE = 'STOPPED: CONTRACT MONITORING - POS. CANCELACION (RAIZA) - 2026-10-05';

List<SM_ACH_Order__c> orders = [SELECT Id, Name, SM_Payment_Status__c, SM_Id_Salesforce_LCS__c
                                FROM SM_ACH_Order__c
                                WHERE Name IN :ORDER_NAMES AND SM_Contract__r.ContractNumber = '00317167'];
List<SM_Payment__c> pays = [SELECT Id, Name, Payment_Status__c, SM_ACH_Order__r.Name
                            FROM SM_Payment__c
                            WHERE Name IN :PAYMENT_NAMES AND SM_Contract__r.ContractNumber = '00317167'
                            AND Payment_Status__c = 'ACH PENDING'];
if (orders.size() != 3 || pays.size() != 3) {
    throw new IllegalArgumentException('Esperaba 3 orders y 3 payments ACH PENDING; encontrados ' + orders.size() + ' / ' + pays.size());
}
for (SM_ACH_Order__c o : orders) {
    o.SM_Payment_Status__c = 'Stopped';
    String prev = o.SM_Id_Salesforce_LCS__c;
    o.SM_Id_Salesforce_LCS__c = String.isBlank(prev) ? NOTE : (prev + ' // ' + NOTE).left(200);
}
update orders;
delete pays;
for (SM_ACH_Order__c o : orders) System.debug('RESULT order ' + o.Name + ' -> Stopped');
for (SM_Payment__c p : pays) System.debug('RESULT deleted ' + p.Name + ' (' + p.SM_ACH_Order__r.Name + ')');
