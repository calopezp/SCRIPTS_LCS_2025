// ============================================================
//  SIMULACIÓN — Cambio de ChargeBee (TC) -> ACH
//
//  Contrato ya tiene SM_Payment_methods__c = 'ACH' y su
//  SM_Payment_Method__c (RecordType SM_ACH) creado por el agente
//  comercial. Este script valida qué falta para completar la
//  migración real, en 3 pasos (instrucción del usuario):
//
//   1. Cancelar en Chargebee lo pendiente: Invoice -> Request -> Subscription
//      (en ese orden: Invoice y Request primero, Subscription al final).
//   2. Crear el ACH Order tipo Subscription (recurrente).
//   3. Crear un ACH Order tipo Late Payment Fee por cada ciclo de
//      cobro que quedó sin pagar en Chargebee, emparejando cada
//      Invoice de Late Fee ($25) con su Invoice padre vía
//      Parent_CB_Invoice__c (campo directo en el Invoice, no hace
//      falta pasar por CB_Charge_Request__c) -- si el padre y el
//      hijo (multa) siguen sin pagar, el LPF de ACH suma los dos
//      (Total_Amount__c = base + multa) y registra la multa en
//      SM_Apply_penalty__c=true / SM_Penalty_value__c=25; si la
//      multa ya se cobró aparte, el LPF de ACH es solo el monto
//      base, sin penalty.
//
//  Después de crear los ACH Order (paso 2 y 3), se cancela Chargebee
//  en este orden -- Invoice -> Request -> Subscription -- cada uno
//  con la nota "Paso de TC a ACH":
//   - Invoice: VOID vía API (Named Credential Chargebee_API), la nota
//     va en el parámetro `comment` del POST (no existe un campo local
//     tipo Notes en el Invoice).
//   - Request (CB_Charge_Request__c, objeto local, no tiene API propia
//     de Chargebee): Request_Status__c = 'Cancelled' (picklist real,
//     doble L) + Notes__c = la nota (ese es su campo "Comment" local).
//   - Subscription: cancel_for_items vía API, misma nota en `comment`.
//  Cada ACH Order tipo Late Payment Fee queda con SM_Fee_CB_Invoice__c
//  (invoice base) y SM_LPF_CB_Invoice__c (invoice de multa) poblados.
//
//  modoDryRun = true: SOLO lee y reporta. Cero callouts a Chargebee,
//  cero DML. Seguro de correr las veces que haga falta para validar.
//
//  Autor: Carlos Lopez / Claude Code — SEPTIEMBRE 2026
// ============================================================

Boolean modoDryRun = false;   // Autorizado por Carlos 2026-09-26 -- ejecución real contrato 00314430
String  contractNumber = '00314430';

String  NAMED_CRED    = 'Chargebee_API';
String  NOTA_MIGRACION = 'Paso de TC a ACH';
Set<String> ESTADOS_INVOICE_RESUELTOS = new Set<String>{ 'VOIDED', 'PAID' };

System.debug('════════════════════════════════════════════════════════');
System.debug('SIMULACIÓN CAMBIO CHARGEBEE -> ACH — Contrato ' + contractNumber);
System.debug('Modo: ' + (modoDryRun ? 'DRY RUN (sin cambios)' : 'EJECUCIÓN REAL'));
System.debug('════════════════════════════════════════════════════════');

// ── 1. Contrato + validaciones de elegibilidad ─────────────
Contract cont = [
    SELECT Id, ContractNumber, Status, SM_Payment_methods__c,
           SM_Payment_Method__c, SM_Payment_Method__r.RecordType.DeveloperName,
           SM_Payment_Method__r.SM_ACH_Account_Number__c, SM_Payment_Method__r.ACH_Account_Type__c,
           CB_Subscription__c, CB_Subscription__r.Name,
           CB_Subscription__r.chargebeeapps__Subscription_status__c,
           SM_AC_collected__c, SM_Total_ac__c, SM_Monthly_offer__c, SM_Payment_day__c,
           SM_Email_to_send_contract__c,
           SM_Customer_Cancellation__c, Is_Test_Contract__c, Is_VIP_Contract__c
    FROM Contract
    WHERE ContractNumber = :contractNumber
    LIMIT 1
];

