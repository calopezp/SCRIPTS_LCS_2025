// SOLO LECTURA -- borrador v2 del compilado semanal para Comercial: una linea por contrato
// (no por pago), separando "nuevo esta semana" del resto del backlog acumulado.

Set<String> CLOSED = new Set<String>{ 'Cancelled', 'Canceled', 'Finalized' };
Date sinceWeek = Date.today().addDays(-7);

class Pad {
    String rep(String ch, Integer n) {
        String s = '';
        for (Integer i = 0; i < n; i++) { s += ch; }
        return s;
    }
}
Pad pad = new Pad();

class Grupo {
    String titulo;
    String accion;
    Set<String> codigos;
    List<SM_Payment__c> payments = new List<SM_Payment__c>();
}

Map<String, Grupo> grupos = new Map<String, Grupo>();

Grupo g1 = new Grupo();
g1.titulo = 'ACTUALIZAR METODO DE PAGO';
g1.accion = 'el dato bancario del cliente esta mal o ya no existe -- hay que contactarlo para actualizarlo, reintentar con el mismo dato no va a funcionar.';
g1.codigos = new Set<String>{ 'R02', 'R04', 'R13' };
grupos.put('metodo', g1);

Grupo g2 = new Grupo();
g2.titulo = 'DISPUTA O REVOCACION DEL CLIENTE';
g2.accion = 'el cliente le dijo al banco que no autoriza o revoco el cobro -- hablar con el cliente antes de reintentar, para no generar otra disputa.';
g2.codigos = new Set<String>{ 'R10', 'R07' };
grupos.put('disputa', g2);

Grupo g3 = new Grupo();
g3.titulo = 'CUENTA CONGELADA';
g3.accion = 'usualmente por una orden legal/judicial, fuera del control del cliente -- dar seguimiento aparte antes de reintentar.';
g3.codigos = new Set<String>{ 'R16' };
grupos.put('congelada', g3);

Set<String> allCodes = new Set<String>{ 'R02', 'R04', 'R13', 'R10', 'R07', 'R16' };
List<SM_Payment__c> allPayments = [
    SELECT Id, Name, SM_Amount__c, CreatedDate, SM_Return_code__c,
           SM_Contract__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status,
           SM_Contract__r.SM_Customer_Cancellation__c,
           SM_Contract__r.Is_Test_Contract__c, SM_Contract__r.Is_VIP_Contract__c
    FROM SM_Payment__c
    WHERE SM_Return_code__c IN :allCodes
    ORDER BY SM_Contract__r.ContractNumber, CreatedDate
];

Set<Id> contractIds = new Set<Id>();
for (SM_Payment__c p : allPayments) {
    if (p.SM_Contract__c == null || p.SM_Contract__r == null) continue;
    if (CLOSED.contains(p.SM_Contract__r.Status) || p.SM_Contract__r.SM_Customer_Cancellation__c == true
        || p.SM_Contract__r.Is_Test_Contract__c == true || p.SM_Contract__r.Is_VIP_Contract__c == true) continue;
    contractIds.add(p.SM_Contract__c);
    for (Grupo g : grupos.values()) {
        if (g.codigos.contains(p.SM_Return_code__c)) {
            g.payments.add(p);
        }
    }
}

Map<Id, List<Date>> acceptedDatesByContract = new Map<Id, List<Date>>();
if (!contractIds.isEmpty()) {
    for (SM_Payment__c p : [SELECT SM_Contract__c, CreatedDate FROM SM_Payment__c
                             WHERE SM_Contract__c IN :contractIds AND Payment_Status__c = 'ACCEPTED']) {
        if (!acceptedDatesByContract.containsKey(p.SM_Contract__c)) {
            acceptedDatesByContract.put(p.SM_Contract__c, new List<Date>());
        }
        acceptedDatesByContract.get(p.SM_Contract__c).add(p.CreatedDate.date());
    }
}

class ContratoResumen {
    String contractNumber;
    String status;
    Decimal total = 0;
    Integer cantidad = 0;
    Date primero;
    Date ultimo;
    Boolean resuelto = false;
    Boolean nuevoEstaSemana = false;
}

String resumenLine = '';
String bodyDetalle = '';
Decimal granTotal = 0;
Integer granContratos = 0;

