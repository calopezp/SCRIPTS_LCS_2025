/**
 * @description Invocable Apex para validar tarjetas de crédito desde Flow
 * @author Carlos Lopez
 * @date 2026-05-18
 */
public without sharing class SM_ValidarTarjetaInvocable {
    
    /**
     * Clase para inputs del método invocable
     */
    public class ValidarTarjetaInput {
        @InvocableVariable(label='Número de Contrato' required=true)
        public String numeroContrato;
        
        @InvocableVariable(label='Payment Method Name (PM-000000)' required=true)
        public String paymentMethodName;
        
        @InvocableVariable(label='Últimas 4 dígitos' required=true)
        public String ultimasCuatro;
    }
    
    /**
     * Clase para outputs del método invocable
     */
    public class ValidarTarjetaOutput {
        @InvocableVariable(label='Éxito')
        public Boolean success;
        
        @InvocableVariable(label='Mensaje')
        public String message;
        
        @InvocableVariable(label='Token (parcial)')
        public String tokenParcial;
        
        @InvocableVariable(label='Errores')
        public String errores;
        
        @InvocableVariable(label='Payment Method Actualizado')
        public String paymentMethodId;
    }
    
    /**
     * @description Método invocable para validar tarjeta desde Flow
     * @param inputs Lista de inputs con datos del contrato y PM
     * @return Lista de outputs con resultados
     */
    @InvocableMethod(
        label='Validar Tarjeta de Crédito' 
        description='Valida y actualiza Payment Method en Contrato y Chargent Orders Activos'
        category='Payment Processing'
    )
    public static List<ValidarTarjetaOutput> validarTarjeta(List<ValidarTarjetaInput> inputs) {
        List<ValidarTarjetaOutput> outputs = new List<ValidarTarjetaOutput>();
        
        for (ValidarTarjetaInput input : inputs) {
            ValidarTarjetaOutput output = new ValidarTarjetaOutput();
            
            try {
                // Validar inputs
                if (String.isBlank(input.numeroContrato)) {
                    throw new ValidacionException('Número de Contrato es requerido');
                }
                if (String.isBlank(input.paymentMethodName)) {
                    throw new ValidacionException('Payment Method Name es requerido');
                }
                if (String.isBlank(input.ultimasCuatro)) {
                    throw new ValidacionException('Últimas 4 dígitos son requeridos');
                }
                
                // EJECUTAR VALIDACIÓN (lógica del script ValidaCreditCard)
                ResultadoValidacion resultado = ejecutarValidacionCompleta(
                    input.numeroContrato, 
                    input.paymentMethodName, 
                    input.ultimasCuatro
                );
                
                // Preparar output
                output.success = resultado.success;
                output.message = resultado.message;
                output.tokenParcial = resultado.tokenParcial;
                output.paymentMethodId = resultado.paymentMethodId;
                output.errores = resultado.errores;
                
            } catch (Exception e) {
                output.success = false;
                output.message = 'Error al validar tarjeta';
                output.errores = e.getMessage() + '\n' + e.getStackTraceString();
                
                // Log del error
                System.debug(LoggingLevel.ERROR, 'Error en validarTarjeta: ' + e.getMessage());
            }
            
            outputs.add(output);
        }
        
        return outputs;
    }
    
    /**
     * @description Ejecuta la validación completa (lógica del script ValidaCreditCard)
     * WITHOUT SHARING - accede a campos encriptados y realiza todas las operaciones
     */
    private static ResultadoValidacion ejecutarValidacionCompleta(
        String numeroContrato,
        String paymentMethodName,
        String ultimasCuatro
    ) {
        ResultadoValidacion resultado = new ResultadoValidacion();
        
        try {
            // 1️⃣ Obtener Contrato activo
            List<Contract> contratos = [
                SELECT Id, AccountId, Status, ContractNumber, 
                       SM_Payment_Method__c, SM_Registered_Card_Token__c,
                       SM_Billing_Address__r.State, SM_Billing_Address__r.Country
                FROM Contract
                WHERE ContractNumber = :numeroContrato
                  AND Status NOT IN ('Canceled', 'Finalized')
                LIMIT 1
            ];
            
            if (contratos.isEmpty()) {
                throw new ValidacionException('Contrato no encontrado o inactivo');
            }
            
            Contract contrato = contratos[0];
            
            // 2️⃣ Obtener Payment Method
            List<SM_Payment_Method__c> pms = [
                SELECT Id, Name, SM_Active__c, SM_Account__c,
                       SM_Card_Token__c, SM_Credit_Card_Number__c,
                       SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c,
                       CreatedDate
                FROM SM_Payment_Method__c
                WHERE Name = :paymentMethodName
                  AND SM_Account__c = :contrato.AccountId
                  AND SM_Active__c = TRUE
                LIMIT 1
            ];
            
            if (pms.isEmpty()) {
                throw new ValidacionException('Payment Method no válido/inactivo o no pertenece a la cuenta');
            }
            
            SM_Payment_Method__c pm = pms[0];
            
            // 3️⃣ Validar últimas 4 dígitos
            String last4FromPM = pm.SM_Credit_Card_Number__c != null ? 
                                 pm.SM_Credit_Card_Number__c.right(4) : '';
            
            if (!last4FromPM.equals(ultimasCuatro)) {
                throw new ValidacionException('Las últimas 4 dígitos no coinciden. PM: ' + 
                                            last4FromPM + ' vs Reportado: ' + ultimasCuatro);
            }
            
            // 4️⃣ Validación de token duplicado
            String tokenOriginal = pm.SM_Card_Token__c;
            String tokenFinal = tokenOriginal;
            
            List<SM_Payment_Method__c> todosLosPM = [
                SELECT Id, Name, SM_Card_Token__c, SM_Credit_Card_Number__c,
                       SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c,
                       SM_Active__c, CreatedDate
                FROM SM_Payment_Method__c
                WHERE SM_Account__c = :contrato.AccountId
                ORDER BY CreatedDate ASC
            ];
            
            // Verificar si hay duplicados
            Boolean hayDuplicado = false;
            for (SM_Payment_Method__c otro : todosLosPM) {
                if (otro.Id != pm.Id && otro.SM_Card_Token__c == tokenOriginal) {
                    hayDuplicado = true;
                    break;
                }
            }
            
            // Si hay duplicado, buscar en historial
            if (hayDuplicado) {
                List<SM_Payment_Method__History> hist = [
                    SELECT OldValue, NewValue, CreatedDate
                    FROM SM_Payment_Method__History
                    WHERE ParentId = :pm.Id
                      AND Field = 'SM_Card_Token__c'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                
                if (!hist.isEmpty() && hist[0].OldValue != null) {
                    tokenFinal = String.valueOf(hist[0].OldValue);
                    resultado.message = '⚠️ Token duplicado. Usando OldValue del historial. ';
                } else {
                    tokenFinal = '';
                    resultado.message = '⚠️ Token duplicado y sin histórico. Token dejado en blanco. ';
                }
            }
            
            // 5️⃣ Obtener Orders TC activos
            List<ChargentOrders__ChargentOrder__c> tcOrders = [
                SELECT Id, ChargentOrders__Billing_Country__c, ChargentOrders__Tokenization__c,
                       ChargentOrders__Card_Last_4__c, ChargentOrders__Card_Expiration_Month__c,
                       ChargentOrders__Card_Expiration_Year__c, ChargentOrders__Card_Number__c,
                       ChargentOrders__Card_Month_Indicator__c, ChargentOrders__Card_Year_Indicator__c
                FROM ChargentOrders__ChargentOrder__c
                WHERE Contract__c = :contrato.Id
                  AND (ChargentOrders__Payment_Status__c = 'Recurring' 
                       OR ChargentOrders__Payment_Status__c = 'Stopped')
            ];
            
            // 6️⃣ Actualizar Contrato
            contrato.SM_Payment_Method__c = pm.Id;
            contrato.SM_Registered_Card_Token__c = tokenFinal;
            
            // 7️⃣ Actualizar Orders TC
            String billingCountry = contrato.SM_Billing_Address__r.State == 'Puerto Rico' ? 
                                   'PR' : contrato.SM_Billing_Address__r.Country;
            
            for (ChargentOrders__ChargentOrder__c orden : tcOrders) {
                orden.ChargentOrders__Billing_Country__c = billingCountry;
                orden.ChargentOrders__Tokenization__c = tokenFinal;
                orden.ChargentOrders__Card_Last_4__c = last4FromPM;
                orden.ChargentOrders__Card_Expiration_Month__c = pm.SM_Credit_Card_expiration_month__c;
                orden.ChargentOrders__Card_Expiration_Year__c = pm.SM_Credit_Card_expiration_year__c;
                orden.ChargentOrders__Card_Number__c = last4FromPM;
                orden.ChargentOrders__Card_Month_Indicator__c = pm.SM_Credit_Card_expiration_month__c;
                orden.ChargentOrders__Card_Year_Indicator__c = pm.SM_Credit_Card_expiration_year__c;
            }
            
            // 8️⃣ Guardar cambios
            if (!tcOrders.isEmpty()) {
                update tcOrders;
            }
            update contrato;
            
            // 9️⃣ Limpieza de duplicados
            Integer eliminados = limpiarPMDuplicados(todosLosPM, pm, tokenOriginal, last4FromPM, contrato.AccountId);
            
            // Resultado final
            resultado.success = true;
            resultado.message += '✅ Contrato y ' + tcOrders.size() + ' Orders TC actualizados. ' +
                               (eliminados > 0 ? eliminados + ' PMs duplicados eliminados.' : '');
            resultado.tokenParcial = enmascararToken(tokenFinal);
            resultado.paymentMethodId = pm.Id;
            
        } catch (Exception e) {
            resultado.success = false;
            resultado.message = 'Error en la validación';
            resultado.errores = e.getMessage() + '\n' + e.getStackTraceString();
        }
        
        return resultado;
    }
    
    /**
     * @description Limpia Payment Methods duplicados que no están en uso
     */
    private static Integer limpiarPMDuplicados(
        List<SM_Payment_Method__c> todosLosPM,
        SM_Payment_Method__c pmOriginal,
        String tokenOriginal,
        String last4,
        Id accountId
    ) {
        Set<Id> pmIds = new Set<Id>();
        for (SM_Payment_Method__c pm : todosLosPM) {
            pmIds.add(pm.Id);
        }
        
        // PMs en uso por Contratos
        Set<Id> pmEnUso = new Set<Id>();
        for (Contract con : [SELECT SM_Payment_Method__c FROM Contract WHERE SM_Payment_Method__c IN :pmIds]) {
            pmEnUso.add(con.SM_Payment_Method__c);
        }
        
        // PMs en uso por Orders TC
        for (ChargentOrders__ChargentOrder__c ord : [
            SELECT ChargentOrders__Payment_Method__c 
            FROM ChargentOrders__ChargentOrder__c 
            WHERE ChargentOrders__Payment_Method__c IN :pmIds
        ]) {
            pmEnUso.add(ord.ChargentOrders__Payment_Method__c);
        }
        
        // Buscar duplicados para eliminar
        List<SM_Payment_Method__c> aBorrar = new List<SM_Payment_Method__c>();
        for (SM_Payment_Method__c pm : todosLosPM) {
            if (pm.Id != pmOriginal.Id &&
                pm.SM_Card_Token__c == tokenOriginal &&
                pm.SM_Credit_Card_Number__c.right(4) == last4 &&
                pm.SM_Credit_Card_expiration_month__c == pmOriginal.SM_Credit_Card_expiration_month__c &&
                pm.SM_Credit_Card_expiration_year__c == pmOriginal.SM_Credit_Card_expiration_year__c &&
                !pmEnUso.contains(pm.Id)) {
                aBorrar.add(pm);
            }
        }
        
        if (!aBorrar.isEmpty()) {
            delete aBorrar;
            return aBorrar.size();
        }
        
        return 0;
    }
    
    /**
     * @description Enmascara token para mostrar solo primeros y últimos caracteres
     */
    private static String enmascararToken(String token) {
        if (String.isBlank(token) || token.length() < 8) {
            return '****';
        }
        
        String inicio = token.substring(0, 4);
        String fin = token.substring(token.length() - 4);
        
        return inicio + '...' + fin;
    }
    
    /**
     * Clase interna para resultado de validación
     */
    private class ResultadoValidacion {
        public Boolean success = false;
        public String message = '';
        public String tokenParcial = '';
        public String errores = '';
        public String paymentMethodId = '';
    }
    
    /**
     * Exception personalizada
     */
    public class ValidacionException extends Exception {}
}