List<String> bloqueos = new List<String>();
if (cont.Status == 'Cancelled') bloqueos.add('Contrato ya está Cancelled.');
if (cont.SM_Customer_Cancellation__c == true) bloqueos.add('Contrato marcado con cancelación de cliente.');
if (cont.Is_Test_Contract__c == true) bloqueos.add('Es Test Contract.');
if (cont.Is_VIP_Contract__c == true) bloqueos.add('Es VIP Contract.');
if (String.isBlank(cont.CB_Subscription__c)) bloqueos.add('No tiene CB_Subscription__c -- no es un contrato Chargebee, nada que migrar.');
if (cont.SM_Payment_methods__c != 'ACH') bloqueos.add('SM_Payment_methods__c todavía NO está en ACH (actual: ' + cont.SM_Payment_methods__c + ').');
if (cont.SM_Payment_Method__r == null || cont.SM_Payment_Method__r.RecordType.DeveloperName != 'SM_ACH')
    bloqueos.add('El Payment Method asignado al contrato no es de tipo ACH.');

System.debug('\n── CONTRATO ──');
System.debug(' Status: ' + cont.Status + ' | SM_Payment_methods__c: ' + cont.SM_Payment_methods__c);
System.debug(' Payment Method ACH: ' + (cont.SM_Payment_Method__c != null ? cont.SM_Payment_Method__c
    + ' (cuenta ...' + cont.SM_Payment_Method__r.SM_ACH_Account_Number__c + ', ' + cont.SM_Payment_Method__r.ACH_Account_Type__c + ')' : 'NO ASIGNADO'));
System.debug(' AC ya cobrado (SM_AC_collected__c): ' + cont.SM_AC_collected__c + ' ($' + cont.SM_Total_ac__c + ')');
System.debug(' Monthly offer (RC): $' + cont.SM_Monthly_offer__c);
System.debug(' Chargebee Subscription: ' + cont.CB_Subscription__r.Name
    + ' -- status ' + cont.CB_Subscription__r.chargebeeapps__Subscription_status__c);

if (!bloqueos.isEmpty()) {
    System.debug('\n⚠️ BLOQUEADO -- no se puede continuar:');
    for (String b : bloqueos) System.debug(' - ' + b);
    return;
}

// ── 2. Invoices de Chargebee (todas, para poder emparejar) ─
Map<Id, chargebeeapps__CB_Invoice__c> invoicesById = new Map<Id, chargebeeapps__CB_Invoice__c>([
    SELECT Id, Name, chargebeeapps__CB_Invoice_Id__c, chargebeeapps__Status__c,
           chargebeeapps__Invoice_Date__c, chargebeeapps__Due_Amount__c, Has_Late_Fee__c,
           Parent_CB_Invoice__c, Parent_CB_Invoice_Number__c
    FROM   chargebeeapps__CB_Invoice__c
    WHERE  Contract__c = :cont.Id
    ORDER BY chargebeeapps__Invoice_Date__c ASC
]);

List<chargebeeapps__CB_Invoice__c> pendientes = new List<chargebeeapps__CB_Invoice__c>();
for (chargebeeapps__CB_Invoice__c inv : invoicesById.values()) {
    if (!ESTADOS_INVOICE_RESUELTOS.contains(inv.chargebeeapps__Status__c)) pendientes.add(inv);
}

System.debug('\n── PASO 1a. INVOICES CHARGEBEE (' + invoicesById.size() + ' total, ' + pendientes.size() + ' pendientes de VOID) ──');
for (chargebeeapps__CB_Invoice__c inv : invoicesById.values()) {
    Boolean esPendiente = !ESTADOS_INVOICE_RESUELTOS.contains(inv.chargebeeapps__Status__c);
    System.debug(' ' + (esPendiente ? '⚠️ PENDIENTE' : '✓ resuelto  ') + ' — Invoice ' + inv.Name
        + ' ▫ ' + inv.chargebeeapps__Status__c
        + ' ▫ Fecha: ' + inv.chargebeeapps__Invoice_Date__c
        + ' ▫ Debe: $' + inv.chargebeeapps__Due_Amount__c
        + (inv.Has_Late_Fee__c ? ' ▫ (es Late Fee)' : ''));
}

