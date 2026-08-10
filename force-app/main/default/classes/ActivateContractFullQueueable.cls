public class ActivateContractFullQueueable implements Queueable {

    private String contractNumber;

    public ActivateContractFullQueueable(String contractNumber) {
        this.contractNumber = contractNumber;
    }

    public void execute(QueueableContext qc) {

        System.debug('────────────────────────────────────────────');
        System.debug('→ Procesando contrato: ' + contractNumber);

        // Estados inválidos
        Set<String> estadosInvalidos = new Set<String>{
            'Finalized', 'Cancelled', 'Canceled', 'Draft', 'Complete information'
        };

        // Estados cerrados de Payments
        Set<String> estadosCerrados = new Set<String>{
            'NOT_COLLECTED', 'COLLECTED', 'ACCEPTED', 'REFUNDED'
        };

        // 1️⃣ Consultar contrato
        Contract c;
        try {
            c = [
                SELECT Id, SM_Net_AC__c, SM_Charged_AC_Fees__c, SM_Charged_AC_Amount__c,
                       SM_AC_collected__c, SM_Payment_Received__c, SM_Start_date__c,
                       SM_AC_Split_Date__c, Status, ContractNumber
                FROM Contract
                WHERE ContractNumber = :contractNumber
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('→ ❌ Contrato no encontrado: ' + contractNumber);
            return;
        }

        // 2️⃣ Validaciones
        if (c.Status == 'Activated') {
            System.debug('→ ⚠️ Ya está ACTIVATED. No se procesa.');
            return;
        }

        if (c.SM_AC_Split_Date__c != null) {
            System.debug('→ ⚠️ Tiene Split Date. No se procesa.');
            return;
        }

        if (estadosInvalidos.contains(c.Status)) {
            System.debug('→ ⚠️ Estado inválido (' + c.Status + '). No se procesa.');
            return;
        }

        // 3️⃣ Consultar pagos AC
        List<SM_Payment__c> payments = [
            SELECT Id, Name, Payment_Status__c, SM_Payment_Date__c,
                   SM_Net_Amount__c, SM_Original_Type__c, SM_Type__c
            FROM SM_Payment__c
            WHERE SM_Contract__c = :c.Id
            ORDER BY SM_Payment_Date__c DESC
        ];

        Integer countPayments = 0;

        for (SM_Payment__c p : payments) {
            if ((p.SM_Original_Type__c == 'AC' || p.SM_Type__c == 'AC') &&
                 p.Payment_Status__c == 'ACCEPTED') {

                countPayments++;
                System.debug('→ ✔ Pago AC válido: ' + p.Name +
                             ' 🔸 Monto: ' + p.SM_Net_Amount__c +
                             ' 🔸 Fecha: ' + p.SM_Payment_Date__c);
            }
        }

        System.debug('→ Total pagos AC válidos: ' + countPayments);

        // 4️⃣ Reglas de negocio AC
        if (countPayments == 0) {
            System.debug('→ ❌ No hay pagos AC válidos. No se activa.');
            return;
        }

        if (c.SM_AC_Split_Date__c == null && countPayments == 1) {
            c.SM_Charged_AC_Fees__c = 1;
            System.debug('→ 1 pago AC, SplitDate NULL → Fees = 1');
        }
        else if (c.SM_AC_Split_Date__c != null && countPayments == 2) {
            c.SM_Charged_AC_Fees__c = 2;
            System.debug('→ 2 pagos AC, SplitDate NO NULL → Fees = 2');
        }
        else if (countPayments > 2) {
            System.debug('→ ⚠️ Pagos AC adicionales. Validar duplicados.');
            return;
        }
        else {
            System.debug('→ ⚠️ Cantidad de pagos AC no coincide con reglas.');
            return;
        }

        // 5️⃣ Activación del contrato
        c.Status = 'Activated';
        c.SM_Charged_AC_Amount__c = c.SM_Net_AC__c;
        c.SM_AC_collected__c = true;
        c.SM_Payment_Received__c = true;

        update c;

        System.debug('→ ✅ Contrato ACTIVADO: ' + c.ContractNumber);

        // ────────────────────────────────────────────────────────────────
        // 6️⃣ PROCESAR ACH ORDERS
        // ────────────────────────────────────────────────────────────────

        List<SM_ACH_Order__c> achOrds = [
            SELECT Id, Name, SM_Payment_Status__c
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :c.Id
        ];

        List<SM_Payment__c> pagos = [
            SELECT Id, SM_Check_Collection_Status__c, SM_ACH_Order__c
            FROM SM_Payment__c
            WHERE SM_ACH_Order__c IN :achOrds
        ];

        Map<Id, List<SM_Payment__c>> pagosPorOrder = new Map<Id, List<SM_Payment__c>>();

        for (SM_Payment__c p : pagos) {
            if (!pagosPorOrder.containsKey(p.SM_ACH_Order__c)) {
                pagosPorOrder.put(p.SM_ACH_Order__c, new List<SM_Payment__c>());
            }
            pagosPorOrder.get(p.SM_ACH_Order__c).add(p);
        }

        List<SM_ACH_Order__c> achParaActualizar = new List<SM_ACH_Order__c>();

        for (SM_ACH_Order__c ord : achOrds) {

            Boolean tienePagosEnProceso = false;

            if (pagosPorOrder.containsKey(ord.Id)) {
                for (SM_Payment__c p : pagosPorOrder.get(ord.Id)) {
                    if (!estadosCerrados.contains(p.SM_Check_Collection_Status__c)) {
                        tienePagosEnProceso = true;
                        break;
                    }
                }
            }

            // X CANCELED
            if (tienePagosEnProceso &&
                !(
                    ord.SM_Payment_Status__c == 'cancelled' ||
                    ord.SM_Payment_Status__c == 'Canceled'  ||
                    ord.SM_Payment_Status__c == 'Complete'  ||
                    ord.SM_Payment_Status__c == 'X CANCELED'
                )
            ) {
                ord.SM_Payment_Status__c = 'X CANCELED';
                achParaActualizar.add(ord);
                System.debug('→ ⛔ X CANCELED aplicado a ACH: ' + ord.Name);
                continue;
            }

            // Canceled
            if (!tienePagosEnProceso &&
                (
                    ord.SM_Payment_Status__c == 'Stopped'   ||
                    ord.SM_Payment_Status__c == 'recurring' ||
                    ord.SM_Payment_Status__c == 'Initiated' ||
                    ord.SM_Payment_Status__c == 'pending'
                )
            ) {
                ord.SM_Payment_Status__c = 'Canceled';
                achParaActualizar.add(ord);
                System.debug('→ ✔ Canceled aplicado a ACH: ' + ord.Name);
            }
        }

        if (!achParaActualizar.isEmpty()) {
            update achParaActualizar;
            System.debug('→ ACH Orders actualizados: ' + achParaActualizar.size());
        }

        // ────────────────────────────────────────────────────────────────
        // 7️⃣ PROCESAR TC ORDERS
        // ────────────────────────────────────────────────────────────────

        List<ChargentOrders__ChargentOrder__c> tcOrds = [
            SELECT Id, Name, ChargentOrders__Payment_Status__c
            FROM ChargentOrders__ChargentOrder__c
            WHERE Contract__c = :c.Id
            AND ChargentOrders__Payment_Status__c NOT IN ('cancelled','Canceled','Complete','X CANCELED', null)
        ];

        if (!tcOrds.isEmpty()) {
            for (ChargentOrders__ChargentOrder__c tc : tcOrds) {
                tc.ChargentOrders__Payment_Status__c = 'X CANCELED';
            }
            update tcOrds;
            System.debug('→ TC Orders actualizados: ' + tcOrds.size());
        }

        System.debug('→ PROCESO COMPLETADO PARA CONTRATO ' + contractNumber);
    }
}
