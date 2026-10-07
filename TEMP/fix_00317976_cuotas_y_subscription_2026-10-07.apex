/*
 * fix_00317976_cuotas_y_subscription_2026-10-07.apex
 * Requerimiento de Comercial: "crea facturas SIN FEE de agosto, sept y oct, cobro INMEDIATO - 00317976".
 * El contrato (ACH, Activated) no tiene Subscription: nunca se generaron sus cuotas mensuales.
 *   - 3 Late payment fee de la cuota ($79, sin multa): inicio en la fecha de cada mes, próximo cobro hoy.
 *   - Subscription mensual: inicio 16-ago, próximo cobro SUB_NEXT.
 * Marca AUTO en cada orden. Sin Task (decisión de Carlos). DRY_RUN = true primero.
 */
Boolean DRY_RUN  = true;
String  CONTRATO = '00317976';
Date    COBRO_LPF = Date.newInstance(2026, 10, 7);    // "cobro inmediato": hoy
Date    SUB_START = Date.newInstance(2026, 8, 16);
Date    SUB_NEXT  = Date.newInstance(2026, 11, 16);   // Ago/Sep/Oct van por LPF (confirmado por Carlos)
String  PROCESO  = 'FIX_00317976';

Contract c = [SELECT Id, ContractNumber, Status, SM_Payment_methods__c, SM_Monthly_offer__c, SM_Payment_Method__c,
                     SM_Email_to_send_contract__c FROM Contract WHERE ContractNumber = :CONTRATO LIMIT 1];
System.debug('→ ' + c.ContractNumber + ' ▫️ ' + c.Status + ' ▫️ ' + c.SM_Payment_methods__c + ' ▫️ cuota $' + c.SM_Monthly_offer__c
             + ' ▫️ MODO ' + (DRY_RUN ? 'DRY RUN' : 'REAL'));
if (c.SM_Payment_methods__c != 'ACH' || c.SM_Payment_Method__c == null) { System.debug('→ ❌ No es ACH o no tiene Payment Method'); return; }

List<SM_ACH_Order__c> existentes = [SELECT Name, SM_Payment_Type__c, SM_Payment_Status__c, SM_PTP_Montly__c
                                    FROM SM_ACH_Order__c WHERE SM_Contract__c = :c.Id AND SM_Payment_Status__c != 'Canceled'];
for (SM_ACH_Order__c o : existentes) {
    if (o.SM_Payment_Type__c == 'Subscription' && o.SM_Payment_Status__c != 'Completed') { System.debug('→ ❌ Ya existe Subscription ' + o.Name); return; }
    if (o.SM_Payment_Type__c == 'Late payment fee' && o.SM_PTP_Montly__c != null && o.SM_Payment_Status__c != 'Completed') {
        System.debug('→ ❌ Ya existe LPF ' + o.Name + ' (' + o.SM_PTP_Montly__c + ')'); return;
    }
}

Decimal cuota = c.SM_Monthly_offer__c.setScale(2);
Map<String, Date> meses = new Map<String, Date>{ 'AUG' => Date.newInstance(2026, 8, 16), 'SEP' => Date.newInstance(2026, 9, 16), 'OCT' => Date.newInstance(2026, 10, 16) };
List<SM_ACH_Order__c> nuevas = new List<SM_ACH_Order__c>();
for (String mes : new List<String>{'AUG', 'SEP', 'OCT'}) {
    nuevas.add(new SM_ACH_Order__c(
        SM_Contract__c = c.Id, SM_Payment_Type__c = 'Late payment fee', SM_Payment_Frequency__c = 'Once',
        SM_Payment_Start_Date__c = meses.get(mes), SM_Payment_End_Date__c = meses.get(mes), SM_Next_Transaction_Date__c = COBRO_LPF,
        SM_Payment_Status__c = 'Pending', SM_Payment_Condition__c = 'Fixed value', SM_Billing_Email__c = c.SM_Email_to_send_contract__c,
        SM_Payment_Count__c = 1, SM_Fee_to_collect__c = 1, SM_Apply_Penalty__c = false, SM_Penalty_Value__c = 0,
        SM_Payment_Method__c = c.SM_Payment_Method__c, SM_Total__c = cuota, SM_PTP_Montly__c = mes,
        SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(null, PROCESO,
            'LPF cuota ' + mes + ' $' + cuota + ' sin multa (contrato sin Subscription), pedido Comercial')));
}
nuevas.add(new SM_ACH_Order__c(
    SM_Contract__c = c.Id, SM_Payment_Type__c = 'Subscription', SM_Payment_Frequency__c = 'Monthly',
    SM_Payment_Start_Date__c = SUB_START, SM_Next_Transaction_Date__c = SUB_NEXT,
    SM_Payment_Status__c = 'Pending', SM_Payment_Condition__c = 'Fixed value', SM_Billing_Email__c = c.SM_Email_to_send_contract__c,
    SM_Payment_Count__c = 1, SM_Fee_to_collect__c = 1, SM_Payment_Method__c = c.SM_Payment_Method__c, SM_Total__c = cuota,
    SM_Id_Salesforce_LCS__c = SM_AutomationLogHelper.appendNote(null, PROCESO,
        'Subscription creada (faltaba): inicio ' + String.valueOf(SUB_START) + ', próximo ' + String.valueOf(SUB_NEXT))));

for (SM_ACH_Order__c o : nuevas)
    System.debug('→ CREAR ' + o.SM_Payment_Type__c + ' ▫️ ' + (o.SM_PTP_Montly__c != null ? o.SM_PTP_Montly__c : '') + ' ▫️ $' + o.SM_Total__c
                 + ' ▫️ inicio ' + String.valueOf(o.SM_Payment_Start_Date__c) + ' ▫️ próximo ' + String.valueOf(o.SM_Next_Transaction_Date__c));
if (SUB_NEXT <= Date.newInstance(2026, 10, 16))
    System.debug('→ ⚠️ La Subscription quedaría con próximo cobro ' + String.valueOf(SUB_NEXT)
                 + ', y esa cuota ya la cubre una LPF: riesgo de cobro doble. Con Ago/Sep/Oct por LPF, el próximo natural es 2026-11-16.');

if (DRY_RUN) { System.debug('→ DRY RUN: no se creó nada.'); return; }
insert nuevas;
System.debug('→ ✅ Creadas: ' + nuevas.size());