// ── 3. Charge Requests (Late Payment Fee) de la subscription ─
List<CB_Charge_Request__c> requests = [
    SELECT Id, Name, Request_Status__c, Notes__c, Charge_Amount__c, Charge_Date__c,
           CB_Invoice_Origin_Late_Fee__c, CB_Invoice_Created__c
    FROM   CB_Charge_Request__c
    WHERE  CB_Subscription__c = :cont.CB_Subscription__c
    ORDER BY Charge_Date__c ASC
];

System.debug('\n── PASO 1b. CHARGE REQUESTS CHARGEBEE (' + requests.size() + ' total) ──');
// Instrucción confirmada del usuario: solo se cancelan los Request "activos" -- Pending,
// Ready To Collect, Error (todavía no se resolvieron). Los que ya están "Sent" YA fueron
// trabajados (su invoice ya existe, se resuelve al hacer VOID del invoice) -- NO se tocan.
Set<String> ESTADOS_REQUEST_ACTIVOS = new Set<String>{ 'Pending', 'Ready To Collect', 'Error' };
List<CB_Charge_Request__c> requestsACancelar = new List<CB_Charge_Request__c>();
for (CB_Charge_Request__c req : requests) {
    Boolean esActivo = ESTADOS_REQUEST_ACTIVOS.contains(req.Request_Status__c);
    if (esActivo) requestsACancelar.add(req);
    System.debug(' Request ' + req.Name + ' ▫ Status actual: ' + req.Request_Status__c
        + ' ▫ Charge: $' + req.Charge_Amount__c + ' ▫ Fecha: ' + req.Charge_Date__c
        + (esActivo ? ' ▫ ⚠️ se cancelará' : ' ▫ ✓ ya trabajado, no se toca'));
}

// ── 4. Emparejar ciclos usando Parent_CB_Invoice__c (campo directo
//      en el Invoice hijo de Late Fee -- NO se pasa por CB_Charge_Request__c) ──
// Un "hijo" es un invoice con Has_Late_Fee__c=true y Parent_CB_Invoice__c poblado (la multa de $25).
// Su "padre" es el invoice base (la cuota mensual) que la originó.
class DmlLogger {
    public void logSaveResults(String label, List<Database.SaveResult> results) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                List<String> msgs = new List<String>();
                for (Database.Error e : sr.getErrors()) msgs.add(e.getStatusCode() + ': ' + e.getMessage());
                System.debug('⚠️ ERROR DML [' + label + '] Id=' + sr.getId() + ' -- ' + String.join(msgs, ' | '));
            } else {
                System.debug('✔️ DML OK [' + label + '] Id=' + sr.getId());
            }
        }
    }
}

class PlanLPF implements Comparable {
    String  invoiceBase;
    String  invoiceMulta;
    Id      invoiceBaseId;   // -> SM_Fee_CB_Invoice__c
    Id      invoiceMultaId;  // -> SM_LPF_CB_Invoice__c
    Date    invoiceDate;     // fecha del invoice base -- para ordenar cronológicamente
    Decimal montoBase;
    Decimal montoMulta;
    Decimal totalAmount;   // base + multa -> Total_Amount__c / SM_Total__c del ACH Order
    Boolean aplicaPenalty; // -> SM_Apply_penalty__c
    Date    fechaCobro;    // -> SM_Next_Transaction_Date__c (asignado después de ordenar)
    Boolean esPTP;         // -> Is_PTP__c / SM_PTP_Montly__c

    public Integer compareTo(Object other) {
        PlanLPF o = (PlanLPF) other;
        if (invoiceDate == null || o.invoiceDate == null) return 0;
        if (invoiceDate < o.invoiceDate) return -1;
        if (invoiceDate > o.invoiceDate) return 1;
        return 0;
    }
}

