// ============================================================
//  ACTIVAR ACH ORDER "Late payment fee" — PAGOS AC NOT COLLECTED
// ============================================================
// Tarea: por cada pago "AC" (SM_Type__c = 'AC' o SM_Original_Type__c = 'AC')
// que esté REJECTED / NOT COLLECTED, busca su SM_ACH_Order__c de tipo
// "Late payment fee" vinculado (SM_Failed_payment__c) y lo activa
// (Stopped/Created => Initiated), replicando la misma condición "Iniciar"
// que ya usa -A.MASTER_2026_v6 ach-tc-Batch.apex, pero acotado SOLO a AC
// (no toca Fee/Subscription/TC).
//
// "NOT COLLECTED" = SM_Check_Collection_Status__c = 'NOT_COLLECTED' (o 'NOT COLLECTED').
// OJO: SM_Check_Collection_Status__c es texto libre, no picklist — NO usar
// Payment_Status__c = 'REJECTED' como criterio alternativo, porque un pago
// puede estar REJECTED y seguir con SM_Check_Collection_Status__c en 'RETURN'
// o 'PENDING' (todavía sin resolver) o incluso terminar en 'COLLECTED'.
// Activar con solo REJECTED cobra el Late Payment Fee antes de tiempo.
//
// Se activa solo si:
//   • El contrato está elegible: Status IN ('Activated','Payment Process')
//     AND SM_Customer_Cancellation__c = false.
//   • Ese ACH Order específico NO tiene Payments en proceso
//     (SM_Check_Collection_Status__c IN ('Pending','Return')
//      OR Payment_Status__c = 'ACH TRANSMITTED').
//   • No está ya en 'Initiated'.
//
// Sin restricción de fecha: toma cualquier pago AC NOT COLLECTED pendiente,
// no solo el último mes (una vez rechazado, sigue pendiente de activar
// el Late Payment Fee hasta que se resuelva). Si se necesita acotar por
// fecha, descomentar el filtro FECHA_DESDE más abajo.
//
// MODO SEGURO por defecto: confirmarActualizacion = false (solo reporta,
// no hace ningún update). Cambiar a true para aplicar.
// ============================================================

Boolean confirmarActualizacion = false;
Date    hoy = Date.today();
// Date FECHA_DESDE = Date.today().addMonths(-1).toStartOfMonth(); // ej: solo último mes

Set<String> NOT_COLLECTED_VARIANTS = new Set<String>{
    'NOT_COLLECTED', 'NOT COLLECTED'
};

// ============================================================
// 1. PAGOS AC NOT COLLECTED
// ============================================================
List<SM_Payment__c> pagosAC = [
    SELECT  Id, Name, SM_Contract__c,
            SM_Contract__r.ContractNumber, SM_Contract__r.Status,
            SM_Contract__r.SM_Customer_Cancellation__c,
            SM_Type__c, SM_Original_Type__c,
            Payment_Status__c, SM_Check_Collection_Status__c,
            SM_Payment_execution_date__c, SM_Payment_Date__c, SM_Net_Amount__c
    FROM    SM_Payment__c
    WHERE   (SM_Type__c = 'AC' OR SM_Original_Type__c = 'AC')
      AND   SM_Check_Collection_Status__c IN :NOT_COLLECTED_VARIANTS
      AND   SM_Contract__r.SM_Customer_Cancellation__c = false
      //AND  SM_Contract__r.ContractNumber = '00317863'
    //  AND   SM_Payment_execution_date__c >= :FECHA_DESDE
];

Map<Id, SM_Payment__c> pagoFallidoPorId = new Map<Id, SM_Payment__c>();
for (SM_Payment__c p : pagosAC) pagoFallidoPorId.put(p.Id, p);

if (pagoFallidoPorId.isEmpty()) {
    System.debug(' \u2192 No hay pagos AC NOT COLLECTED pendientes.');
    return;
}

// ============================================================
// 2. ACH ORDERS "Late payment fee" VINCULADOS A ESOS PAGOS
// ============================================================
List<SM_ACH_Order__c> lateFeeOrders = [
    SELECT  Id, Name, SM_Payment_Type__c, SM_Payment_Status__c,
            SM_Failed_payment__c, SM_Next_Transaction_Date__c,
            SM_PTP_Montly__c, Total_Amount__c,
            SM_Contract__c, SM_Contract__r.ContractNumber
    FROM    SM_ACH_Order__c
    WHERE   SM_Failed_payment__c IN :pagoFallidoPorId.keySet()
      AND   SM_Payment_Type__c = 'Late payment fee'
      AND   SM_Payment_Status__c NOT IN ('Canceled', 'Completed', 'Initiated')
];

if (lateFeeOrders.isEmpty()) {
    System.debug(' \u2192 No hay ACH Orders "Late payment fee" pendientes de activar para esos pagos.');
    return;
}

Set<Id> lateFeeOrderIds = new Map<Id, SM_ACH_Order__c>(lateFeeOrders).keySet();