for (String key : new List<String>{ 'metodo', 'disputa', 'congelada' }) {
    Grupo g = grupos.get(key);
    Map<Id, ContratoResumen> porContrato = new Map<Id, ContratoResumen>();
    for (SM_Payment__c p : g.payments) {
        Date pd = p.CreatedDate.date();
        if (!porContrato.containsKey(p.SM_Contract__c)) {
            ContratoResumen cr = new ContratoResumen();
            cr.contractNumber = p.SM_Contract__r.ContractNumber;
            cr.status = p.SM_Contract__r.Status;
            cr.primero = pd;
            cr.ultimo = pd;
            porContrato.put(p.SM_Contract__c, cr);
        }
        ContratoResumen cr = porContrato.get(p.SM_Contract__c);
        cr.cantidad++;
        cr.total += (p.SM_Amount__c != null ? p.SM_Amount__c : 0);
        if (pd < cr.primero) cr.primero = pd;
        if (pd > cr.ultimo) cr.ultimo = pd;
        if (pd >= sinceWeek) cr.nuevoEstaSemana = true;
    }
    for (Id cId : porContrato.keySet()) {
        ContratoResumen cr = porContrato.get(cId);
        for (Date d : acceptedDatesByContract.containsKey(cId) ? acceptedDatesByContract.get(cId) : new List<Date>()) {
            if (d > cr.ultimo) cr.resuelto = true;
        }
    }

    List<ContratoResumen> nuevosSemana = new List<ContratoResumen>();
    List<ContratoResumen> backlog = new List<ContratoResumen>();
    List<ContratoResumen> resueltos = new List<ContratoResumen>();
    Decimal groupTotal = 0;
    for (ContratoResumen cr : porContrato.values()) {
        if (cr.resuelto) {
            resueltos.add(cr);
        } else if (cr.nuevoEstaSemana) {
            nuevosSemana.add(cr);
            groupTotal += cr.total;
        } else {
            backlog.add(cr);
            groupTotal += cr.total;
        }
    }

    resumenLine += '  ' + g.titulo + pad.rep(' ', Math.max(1, 35 - g.titulo.length()))
        + (nuevosSemana.size() + backlog.size()) + ' contrato(s)   $' + groupTotal.format()
        + '   (' + nuevosSemana.size() + ' nuevo(s) esta semana)\n';
    granTotal += groupTotal;
    granContratos += nuevosSemana.size() + backlog.size();

    bodyDetalle += '========================================================================\n';
    bodyDetalle += g.titulo + '\n';
    bodyDetalle += g.accion + '\n\n';

    if (nuevosSemana.isEmpty() && backlog.isEmpty()) {
        bodyDetalle += '  Sin contratos pendientes en esta categoria.\n\n';
    } else {
        for (Integer i = 0; i < nuevosSemana.size(); i++) {
            for (Integer j = i + 1; j < nuevosSemana.size(); j++) {
                if (nuevosSemana[j].total > nuevosSemana[i].total) {
                    ContratoResumen tmp = nuevosSemana[i]; nuevosSemana[i] = nuevosSemana[j]; nuevosSemana[j] = tmp;
                }
            }
        }
        for (Integer i = 0; i < backlog.size(); i++) {
            for (Integer j = i + 1; j < backlog.size(); j++) {
                if (backlog[j].total > backlog[i].total) {
                    ContratoResumen tmp = backlog[i]; backlog[i] = backlog[j]; backlog[j] = tmp;
                }
            }
        }

        if (!nuevosSemana.isEmpty()) {
            bodyDetalle += '  NUEVO ESTA SEMANA (' + nuevosSemana.size() + '):\n';
            for (ContratoResumen cr : nuevosSemana) {
                bodyDetalle += '  - Contrato ' + cr.contractNumber + ' (' + cr.status + ') - '
                    + cr.cantidad + ' pago(s) rechazado(s), $' + cr.total.format()
                    + ' - ' + cr.primero.format() + ' a ' + cr.ultimo.format() + '\n';
            }
            bodyDetalle += '\n';
        }
        if (!backlog.isEmpty()) {
            bodyDetalle += '  BACKLOG ACUMULADO (' + backlog.size() + ', sin novedad esta semana):\n';
            for (ContratoResumen cr : backlog) {
                bodyDetalle += '  - Contrato ' + cr.contractNumber + ' (' + cr.status + ') - '
                    + cr.cantidad + ' pago(s) rechazado(s), $' + cr.total.format()
                    + ' - ' + cr.primero.format() + ' a ' + cr.ultimo.format() + '\n';
            }
            bodyDetalle += '\n';
        }
    }

    if (!resueltos.isEmpty()) {
        bodyDetalle += '  Ya resueltos (' + resueltos.size() + ', pago aceptado despues del ultimo rechazo -- no requieren accion): ';
        List<String> nums = new List<String>();
        for (ContratoResumen cr : resueltos) { nums.add(cr.contractNumber); }
        bodyDetalle += String.join(nums, ', ') + '\n\n';
    }
}

String header = 'NOVEDADES ACH PARA COMERCIAL - Semana del ' + sinceWeek.format() + ' al ' + Date.today().format() + '\n'
    + '========================================================================\n\n'
    + 'RESUMEN\n' + resumenLine
    + '  ' + pad.rep('-', 50) + '\n'
    + '  TOTAL' + pad.rep(' ', 31) + granContratos + ' contrato(s)   $' + granTotal.format() + '\n\n';

String fullBody = header + bodyDetalle;
System.debug('===BODY START===');
System.debug(fullBody);
System.debug('===BODY END===');
System.debug('LENGTH: ' + fullBody.length());