Set<Id> invoicesEmparejadas = new Set<Id>();
List<PlanLPF> planesLPF = new List<PlanLPF>();

// 4a. Recorrer los invoices HIJOS (multa) pendientes y buscar su padre.
for (chargebeeapps__CB_Invoice__c hijo : pendientes) {
    if (hijo.Parent_CB_Invoice__c == null) continue; // no es un hijo de Late Fee

    chargebeeapps__CB_Invoice__c padre = invoicesById.get(hijo.Parent_CB_Invoice__c);
    Decimal dueMulta = (hijo.chargebeeapps__Due_Amount__c != null) ? hijo.chargebeeapps__Due_Amount__c : 0;
    Decimal duePadre = (padre != null && !ESTADOS_INVOICE_RESUELTOS.contains(padre.chargebeeapps__Status__c) && padre.chargebeeapps__Due_Amount__c != null)
        ? padre.chargebeeapps__Due_Amount__c : 0;

    invoicesEmparejadas.add(hijo.Id);
    if (padre != null) invoicesEmparejadas.add(padre.Id);

    PlanLPF p = new PlanLPF();
    p.invoiceBase    = padre != null ? padre.Name : hijo.Parent_CB_Invoice_Number__c;
    p.invoiceMulta   = hijo.Name;
    p.invoiceBaseId  = (padre != null) ? padre.Id : null;
    p.invoiceMultaId = hijo.Id;
    p.invoiceDate    = (padre != null && padre.chargebeeapps__Invoice_Date__c != null) ? padre.chargebeeapps__Invoice_Date__c.date() : hijo.chargebeeapps__Invoice_Date__c.date();
    p.montoBase      = duePadre;
    p.montoMulta     = dueMulta;
    p.totalAmount    = duePadre + dueMulta;
    p.aplicaPenalty  = dueMulta > 0;
    if (p.totalAmount > 0) planesLPF.add(p);
}

// 4b. Invoices base pendientes cuyo hijo (multa) ya está resuelto/PAID o nunca se generó -- LPF sin penalty.
for (chargebeeapps__CB_Invoice__c inv : pendientes) {
    if (inv.Parent_CB_Invoice__c != null) continue;           // es un hijo, ya se procesó arriba
    if (invoicesEmparejadas.contains(inv.Id)) continue;        // ya tiene un hijo pendiente, ya se procesó arriba
    if (inv.chargebeeapps__Due_Amount__c == null || inv.chargebeeapps__Due_Amount__c <= 0) continue;

    PlanLPF p = new PlanLPF();
    p.invoiceBase    = inv.Name;
    p.invoiceMulta   = null;
    p.invoiceBaseId  = inv.Id;
    p.invoiceMultaId = null;
    p.invoiceDate    = inv.chargebeeapps__Invoice_Date__c != null ? inv.chargebeeapps__Invoice_Date__c.date() : null;
    p.montoBase      = inv.chargebeeapps__Due_Amount__c;
    p.montoMulta     = 0;
    p.totalAmount    = inv.chargebeeapps__Due_Amount__c;
    p.aplicaPenalty  = false;
    planesLPF.add(p);
}

Decimal totalLPF = 0;
for (PlanLPF p : planesLPF) totalLPF += p.totalAmount;

// ── 4c. Requerimiento puntual de la agente (00314430): "UNA cobro inmediato, y las
//      otras PTP para el 16 y 30 de oct" -- confirmado con el usuario: orden cronológico,
//      la deuda más vieja se cobra primero. Esto es específico de ESTE contrato/solicitud,
//      no una regla genérica -- en otro contrato habría que preguntar de nuevo.
planesLPF.sort(); // ordena por invoiceDate ascendente (Comparable)
List<Date> FECHAS_COBRO_ESPECIFICAS = new List<Date>{
    Date.today(),               // el ciclo más viejo -> cobro inmediato
    Date.newInstance(2026,10,16), // PTP 16-oct
    Date.newInstance(2026,10,30)  // PTP 30-oct
};
for (Integer i = 0; i < planesLPF.size(); i++) {
    PlanLPF p = planesLPF[i];
    if (i < FECHAS_COBRO_ESPECIFICAS.size()) {
        p.fechaCobro = FECHAS_COBRO_ESPECIFICAS[i];
        p.esPTP      = (i > 0); // el primero es cobro inmediato, no PTP
    } else {
        // más ciclos de los que el requerimiento contempló -- no se asume fecha, se marca para revisión manual
        p.fechaCobro = null;
        p.esPTP      = false;
    }
}

