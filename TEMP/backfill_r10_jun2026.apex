/*
 * backfill_r10_jun2026.apex
 * --------------------------
 * Instruccion explicita del usuario (2026-09-15): todo Payment de Junio
 * 2026 a la fecha que aparezca en los reportes de RETURN/COLLECTION como
 * R10 (Customer Advises Not Authorized) debe quedar en
 * Payment_Status__c = REJECTED, SM_Check_Collection_Status__c = NOT_COLLECTED,
 * SM_Return_code__c = R10, y con la razon real del reporte en
 * SM_Check_Collection_Return_Reason__c.
 *
 * Alcance identificado (TEMP/r10_backfill_scope.py, validado contra el
 * "reporte ganador" mas reciente por payment desde 2026-06-01): 23 pagos.
 * De esos, 21 ya estaban REJECTED pero con SM_Check_Collection_Status__c
 * en PENDING/RETURN (nunca se resolvieron a un estado final) y 2
 * (PY-01868816, PY-01885207 -- contrato 00316444, el caso de disputa que
 * origino este pedido) estaban incorrectamente en ACCEPTED/COLLECTED.
 *
 * NO debe disparar ningun automatismo (instruccion explicita) -- se usa
 * SM_TriggerHandler.avoidAllHandlerExcecution = true antes del update,
 * igual que en el backfill de SM_Return_code__c del 2026-09-14.
 *
 * Corre primero con DRY_RUN = true -> solo imprime el preview, NO
 * actualiza nada. Cuando el usuario autorice, cambiar a false.
 */

Boolean DRY_RUN = false; // Autorizado por el usuario 2026-09-15 tras revisar el preview

class PaymentFix {
    String paymentName;
    String reason;
    PaymentFix(String n, String r) {
        this.paymentName = n;
        this.reason = r;
    }
}

List<PaymentFix> fixes = new List<PaymentFix>{
        new PaymentFix('PY-01847651', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01847653', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01849219', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01849469', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01859586', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01859726', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01865165', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01868816', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01869482', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01872218', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01872289', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01880352', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01880378', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01880427', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01883331', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01884599', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01884645', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01884676', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01884692', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01885207', 'CUSTOMER ADVISES NOT AUTHORIZED'),
        new PaymentFix('PY-01889059', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01889111', 'R10 CUST ADV NOT'),
        new PaymentFix('PY-01894616', 'R10 CUST ADV NOT')
};

Map<String, PaymentFix> fixByName = new Map<String, PaymentFix>();
List<String> names = new List<String>();
for (PaymentFix pf : fixes) {
    fixByName.put(pf.paymentName, pf);
    names.add(pf.paymentName);
}

Map<Id, SM_Payment__c> current = new Map<Id, SM_Payment__c>([
        SELECT Id, Name, Payment_Status__c, SM_Check_Collection_Status__c,
               SM_Return_code__c, SM_Check_Collection_Return_Reason__c,
               SM_Historical_Collection_Status__c, SM_Contract__r.ContractNumber
        FROM SM_Payment__c
        WHERE Name IN :names
]);

System.debug('=======================================================');
System.debug(' -> MODO: ' + (DRY_RUN ? 'DRY RUN (solo preview, sin cambios)' : 'EJECUCION REAL (se va a actualizar)'));
System.debug(' -> Candidatos encontrados en Salesforce: ' + current.size() + ' / ' + fixes.size());
System.debug('=======================================================');

List<SM_Payment__c> toUpdate = new List<SM_Payment__c>();

for (SM_Payment__c p : current.values()) {
    PaymentFix pf = fixByName.get(p.Name);
    if (pf == null) {
        continue;
    }

    String tag = 'PRC_AUT_R10_BACKFILL_JUN2026: REJECTED/NOT_COLLECTED //';
    String newHistorical = tag + (String.isBlank(p.SM_Historical_Collection_Status__c) ? '' : p.SM_Historical_Collection_Status__c);
    if (newHistorical.length() > 150) {
        newHistorical = newHistorical.substring(0, 150);
    }

    System.debug('---------------------------------------------------------');
    System.debug(p.Name + '  (Contrato ' + p.SM_Contract__r.ContractNumber + ')');
    System.debug('  ACTUAL -> Payment_Status=' + p.Payment_Status__c +
            ' | Collection_Status=' + p.SM_Check_Collection_Status__c +
            ' | Return_Code=' + p.SM_Return_code__c +
            ' | Reason=' + p.SM_Check_Collection_Return_Reason__c);
    System.debug('  NUEVO  -> Payment_Status=REJECTED | Collection_Status=NOT_COLLECTED' +
            ' | Return_Code=R10 | Reason=' + pf.reason);
    System.debug('  Historico nuevo -> ' + newHistorical);

    SM_Payment__c upd = new SM_Payment__c(
            Id = p.Id,
            Payment_Status__c = 'REJECTED',
            SM_Check_Collection_Status__c = 'NOT_COLLECTED',
            SM_Return_code__c = 'R10',
            SM_Check_Collection_Return_Reason__c = pf.reason,
            SM_Historical_Collection_Status__c = newHistorical
    );
    toUpdate.add(upd);
}

System.debug('=======================================================');
System.debug(' -> Total a actualizar: ' + toUpdate.size());
System.debug('=======================================================');

if (!DRY_RUN) {
    SM_TriggerHandler.avoidAllHandlerExcecution = true;
    Database.SaveResult[] results = Database.update(toUpdate, false);
    Integer ok = 0;
    Integer fail = 0;
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            ok++;
        } else {
            fail++;
            System.debug(' -> ERROR en ' + sr.getId() + ': ' + sr.getErrors());
        }
    }
    System.debug(' -> Actualizados OK: ' + ok + '  |  Fallidos: ' + fail);
} else {
    System.debug(' -> DRY RUN: no se realizo ningun cambio. Cambiar DRY_RUN a false para ejecutar.');
}
