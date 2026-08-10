// ┌──────────────────────────────────────────────────────────────────────┐
// │ STOP DE ACH ORDERS PARA CONTRATOS EN "CUSTOMER CANCELLATION"          │
// │ Ejecutar ANTES de correr SM_PaymentBatch.                             │
// │                                                                        │
// │ Nota: el bloqueo real de cobro ya vive en SM_PaymentBatch /            │
// │ SM_PaymentHelper.createPayment (filtran por                           │
// │ Contract.SM_Customer_Cancellation__c). Este script es de              │
// │ higiene/visibilidad: deja el status del ACH Order reflejando la       │
// │ realidad (Stopped) para reportes y agentes, no es la barrera de       │
// │ seguridad en si.                                                      │
// └──────────────────────────────────────────────────────────────────────┘

// false = modo preview: solo muestra que se eliminaria/actualizaria, no ejecuta DML.
// true  = ejecuta de verdad el delete de payments y el update de los ACH Orders.
Boolean confirmarActualizacion = true;

// 1. Contratos en negociacion (Customer Cancellation = TRUE)
List<Contract> contratos = [
    SELECT Id, ContractNumber, Status
    FROM Contract
    WHERE SM_Customer_Cancellation__c = TRUE
];

if (contratos.isEmpty()) {
    System.debug(' \u2192 ❌ No se encontraron contratos en Customer Cancellation');
} else {
    System.debug(' \u2192 ✔ Contratos en Customer Cancellation: ' + contratos.size());

    // 2. ACH Orders activos de esos contratos (aun no estan en un status terminal)
    List<SM_ACH_Order__c> achOrds = [
        SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status
        FROM SM_ACH_Order__c
        WHERE SM_Contract__c IN :contratos
        AND SM_Payment_Status__c IN ('Initiated', 'Pending', 'Created')
    ];

    System.debug(LoggingLevel.INFO, ' \u2192 ACH Orders candidatos: ' + achOrds.size());

    // 3. Payments en ACH PENDING relacionados a esos ACH Orders (se eliminarian)
    List<SM_Payment__c> pagosAEliminar = new List<SM_Payment__c>();
    if (!achOrds.isEmpty()) {
        pagosAEliminar = [
            SELECT Id, Name, SM_ACH_Order__c
            FROM SM_Payment__c
            WHERE SM_ACH_Order__c IN :achOrds
            AND Payment_Status__c = 'ACH PENDING'
        ];
    }

    // 4. Preparar el update de ACH Orders a Stopped, guardando el estatus anterior para el log
    List<SM_ACH_Order__c> achParaActualizar = new List<SM_ACH_Order__c>();
    Map<Id, String> estatusAnteriorPorOrder = new Map<Id, String>();

    for (SM_ACH_Order__c ord : achOrds) {
        estatusAnteriorPorOrder.put(ord.Id, ord.SM_Payment_Status__c);
        ord.SM_Payment_Status__c = 'Stopped';
        achParaActualizar.add(ord);
    }

    // 5. Mostrar SIEMPRE el detalle de lo que se eliminaria/actualizaria (preview o real)
    System.debug(' \u2192 Payments en ACH PENDING que se eliminarian: ' + pagosAEliminar.size());
    for (SM_Payment__c p : pagosAEliminar) {
        System.debug(' \u2192   Payment: ' + p.Name + ' (Id: ' + p.Id + ') - ACH Order: ' + p.SM_ACH_Order__c);
    }

    System.debug(' \u2192 ACH Orders que cambiarian a Stopped: ' + achParaActualizar.size());
    System.debug(' \u2192 Nombre \uFF5C Estatus anterior \uFF5C Contrato \uFF5C Estatus del contrato');
    for (SM_ACH_Order__c ord : achParaActualizar) {
        System.debug(' \u2192   ' + ord.Name
            + ' \uFF5C ' + estatusAnteriorPorOrder.get(ord.Id)
            + ' \uFF5C ' + ord.SM_Contract__r.ContractNumber
            + ' \uFF5C ' + ord.SM_Contract__r.Status);
    }

    // 6. Ejecutar los cambios solo si confirmarActualizacion = true
    if (confirmarActualizacion) {
        if (!pagosAEliminar.isEmpty()) {
            delete pagosAEliminar;
            System.debug(' \u2192 🗑 Payments en ACH PENDING eliminados: ' + pagosAEliminar.size());
        }
        if (!achParaActualizar.isEmpty()) {
            update achParaActualizar;
            System.debug(' \u2192 ✅ ACH Orders actualizados a Stopped: ' + achParaActualizar.size());
        }
    } else {
        System.debug(' \u2192 ℹ️ MODO PREVIEW (confirmarActualizacion = false): no se ejecuto ningun cambio. '
            + 'Cambia la variable a true y vuelve a correr el script para aplicar los cambios de verdad.');
    }
}

System.debug(' \u2192 ────────────────────────────────────────');
System.debug(' \u2192 PROCESO COMPLETADO PARA ACH Orders EN CUSTOMER CANCELLATION');