// ============================================================
// 3. PAYMENTS EN PROCESO POR ACH ORDER (para no pisar cobros en curso)
// ============================================================
Map<Id, Set<String>> achOrderConPagosEnProceso = new Map<Id, Set<String>>();
for (SM_Payment__c p : [
    SELECT Id, SM_ACH_Order__c, SM_Check_Collection_Status__c, Payment_Status__c
    FROM   SM_Payment__c
    WHERE  SM_ACH_Order__c IN :lateFeeOrderIds
      AND  (SM_Check_Collection_Status__c IN ('Pending', 'Return')
            OR Payment_Status__c = 'ACH TRANSMITTED')
]) {
    if (!achOrderConPagosEnProceso.containsKey(p.SM_ACH_Order__c)) {
        achOrderConPagosEnProceso.put(p.SM_ACH_Order__c, new Set<String>());
    }
    if (p.SM_Check_Collection_Status__c != null) {
        achOrderConPagosEnProceso.get(p.SM_ACH_Order__c).add(p.SM_Check_Collection_Status__c);
    }
    if (p.Payment_Status__c == 'ACH TRANSMITTED') {
        achOrderConPagosEnProceso.get(p.SM_ACH_Order__c).add('Transmitted');
    }
}

// ============================================================
// 4. CLASIFICAR: ACTIVAR / SKIP (no elegible) / BLOQUEADO (pago en proceso)
// ============================================================
List<SM_ACH_Order__c> toUpdate = new List<SM_ACH_Order__c>();
List<String> lineasActivar   = new List<String>();
List<String> lineasSkip      = new List<String>();
List<String> lineasBloqueado = new List<String>();

for (SM_ACH_Order__c o : lateFeeOrders) {
    SM_Payment__c fallido = pagoFallidoPorId.get(o.SM_Failed_payment__c);
    if (fallido == null) continue; // no debería pasar, pero por seguridad

    Boolean contratoElegible =
        (fallido.SM_Contract__r.Status == 'Activated' || fallido.SM_Contract__r.Status == 'Payment Process')
        && fallido.SM_Contract__r.SM_Customer_Cancellation__c != true;

    if (!contratoElegible) {
        lineasSkip.add(' \u2192 SKIP ' + o.SM_Contract__r.ContractNumber + ' (' + o.Name
            + ') ▪️ Contrato no elegible (Status: ' + fallido.SM_Contract__r.Status
            + ', Cancelacion: ' + fallido.SM_Contract__r.SM_Customer_Cancellation__c + ')');
        continue;
    }

    if (achOrderConPagosEnProceso.containsKey(o.Id)) {
        lineasBloqueado.add(' \u2192 BLOQUEADO ' + o.SM_Contract__r.ContractNumber + ' (' + o.Name
            + ') ▪️ Payments en proceso: '
            + String.join(new List<String>(achOrderConPagosEnProceso.get(o.Id)), ', '));
        continue;
    }

    o.SM_Payment_Status__c        = 'Initiated';
    o.SM_Next_Transaction_Date__c = hoy;
   
   o.SM_PTP_Montly__c = 'AC'
   /* o.SM_PTP_Montly__c = fallido.SM_Payment_Date__c != null
        ? DateTime.newInstance(fallido.SM_Payment_Date__c, Time.newInstance(0, 0, 0, 0)).format('MMM')
        : o.SM_PTP_Montly__c
    */;

    toUpdate.add(o);
    lineasActivar.add(' \u2192 ACTIVAR ' + o.SM_Contract__r.ContractNumber + ' (' + o.Name
        + ') ▪️ $' + o.Total_Amount__c + ' ▪️ PTP: ' + o.SM_PTP_Montly__c
        + ' ▪️ Pago fallido: ' + fallido.Name);
}

// ============================================================
// 5. REPORTE
// ============================================================
String sep = ''.leftPad(140, '─');
System.debug(' \u2192 ' + sep);
System.debug(' \u2192 Pagos AC NOT COLLECTED encontrados: ' + pagosAC.size());
System.debug(' \u2192 ACH Orders "Late payment fee" candidatos: '   + lateFeeOrders.size());
System.debug(' \u2192 A ACTIVAR: '  + toUpdate.size());
System.debug(' \u2192 SKIP (contrato no elegible): '   + lineasSkip.size());
System.debug(' \u2192 BLOQUEADOS (pago en proceso): '  + lineasBloqueado.size());
System.debug(' \u2192 ' + sep);
if (!lineasActivar.isEmpty())   System.debug('\n' + String.join(lineasActivar, '\n'));
if (!lineasSkip.isEmpty())      System.debug('\n' + String.join(lineasSkip, '\n'));
if (!lineasBloqueado.isEmpty()) System.debug('\n' + String.join(lineasBloqueado, '\n'));
System.debug(' \u2192 ' + sep);

// ============================================================
// 6. DML (solo si confirmarActualizacion = true)
// ============================================================
if (confirmarActualizacion) {
    Database.SaveResult[] saves = Database.update(toUpdate, false);
    Integer ok = 0, fail = 0;
    for (Integer i = 0; i < saves.size(); i++) {
        if (saves[i].isSuccess()) {
            ok++;
        } else {
            fail++;
            List<String> msgs = new List<String>();
            for (Database.Error e : saves[i].getErrors()) msgs.add(e.getMessage());
            System.debug(' \u2192 ❌ Error activando ' + toUpdate[i].Name + ': ' + String.join(msgs, '; '));
        }
    }
    System.debug(' \u2192 ✅ Activados: ' + ok + '   ❌ Fallidos: ' + fail);
} else {
    System.debug(' \u2192 ⚠️ MODO SEGURO: no se ejecutó ningún update. Cambia confirmarActualizacion = true para aplicar.');
}