System.debug('\n── PASO 3. LATE PAYMENT FEE (ACH) A CREAR -- ' + planesLPF.size() + ' orden(es), total $' + totalLPF + ' ──');
System.debug(' (Requerimiento de la agente: 1 cobro inmediato + 2 PTP para 16 y 30-oct, orden cronológico)');
for (PlanLPF p : planesLPF) {
    System.debug(' → ACH Order Late Payment Fee: SM_Total__c = $' + p.totalAmount + ' (Total_Amount__c es fórmula, se calcula solo)'
        + '  (base ' + p.invoiceBase + ' $' + p.montoBase
        + (p.aplicaPenalty ? ' + multa ' + p.invoiceMulta + ' $' + p.montoMulta : (p.invoiceMulta != null ? ' -- multa ' + p.invoiceMulta + ' ya resuelta, no se replica' : ''))
        + ')  ▫ SM_Apply_penalty__c=' + p.aplicaPenalty
        + (p.aplicaPenalty ? ' ▫ SM_Penalty_value__c=$' + p.montoMulta : ''));
    System.debug('     SM_Fee_CB_Invoice__c = ' + p.invoiceBase + ' (' + p.invoiceBaseId + ')'
        + ' ▫ SM_LPF_CB_Invoice__c = ' + (p.invoiceMultaId != null ? p.invoiceMulta + ' (' + p.invoiceMultaId + ')' : 'N/A (sin multa pendiente)'));
    System.debug('     SM_Next_Transaction_Date__c = ' + p.fechaCobro
        + (p.fechaCobro == null ? ' ⚠️ SIN FECHA -- revisar manualmente' : (p.esPTP ? ' (PTP -- Is_PTP__c=true, SM_PTP_Montly__c=\'octubre PTP\')' : ' (cobro inmediato)')));
}
if (planesLPF.isEmpty()) System.debug(' → No hay ciclos pendientes -- no haría falta crear ningún Late Payment Fee.');

// ── 5. Plan de cancelación Chargebee (Invoice -> Request -> Subscription) ──
System.debug('\n── PASO 4. CANCELACIÓN CHARGEBEE (orden: Invoice -> Request -> Subscription) -- nota: "' + NOTA_MIGRACION + '" ──');
for (chargebeeapps__CB_Invoice__c inv : pendientes) {
    System.debug(' → VOID Invoice ' + inv.Name + ' (CB Id ' + inv.chargebeeapps__CB_Invoice_Id__c
        + ') vía POST /invoices/.../void, comment="' + NOTA_MIGRACION + '"');
}
for (CB_Charge_Request__c req : requestsACancelar) {
    System.debug(' → Request ' + req.Name + ' (status actual ' + req.Request_Status__c + '): Request_Status__c = \'Cancelled\', Notes__c = "' + NOTA_MIGRACION + '"');
}
System.debug(' → Cancelar Subscription ' + cont.CB_Subscription__r.Name + ' vía POST /subscriptions/.../cancel_for_items, comment="' + NOTA_MIGRACION + '" -- SOLO después de que los invoices arriba queden resueltos.');

