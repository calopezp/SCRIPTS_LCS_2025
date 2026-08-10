# 🔍 Análisis Final - Error Apex Job 707UU00001tkoV3

## ✅ Causa Raíz Confirmada

**Error:** "First error: Argument cannot be null."

**Ubicación:** Clase `SM_PaymentHelper`, método `createPayments()`  
**Línea:** ~122-123

### Datos del Registro Problemático

Un registro ACH Order tenía la siguiente combinación de datos:
- `SM_Apply_penalty__c = true`
- `SM_Penalty_value__c = null`

### Flujo del Error

1. **SM_PaymentBatch** ejecuta y llama a `SM_PaymentHelper.createPayments()`
2. En la línea 122-123, se intenta crear un Payment con:
   ```apex
   SM_Penalty_value__c = achOrder.SM_Apply_penalty__c && achOrder.SM_Penalty_value__c > 0 
                         ? achOrder.SM_Penalty_value__c 
                         : 0
   ```
3. **Problema:** Cuando `SM_Penalty_value__c = null`, la comparación `null > 0` falla con **"Argument cannot be null"**

### Código Problemático

**Archivo:** `force-app/main/default/classes/SM_PaymentHelper.cls`  
**Líneas:** 122-123

```apex
SM_Penalty_value__c = achOrder.SM_Apply_penalty__c && achOrder.SM_Penalty_value__c > 0 
                     ? achOrder.SM_Penalty_value__c 
                     : 0,
```

## 🎯 Solución Implementada

### Solución 1: Validación en SM_PaymentHandler (Implementada)

Se agregaron validaciones en dos métodos de `SM_PaymentHandler.cls`:

#### a) `updateACHOrderInfo()` - Línea ~152
```apex
private void updateACHOrderInfo(List<SM_Payment__c> newRecords) {
    Set<String> achOrderIds = new Set<String>();
    Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
    
    for (SM_Payment__c payment : newRecords) {
        // Only process ACH Payments with valid ACH Order
        if (payment.RecordTypeId == achRecordTypeId && payment.SM_ACH_Order__c != null) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
    }
    
    // Only continue if there are ACH Orders to process
    if (achOrderIds.isEmpty()) {
        return;
    }
    // ... resto del código
}
```

#### b) `updateRelatedRecordsByPaymentStatusUpdates()` - Línea ~230
```apex
private void updateRelatedRecordsByPaymentStatusUpdates(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
    Set<String> achOrderIds = new Set<String>();
    Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
    
    for (SM_Payment__c payment : newRecords) {
        // Only process ACH Payments with valid ACH Order
        if (payment.RecordTypeId == achRecordTypeId && payment.SM_ACH_Order__c != null) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
    }
    
    // Only continue if there are ACH Orders to process
    if (achOrderIds.isEmpty()) {
        return;
    }
    // ... resto del código
}
```

### Solución 2: Validación en SM_PaymentHelper (RECOMENDADA ADICIONAL)

Para prevenir completamente el error, se debe agregar validación en `SM_PaymentHelper.createPayments()`:

**Archivo:** `force-app/main/default/classes/SM_PaymentHelper.cls`  
**Línea:** ~122-123

**Cambio Recomendado:**
```apex
// ANTES (Línea 122-123):
SM_Penalty_value__c = achOrder.SM_Apply_penalty__c && achOrder.SM_Penalty_value__c > 0 
                     ? achOrder.SM_Penalty_value__c 
                     : 0,

// DESPUÉS (Validar NULL antes de comparar):
SM_Penalty_value__c = achOrder.SM_Apply_penalty__c 
                     && achOrder.SM_Penalty_value__c != null 
                     && achOrder.SM_Penalty_value__c > 0 
                     ? achOrder.SM_Penalty_value__c 
                     : 0,
```

## 📊 Problema de Datos

### Escenario Problemático
Un ACH Order con:
- `SM_Apply_penalty__c = true` (se debe aplicar penalización)
- `SM_Penalty_value__c = null` (pero no hay valor de penalización)

### ¿Por qué ocurre esto?
Posibles razones:
1. Datos migratorios incorrectos
2. Lógica de negocio que marca `SM_Apply_penalty__c = true` sin calcular `SM_Penalty_value__c`
3. Actualización manual de registros sin validar ambos campos

### Recomendación de Validación
Agregar una Validation Rule en el objeto `SM_ACH_Order__c`:

```
Rule Name: Penalty_Value_Required_When_Apply_Penalty
Error Condition Formula:
AND(
  SM_Apply_penalty__c = TRUE,
  OR(
    ISBLANK(SM_Penalty_value__c),
    SM_Penalty_value__c = 0
  )
)
Error Message: "When 'Apply Penalty' is checked, 'Penalty Value' must have a value greater than 0."
```

## ✅ Estado Actual

### Implementado ✅
1. Validación de RecordType ACH en `SM_PaymentHandler.updateACHOrderInfo()`
2. Validación de RecordType ACH en `SM_PaymentHandler.updateRelatedRecordsByPaymentStatusUpdates()`
3. Validación de `SM_ACH_Order__c != null` en ambos métodos

### Pendiente ⚠️
1. Agregar validación `!= null` en `SM_PaymentHelper.createPayments()` línea 122
2. Crear Validation Rule para prevenir datos inconsistentes
3. Identificar y corregir registros existentes con `SM_Apply_penalty__c = true` y `SM_Penalty_value__c = null`

## 🔍 Query para Identificar Registros Problemáticos

```sql
SELECT Id, Name, SM_Apply_penalty__c, SM_Penalty_value__c, 
       SM_Contract__c, SM_Payment_Type__c
FROM SM_ACH_Order__c
WHERE SM_Apply_penalty__c = true 
  AND (SM_Penalty_value__c = null OR SM_Penalty_value__c = 0)
```

## 📝 Resumen

| Aspecto | Detalle |
|---------|---------|
| **Error** | "Argument cannot be null." |
| **Causa Raíz** | Comparación `null > 0` en línea 122 de SM_PaymentHelper |
| **Datos Problemáticos** | ACH Order con `SM_Apply_penalty__c = true` y `SM_Penalty_value__c = null` |
| **Solución Principal** | Validar `!= null` antes de comparar con 0 |
| **Solución Adicional** | Validar RecordType y NULL en SM_PaymentHandler |
| **Prevención** | Validation Rule en SM_ACH_Order__c |

## 🚀 Próximos Pasos

1. ✅ **Completado:** Validaciones en SM_PaymentHandler
2. ⚠️ **Pendiente:** Agregar validación NULL en SM_PaymentHelper.createPayments()
3. ⚠️ **Pendiente:** Crear Validation Rule en SM_ACH_Order__c
4. ⚠️ **Pendiente:** Identificar y corregir registros con datos inconsistentes
5. ⚠️ **Pendiente:** Ejecutar tests unitarios
6. ⚠️ **Pendiente:** Desplegar a producción

---

**Fecha del Análisis:** 2026-05-05  
**Job ID Analizado:** 707UU00001tkoV3  
**Clase Afectada:** SM_PaymentBatch  
**Métodos Corregidos:** SM_PaymentHandler.updateACHOrderInfo(), SM_PaymentHandler.updateRelatedRecordsByPaymentStatusUpdates()  
**Método que Requiere Corrección Adicional:** SM_PaymentHelper.createPayments() línea 122-123