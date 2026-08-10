/**
 * @description: Procesamiento para validar y aplicar nueva Tarjeta de Crédito (TC)
 *               desde el objeto Contract usando LWC Screen Action.
 * @author: Carlos Alberto Lopez Prada
 * @date: May 2026
 */
public with sharing class SM_TC_ValidationProcessor {

    @AuraEnabled
    public static String procesarNuevaTC(Id contractId, String paymentMethodName, String lastFourCard) {
        try {
            // Validación inicial de parámetros
            if (String.isBlank(paymentMethodName) || String.isBlank(lastFourCard)) {
                throw new AuraHandledException('Debes ingresar Payment Method Name y las últimas 4 dígitos de la tarjeta.');
            }

            // 1️⃣ Obtener Contrato activo usando el recordId del botón
            Contract c = [
                SELECT Id, AccountId, Status, ContractNumber,
                       SM_Billing_Address__r.State, SM_Billing_Address__r.Country
                FROM Contract
                WHERE Id = :contractId
                  AND Status NOT IN ('Canceled', 'Finalized')
                LIMIT 1
            ];

            // 2️⃣ Obtener Payment Method válido
            SM_Payment_Method__c pm = [
                SELECT Id, Name, SM_Active__c, SM_Account__c,
                       SM_Card_Token__c, SM_Credit_Card_Number__c,
                       SM_Credit_Card_expiration_month__c,
                       SM_Credit_Card_expiration_year__c,
                       CreatedDate
                FROM SM_Payment_Method__c
                WHERE Name = :paymentMethodName
                  AND SM_Account__c = :c.AccountId
                  AND SM_Active__c = TRUE
                LIMIT 1
            ];

            String tokenOriginal = pm.SM_Card_Token__c;

            // 2️⃣-B VALIDACIÓN DE TOKEN DUPLICADO
            List<SM_Payment_Method__c> allPMFinal = [
                SELECT Id, Name, SM_Card_Token__c, SM_Credit_Card_Number__c,
                       SM_Credit_Card_expiration_month__c, SM_Credit_Card_expiration_year__c,
                       SM_Active__c, CreatedDate
                FROM SM_Payment_Method__c
                WHERE SM_Account__c = :c.AccountId
                ORDER BY CreatedDate ASC
            ];

            Boolean hayDuplicado = false;
            for (SM_Payment_Method__c otro : allPMFinal) {
                if (otro.Id != pm.Id && otro.SM_Card_Token__c == tokenOriginal) {
                    hayDuplicado = true;
                    break;
                }
            }

            String tokenReal = tokenOriginal;
            if (hayDuplicado) {
                List<SM_Payment_Method__History> hist = [
                    SELECT OldValue
                    FROM SM_Payment_Method__History
                    WHERE ParentId = :pm.Id
                      AND Field = 'SM_Card_Token__c'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];

                if (!hist.isEmpty() && hist[0].OldValue != null) {
                    tokenReal = String.valueOf(hist[0].OldValue);
                    System.debug('→⚠️ Token duplicado detectado. Usando OldValue del historial: ' + tokenReal);
                } else {
                    tokenReal = '';
                    System.debug('→⚠️ Token duplicado sin historial previo. Se usará valor vacío.');
                }
            }

            // 3️⃣ Validar últimas 4 dígitos
            String last4FromPM = pm.SM_Credit_Card_Number__c.right(4);
            if (!last4FromPM.equals(lastFourCard)) {
                throw new AuraHandledException('Las últimas 4 dígitos no coinciden. PM: ' + last4FromPM + ' vs Ingresado: ' + lastFourCard);
            }

            // 4️⃣ Obtener Orders TC activos (Recurring o Stopped)
            List<ChargentOrders__ChargentOrder__c> tcOrds = [
                SELECT Id, ChargentOrders__Billing_Country__c, ChargentOrders__Tokenization__c,
                       ChargentOrders__Card_Last_4__c, ChargentOrders__Card_Expiration_Month__c,
                       ChargentOrders__Card_Expiration_Year__c, ChargentOrders__Card_Number__c,
                       ChargentOrders__Card_Month_Indicator__c, ChargentOrders__Card_Year_Indicator__c
                FROM ChargentOrders__ChargentOrder__c
                WHERE Contract__c = :c.Id
                  AND (ChargentOrders__Payment_Status__c = 'Recurring'
                       OR ChargentOrders__Payment_Status__c = 'Stopped')
            ];

            if (tcOrds.isEmpty()) {
                return '✅ No se encontraron Orders TC activos (Recurring/Stopped) para actualizar en este contrato.';
            }

            // 5️⃣ Actualizar Contrato y Orders TC
            c.SM_Payment_Method__c = pm.Id;
            c.SM_Registered_Card_Token__c = tokenReal;   // Usamos tokenReal (puede ser vacío)

            for (ChargentOrders__ChargentOrder__c o : tcOrds) {
                o.ChargentOrders__Billing_Country__c      = (c.SM_Billing_Address__r.State == 'Puerto Rico') ? 'PR' : c.SM_Billing_Address__r.Country;
                o.ChargentOrders__Tokenization__c         = tokenReal;
                o.ChargentOrders__Card_Last_4__c          = pm.SM_Credit_Card_Number__c.right(4);
                o.ChargentOrders__Card_Expiration_Month__c = pm.SM_Credit_Card_expiration_month__c;
                o.ChargentOrders__Card_Expiration_Year__c  = pm.SM_Credit_Card_expiration_year__c;
                o.ChargentOrders__Card_Number__c          = pm.SM_Credit_Card_Number__c.right(4);
                o.ChargentOrders__Card_Month_Indicator__c = pm.SM_Credit_Card_expiration_month__c;
                o.ChargentOrders__Card_Year_Indicator__c  = pm.SM_Credit_Card_expiration_year__c;
            }

            // 6️⃣ Guardar cambios (una sola transacción)
            update tcOrds;
            update c;

            // 7️⃣ Limpieza de duplicados
            Set<Id> pmIdsAccount = new Set<Id>();
            for (SM_Payment_Method__c p : allPMFinal) {
                pmIdsAccount.add(p.Id);
            }

            Set<Id> pmEnUso = new Set<Id>();
            for (Contract con : [SELECT SM_Payment_Method__c FROM Contract WHERE SM_Payment_Method__c IN :pmIdsAccount]) {
                if (con.SM_Payment_Method__c != null) pmEnUso.add(con.SM_Payment_Method__c);
            }
            for (ChargentOrders__ChargentOrder__c ord : [SELECT ChargentOrders__Payment_Method__c FROM ChargentOrders__ChargentOrder__c WHERE ChargentOrders__Payment_Method__c IN :pmIdsAccount]) {
                if (ord.ChargentOrders__Payment_Method__c != null) pmEnUso.add(ord.ChargentOrders__Payment_Method__c);
            }

            List<SM_Payment_Method__c> aBorrar = new List<SM_Payment_Method__c>();
            for (SM_Payment_Method__c pmLoop : allPMFinal) {
                if (pmLoop.Id != pm.Id &&
                    pmLoop.SM_Card_Token__c == tokenOriginal &&
                    pmLoop.SM_Credit_Card_Number__c.right(4) == last4FromPM &&
                    pmLoop.SM_Credit_Card_expiration_month__c == pm.SM_Credit_Card_expiration_month__c &&
                    pmLoop.SM_Credit_Card_expiration_year__c == pm.SM_Credit_Card_expiration_year__c &&
                    !pmEnUso.contains(pmLoop.Id)) {
                    aBorrar.add(pmLoop);
                }
            }

            if (!aBorrar.isEmpty()) {
                delete aBorrar;
                System.debug('→🧹 Se eliminaron ' + aBorrar.size() + ' Payment Methods duplicados no usados.');
            }

            // Mensaje final de éxito
            return '✅ PROCESO COMPLETADO CON ÉXITO\n\n' +
                   'Contrato: ' + c.ContractNumber + '\n' +
                   'Payment Method aplicado: ' + pm.Name + '\n' +
                   'Token final registrado: ' + (String.isBlank(tokenReal) ? '(vacío)' : tokenReal) + '\n' +
                   'Órdenes TC actualizadas: ' + tcOrds.size() + '\n' +
                   'Duplicados eliminados: ' + aBorrar.size();

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error grave en procesarNuevaTC: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
            throw new AuraHandledException('Error inesperado: ' + e.getMessage());
        }
    }
}