// ── 6. Task de auditoría/seguimiento (nuevo, no toca el Task existente de la agente) ──
String taskSubject = 'Migración ChargeBee (TC) a ACH';
String taskDescription =
    'AUTO: TC_to_ACH_Migracion - ' + Date.today().format() + '\n' +
    'Se completó el paso de ChargeBee (TC) a ACH del contrato ' + cont.ContractNumber + ':\n' +
    '- Chargebee: Subscription ' + cont.CB_Subscription__r.Name + ' cancelada + ' + pendientes.size()
        + ' invoice(s) anulados ($' + totalLPF + ' total) - nota "' + NOTA_MIGRACION + '"\n' +
    '- ACH: Subscription Order creada ($' + cont.SM_Monthly_offer__c + '/mes)\n' +
    '- ACH: ' + planesLPF.size() + ' Late Payment Fee creadas ($' + totalLPF + ' total)\n' +
    '- AC: ' + (cont.SM_AC_collected__c == true ? 'ya estaba cobrado ($' + cont.SM_Total_ac__c + '), no se generó orden de AC' : 'NO cobrado, se generó orden de AC por $' + cont.SM_Total_ac__c) + '\n' +
    'Referencia: Task "Collections-Change Payment Method" de Raiza Montiel (2026-09-25)';

System.debug('\n── PASO 5. TASK DE AUDITORÍA (nuevo -- no se toca el Task existente de Raiza) ──');
System.debug(' Subject: ' + taskSubject);
System.debug(' WhatId: ' + cont.Id + ' (Contract ' + cont.ContractNumber + ')');
System.debug(' RecordTypeId: 0121U00000085XiQAI (mismo RT que usa CancelarContratosRunner)');
System.debug(' Description:\n' + taskDescription);

// ── 7. Resumen del plan completo ──
System.debug('\n════════════════════════════════════════════════════════');
System.debug('RESUMEN DEL PLAN (' + (modoDryRun ? 'SIMULADO -- nada se ejecutó' : 'A EJECUTAR') + ')');
System.debug('════════════════════════════════════════════════════════');
System.debug('1. VOID en Chargebee: ' + pendientes.size() + ' invoice(s) pendientes -- comment="' + NOTA_MIGRACION + '".');
System.debug('   Cancelar Request(s) activos: ' + requestsACancelar.size() + ' de ' + requests.size() + ' (Request_Status__c=\'Cancelled\', Notes__c="' + NOTA_MIGRACION + '") -- los "Sent" no se tocan.');
System.debug('   Cancelar Subscription ' + cont.CB_Subscription__r.Name + ' (status actual: '
    + cont.CB_Subscription__r.chargebeeapps__Subscription_status__c + ') -- comment="' + NOTA_MIGRACION + '", SOLO después de que los invoices queden resueltos.');
System.debug('2. Crear ACH Order tipo Subscription: $' + cont.SM_Monthly_offer__c + '/mes.');
System.debug('3. Crear ' + planesLPF.size() + ' ACH Order(es) tipo Late Payment Fee por $' + totalLPF + ' total, con SM_Fee_CB_Invoice__c / SM_LPF_CB_Invoice__c poblados.');
System.debug('   AC: ' + (cont.SM_AC_collected__c == true
    ? 'ya cobrado ($' + cont.SM_Total_ac__c + ') -- NO se crea ACH Order de AC.'
    : '⚠️ NO cobrado todavía -- SÍ haría falta crear un ACH Order tipo AC por $' + cont.SM_Total_ac__c + '.'));
System.debug('4. Crear 1 Task nuevo de auditoría en el contrato (ver detalle arriba).');

