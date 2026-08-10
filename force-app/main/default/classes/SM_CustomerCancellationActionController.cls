/**
 * @description: Marca un Contrato como Customer Cancellation y detiene (Stopped) sus ACH Orders
 *               activos. Solo un usuario con profile "System Administrator" puede eliminar los
 *               Payments en ACH PENDING asociados (esos payments ya fueron generados por el batch
 *               diario y estan pendientes del reporte manual de transmision, asi que borrarlos
 *               requiere autorizacion). Invocado desde un Quick Action LWC en el registro de Contract.
 * @author: Carlos Alberto Lopez Prada
 * @date: Agosto 2026
 */
public with sharing class SM_CustomerCancellationActionController {

    private static final Set<String> ESTATUS_ELEGIBLES = new Set<String>{'Initiated', 'Pending', 'Created'};
    private static final String PROFILE_ADMINISTRADOR = 'System Administrator';

    public class PreviewResult {
        @AuraEnabled public Boolean yaMarcado;
        @AuraEnabled public Integer cantidadOrdenes;
        @AuraEnabled public Integer cantidadPayments;
        @AuraEnabled public Boolean esAdministrador;
        @AuraEnabled public List<OrdenDetalle> ordenes;
    }

    public class OrdenDetalle {
        @AuraEnabled public String nombre;
        @AuraEnabled public String estatusAnterior;
        @AuraEnabled public String contrato;
        @AuraEnabled public String estatusContrato;
    }

    public class ResultadoAccion {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String mensaje;
        @AuraEnabled public Integer ordenesActualizadas;
        @AuraEnabled public Integer paymentsEliminados;
        @AuraEnabled public Integer paymentsPendientesDeRevision;
        @AuraEnabled public List<OrdenDetalle> detalle;
    }

    /**
    * @description Muestra el impacto de marcar el contrato como Customer Cancellation, sin modificar nada.
    * @param contractId
    * @return PreviewResult
    **/
    @AuraEnabled(cacheable=true)
    public static PreviewResult obtenerPreview(Id contractId) {
        PreviewResult resultado = new PreviewResult();

        Contract contrato = [SELECT Id, SM_Customer_Cancellation__c FROM Contract WHERE Id = :contractId];
        resultado.yaMarcado = contrato.SM_Customer_Cancellation__c;
        resultado.esAdministrador = esAdministrador();

        List<SM_ACH_Order__c> ordenes = buscarOrdenesElegibles(contractId);
        resultado.cantidadOrdenes = ordenes.size();

        resultado.ordenes = new List<OrdenDetalle>();
        for (SM_ACH_Order__c ord : ordenes) {
            resultado.ordenes.add(construirDetalle(ord));
        }

        resultado.cantidadPayments = ordenes.isEmpty() ? 0 : contarPaymentsPendientes(ordenes);

        return resultado;
    }

    /**
    * @description Marca el contrato como Customer Cancellation y detiene sus ACH Orders activos
    *              (pasan a Stopped). Los Payments en ACH PENDING asociados solo se eliminan si
    *              quien ejecuta la accion tiene el profile System Administrator; de lo contrario
    *              quedan intactos, pendientes de revision manual por un administrador.
    * @param contractId
    * @return ResultadoAccion
    **/
    @AuraEnabled
    public static ResultadoAccion marcarCustomerCancellation(Id contractId) {
        ResultadoAccion resultado = new ResultadoAccion();
        try {
            Boolean esAdmin = esAdministrador();

            update new Contract(Id = contractId, SM_Customer_Cancellation__c = true);

            List<SM_ACH_Order__c> ordenes = buscarOrdenesElegibles(contractId);

            List<SM_Payment__c> pagosPendientes = new List<SM_Payment__c>();
            if (!ordenes.isEmpty()) {
                pagosPendientes = [
                    SELECT Id
                    FROM SM_Payment__c
                    WHERE SM_ACH_Order__c IN :ordenes
                    AND Payment_Status__c = 'ACH PENDING'
                ];
            }

            List<OrdenDetalle> detalle = new List<OrdenDetalle>();
            List<SM_ACH_Order__c> paraActualizar = new List<SM_ACH_Order__c>();
            for (SM_ACH_Order__c ord : ordenes) {
                detalle.add(construirDetalle(ord));
                ord.SM_Payment_Status__c = 'Stopped';
                paraActualizar.add(ord);
            }

            Integer paymentsEliminados = 0;
            Integer paymentsPendientesDeRevision = 0;

            if (!pagosPendientes.isEmpty()) {
                if (esAdmin) {
                    delete pagosPendientes;
                    paymentsEliminados = pagosPendientes.size();
                } else {
                    paymentsPendientesDeRevision = pagosPendientes.size();
                }
            }

            if (!paraActualizar.isEmpty()) {
                update paraActualizar;
            }

            resultado.success = true;
            resultado.ordenesActualizadas = paraActualizar.size();
            resultado.paymentsEliminados = paymentsEliminados;
            resultado.paymentsPendientesDeRevision = paymentsPendientesDeRevision;
            resultado.detalle = detalle;

            resultado.mensaje = 'Contrato marcado como Customer Cancellation. ' + paraActualizar.size() + ' ACH Order(s) pasaron a Stopped.';
            if (paymentsEliminados > 0) {
                resultado.mensaje += ' ' + paymentsEliminados + ' payment(s) en ACH PENDING fueron eliminados.';
            }
            if (paymentsPendientesDeRevision > 0) {
                resultado.mensaje += ' ' + paymentsPendientesDeRevision + ' payment(s) en ACH PENDING ya generados por el batch quedaron SIN eliminar '
                    + '(requieren que un administrador los revise y elimine).';
            }

        } catch (Exception e) {
            resultado.success = false;
            resultado.mensaje = 'Error: ' + e.getMessage();
        }
        return resultado;
    }

    private static Boolean esAdministrador() {
        Profile perfil = [SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        return perfil.Name == PROFILE_ADMINISTRADOR;
    }

    private static List<SM_ACH_Order__c> buscarOrdenesElegibles(Id contractId) {
        return [
            SELECT Id, Name, SM_Payment_Status__c, SM_Contract__r.ContractNumber, SM_Contract__r.Status
            FROM SM_ACH_Order__c
            WHERE SM_Contract__c = :contractId
            AND SM_Payment_Status__c IN :ESTATUS_ELEGIBLES
        ];
    }

    private static Integer contarPaymentsPendientes(List<SM_ACH_Order__c> ordenes) {
        return [
            SELECT COUNT()
            FROM SM_Payment__c
            WHERE SM_ACH_Order__c IN :ordenes
            AND Payment_Status__c = 'ACH PENDING'
        ];
    }

    private static OrdenDetalle construirDetalle(SM_ACH_Order__c ord) {
        OrdenDetalle d = new OrdenDetalle();
        d.nombre = ord.Name;
        d.estatusAnterior = ord.SM_Payment_Status__c;
        d.contrato = ord.SM_Contract__r.ContractNumber;
        d.estatusContrato = ord.SM_Contract__r.Status;
        return d;
    }
}