// ── 8. EJECUCIÓN REAL ──
// Orden interno OBLIGATORIO por restricción de la plataforma (mismo gotcha ya documentado
// en CancelarContratosRunner.cls): un callout DESPUÉS de cualquier DML pendiente en la misma
// transacción tira "System.CalloutException: You have uncommitted work pending". Por eso:
//   FASE 1 = todos los callouts a Chargebee (cero DML antes).
//   FASE 2 = toda la DML junta (ACH Orders, mirror local de Invoice/Subscription, Requests, Task).
// El resultado final es el mismo que pediste (ACH creado + Chargebee cancelado, todo en el
// mismo commit) -- el orden invoice->request->subscription solo aplica DENTRO de la Fase 1.
if (!modoDryRun) {

    DmlLogger logger = new DmlLogger();
    String TASK_OWNER_ID = '0051U000001MRFeQAO'; // "Legal Credit Solutions" -- mismo owner que usa CancelarContratosRunner

    // FASE 1 — Callouts a Chargebee, cero DML todavía.
    Map<Id, Boolean> invoiceVoidOk = new Map<Id, Boolean>();
    Boolean todosLosInvoicesOk = true;

    for (chargebeeapps__CB_Invoice__c inv : pendientes) {
        Boolean ok = false;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/invoices/'
                + EncodingUtil.urlEncode(inv.chargebeeapps__CB_Invoice_Id__c, 'UTF-8') + '/void');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('comment=' + EncodingUtil.urlEncode(NOTA_MIGRACION, 'UTF-8'));
            req.setTimeout(60000);
            HttpResponse res = new Http().send(req);
            ok = (res.getStatusCode() == 200);
            if (!ok) System.debug('⚠️ ERROR void Invoice ' + inv.Name + ': HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
        } catch (Exception e) {
            System.debug('⚠️ EXCEPTION void Invoice ' + inv.Name + ': ' + e.getMessage());
        }
        invoiceVoidOk.put(inv.Id, ok);
        if (!ok) todosLosInvoicesOk = false;
    }

    Boolean subscriptionCancelOk = false;
    if (todosLosInvoicesOk) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + NAMED_CRED + '/api/v2/subscriptions/'
                + EncodingUtil.urlEncode(cont.CB_Subscription__r.Name, 'UTF-8') + '/cancel_for_items');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('cancel_option=immediately&comment=' + EncodingUtil.urlEncode(NOTA_MIGRACION, 'UTF-8'));
            req.setTimeout(60000);
            HttpResponse res = new Http().send(req);
            subscriptionCancelOk = (res.getStatusCode() == 200);
            if (!subscriptionCancelOk) System.debug('⚠️ ERROR cancel Subscription: HTTP ' + res.getStatusCode() + ' — ' + res.getBody());
        } catch (Exception e) {
            System.debug('⚠️ EXCEPTION cancel Subscription: ' + e.getMessage());
        }
    } else {
        System.debug('⚠️ No se intenta cancelar la Subscription -- quedó al menos 1 Invoice sin poder anular.');
    }

    // FASE 2 — Toda la DML, ya sin callouts pendientes.
    List<chargebeeapps__CB_Invoice__c> invoicesToUpdate = new List<chargebeeapps__CB_Invoice__c>();
    for (chargebeeapps__CB_Invoice__c inv : pendientes) {
        if (invoiceVoidOk.get(inv.Id) == true) {
            invoicesToUpdate.add(new chargebeeapps__CB_Invoice__c(Id = inv.Id, chargebeeapps__Status__c = 'VOIDED'));
        }
    }
    if (!invoicesToUpdate.isEmpty()) logger.logSaveResults('Invoice mirror VOIDED', Database.update(invoicesToUpdate, false));

    List<CB_Charge_Request__c> requestsToUpdate = new List<CB_Charge_Request__c>();
    for (CB_Charge_Request__c req : requestsACancelar) {
        requestsToUpdate.add(new CB_Charge_Request__c(Id = req.Id, Request_Status__c = 'Cancelled', Notes__c = NOTA_MIGRACION));
    }
    if (!requestsToUpdate.isEmpty()) logger.logSaveResults('Request Cancelled', Database.update(requestsToUpdate, false));

    if (subscriptionCancelOk) {
        logger.logSaveResults('Subscription mirror CANCELLED', new List<Database.SaveResult>{ Database.update(
            new chargebeeapps__CB_Subscription__c(Id = cont.CB_Subscription__c, chargebeeapps__Subscription_status__c = 'CANCELLED'),
            false
        ) });
    }

    // ── GATE DE SEGURIDAD ──
    // Si Chargebee no quedó 100% cancelado (algún invoice sin voidear, o la subscription
    // sin cancelar), NO se crean los ACH Orders ni el Task -- crearlos igual dejaría al
    // contrato cobrando por los dos lados (Chargebee sin cerrar + ACH nuevo). Se detiene
    // acá para que Carlos revise manualmente qué falló antes de reintentar.
    if (!todosLosInvoicesOk || !subscriptionCancelOk) {
        System.debug('\n⛔ DETENIDO -- Chargebee no quedó completamente cancelado (invoices OK: '
            + todosLosInvoicesOk + ', subscription OK: ' + subscriptionCancelOk
            + '). NO se crearon ACH Orders ni Task. Revisar los ERROR/EXCEPTION de arriba antes de reintentar.');
        return;
    }

    // ACH Order tipo Subscription -- próxima fecha = próxima ocurrencia de SM_Payment_day__c en el mes.
    Date hoy = Date.today();
    Integer diaPago = (cont.SM_Payment_day__c != null) ? Integer.valueOf(cont.SM_Payment_day__c) : hoy.day();
    Date proximoCobro = Date.newInstance(hoy.year(), hoy.month(), 1).addMonths(0);
    Integer ultimoDiaMes = Date.daysInMonth(hoy.year(), hoy.month());
    Date candidato = Date.newInstance(hoy.year(), hoy.month(), Math.min(diaPago, ultimoDiaMes));
    proximoCobro = (candidato >= hoy) ? candidato : candidato.addMonths(1);

    List<SM_ACH_Order__c> achOrdersToInsert = new List<SM_ACH_Order__c>();

    achOrdersToInsert.add(new SM_ACH_Order__c(
        SM_Contract__c              = cont.Id,
        SM_Payment_Method__c        = cont.SM_Payment_Method__c,
        SM_Payment_Type__c          = 'Subscription',
        SM_Payment_Frequency__c     = 'Monthly',
        SM_Payment_Status__c        = 'Pending',
        SM_Payment_Condition__c     = 'Fixed value',
        SM_Billing_Email__c         = cont.SM_Email_to_send_contract__c,
        SM_Payment_Count__c         = 1,
        SM_Fee_to_collect__c        = 1,
        SM_Payment_Start_Date__c    = proximoCobro,
        SM_Next_Transaction_Date__c = proximoCobro,
        SM_Total__c                 = cont.SM_Monthly_offer__c
    ));

    for (PlanLPF p : planesLPF) {
        // Fecha de cobro: la asignada en el PASO 3 (1 inmediata + 2 PTP 16/30-oct,
        // requerimiento puntual de la agente) -- si por alguna razón vino null
        // (más ciclos de los 3 esperados), cae a hoy como fallback seguro.
        Date fechaOrden = (p.fechaCobro != null) ? p.fechaCobro : hoy;
        achOrdersToInsert.add(new SM_ACH_Order__c(
            SM_Contract__c              = cont.Id,
            SM_Payment_Method__c        = cont.SM_Payment_Method__c,
            SM_Payment_Type__c          = 'Late payment fee',
            SM_Payment_Frequency__c     = 'Once',
            SM_Payment_Status__c        = 'Pending',
            SM_Payment_Condition__c     = 'Fixed value',
            SM_Billing_Email__c         = cont.SM_Email_to_send_contract__c,
            SM_Payment_Start_Date__c    = fechaOrden,
            SM_Payment_End_Date__c      = fechaOrden,
            SM_Next_Transaction_Date__c = fechaOrden,
            SM_Total__c                 = p.totalAmount,
            SM_Apply_penalty__c         = p.aplicaPenalty,
            SM_Penalty_value__c         = p.aplicaPenalty ? p.montoMulta : null,
            SM_Penalty_date__c          = p.aplicaPenalty ? hoy : null,
            SM_Fee_CB_Invoice__c        = p.invoiceBaseId,
            SM_LPF_CB_Invoice__c        = p.invoiceMultaId,
            SM_PTP_Montly__c            = p.esPTP ? 'octubre PTP' : null
        ));
    }
    logger.logSaveResults('ACH Order insert', Database.insert(achOrdersToInsert, false));

    logger.logSaveResults('Task insert', new List<Database.SaveResult>{ Database.insert(new Task(
        Subject       = taskSubject,
        WhatId        = cont.Id,
        Description   = taskDescription,
        OwnerId       = TASK_OWNER_ID,
        RecordTypeId  = '0121U00000085XiQAI',
        ActivityDate  = hoy
    ), false) });

    System.debug('\n✔️ EJECUCIÓN REAL completada -- ver detalle arriba de cada callout/DML.');
}
