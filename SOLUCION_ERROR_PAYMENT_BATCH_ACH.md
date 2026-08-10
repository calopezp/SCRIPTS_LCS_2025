# 🔧 Solución Error "Argument Can't be null" en SM_PaymentBatch

## ✅ Causa Raíz Confirmada

**El batch SM_PaymentBatch falla porque el método `updateACHOrderInfo()` procesa Payments SIN validar:**
1. Si el Payment es de tipo **ACH** (RecordType)
2. Si el campo `SM_ACH_Order__c` es **NULL**

---

## 🎯 Código Problemático

**Archivo:** `force-app/main/default/classes/SM_PaymentHandler.cls`  
**Método:** `updateACHOrderInfo()` - Línea ~152-157

```apex
private void updateACHOrderInfo(List<SM_Payment__c> newRecords) {
    Set<String> achOrderIds = new Set<String>();
    for (SM_Payment__c payment : newRecords) {
        achOrderIds.add(payment.SM_ACH_Order__c);  // ⚠️ PROBLEMA
    }
    Map<String, SM_ACH_Order__c> achOrders = SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds);
    // ...
}
```

### Problemas:
1. ❌ No valida si el Payment es tipo **ACH**
2. ❌ No valida si `SM_ACH_Order__c` es **NULL**
3. ❌ Agrega NULL al Set
4. ❌ La query falla: `WHERE Id IN :achOrderIds` cuando contiene NULL

---

## ✅ Solución Correcta (Solo ACH)

```apex
private void updateACHOrderInfo(List<SM_Payment__c> newRecords) {
    Set<String> achOrderIds = new Set<String>();
    Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
    
    for (SM_Payment__c payment : newRecords) {
        // ✅ SOLO procesar Payments ACH con ACH Order válido
        if (payment.RecordTypeId == achRecordTypeId && payment.SM_ACH_Order__c != null) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
    }
    
    // ✅ Solo consultar si hay ACH Orders válidos
    if (achOrderIds.isEmpty()) {
        return;  // No hay nada que procesar
    }
    
    Map<String, SM_ACH_Order__c> achOrders = SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds);
    System.debug('achOrders: ' + JSON.serialize(achOrders));
    
    for (SM_ACH_Order__c achOrder : achOrders.values()) {
        // SFDCMP-299 - JSPA
        if(achOrder.SM_Payment_Condition__c != SM_ACHOrderHelper.paymentCondition.FIXED_VALUE 
           && (System.today() < achOrder.SM_Payment_End_Date__c || achOrder.SM_Payment_End_Date__c == null)){
            achOrder.SM_Fee_to_collect__c++;
        }
        
        Integer qtyOfPayments = achOrder.Payments__r.size();
        
        if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.ONCE) {
            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
            achOrder.SM_Next_Transaction_Date__c = null;
        } else if (achOrder.SM_Payment_Frequency__c == SM_ACHOrderHelper.paymentFrequency.MONTHLY) {
            achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.INITIATED;
            if (achOrder.SM_Quantity_of_scheduled_fees__c > qtyOfPayments) {
                achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
            } else if (achOrder.SM_Quantity_of_scheduled_fees__c == qtyOfPayments) {
                achOrder.SM_Payment_Status__c = SM_ACHOrderHelper.paymentStatus.COMPLETED;
                achOrder.SM_Next_Transaction_Date__c = null;
            } else if (achOrder.SM_Payment_Type__c == SM_ACHOrderHelper.paymentType.SUBSCRIPTION) {
                achOrder.SM_Next_Transaction_Date__c = achOrder.SM_Next_Transaction_Date__c.addMonths(1);
            }
        }
    }
    
    List<Database.SaveResult> sr = Database.update(achOrders.values());
    System.debug('sr: ' + sr);
}
```

---

## 📊 Impacto de los Payments Encontrados

### Payments con `SM_ACH_Order__c = NULL`:

De los 10 Payments encontrados:
- **4 tienen Transaction** (son de Chargent/Credit Card) → **No deben procesarse en updateACHOrderInfo()**
- **6 NO tienen Transaction ni ACH Order** → **Revisar por qué se crearon así**

| Payment | Type | RecordType | ACH Order | Transaction | ¿Debería procesarse? |
|---------|------|------------|-----------|-------------|---------------------|
| PY-01828868 | AC | ? | NULL | NULL | Solo si es ACH |
| PY-01828867 | Fee | ? | NULL | NULL | Solo si es ACH |
| PY-01828866 | Fee | ? | NULL | **a1LUU00000G2Kj52AF** | ❌ NO (Credit Card) |
| PY-01828865 | Fee | ? | NULL | **a1LUU00000G2RcP2AV** | ❌ NO (Credit Card) |
| PY-01828864 | Fee | ? | NULL | NULL | Solo si es ACH |
| PY-01828863 | AC | ? | NULL | NULL | Solo si es ACH |
| PY-01828861 | Fee | ? | NULL | NULL | Solo si es ACH |
| PY-01828860 | LPF | ? | NULL | NULL | Solo si es ACH |
| PY-01828859 | LPF | ? | NULL | NULL | Solo si es ACH |
| PY-01828858 | Fee | ? | NULL | NULL | Solo si es ACH |

---

## 🔍 Validación Adicional Necesaria

Además del método `updateACHOrderInfo()`, revisar:

### **1. updateRelatedRecordsByPaymentStatusUpdates() - Línea ~230**

```apex
private void updateRelatedRecordsByPaymentStatusUpdates(List<SM_Payment__c> newRecords, Map<Id, SObject> oldRecordsMap) {
    Set<String> achOrderIds = new Set<String>();
    Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');
    
    for (SM_Payment__c payment : newRecords) {
        // ✅ VALIDAR RecordType y NULL
        if (payment.RecordTypeId == achRecordTypeId && payment.SM_ACH_Order__c != null) {
            achOrderIds.add(payment.SM_ACH_Order__c);
        }
    }
    
    if (achOrderIds.isEmpty()) {
        return;
    }
    
    Map<String, SM_ACH_Order__c> achOrdersById = SM_ACHOrderHelper.getACHOrdersByIds(achOrderIds);
    // ... resto del código
}
```

### **2. processRejectedPayments() - Línea ~285**

Este método YA valida el RecordType correctamente:

```apex
if (SM_Utils.isChangedField(newRecord, oldRecord, 'Payment_Status__c') 
    && newRecord.Payment_Status__c == SM_PaymentHelper.status.REJECTED
    && SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c','ACH') == newRecord.recordTypeId) {
    // ✅ Ya valida que sea ACH
    paymentsToProcess.add(newRecord.Id);
}
```

---

## 📝 Resumen de Cambios

### Archivos a Modificar:
- ✅ `force-app/main/default/classes/SM_PaymentHandler.cls`

### Métodos a Corregir:
1. ✅ `updateACHOrderInfo()` - Línea 152
2. ✅ `updateRelatedRecordsByPaymentStatusUpdates()` - Línea 230

### Validaciones a Agregar:
```apex
Id achRecordTypeId = SM_utils.getRecordTypeIdByDeveloperName('SM_Payment__c', 'ACH');

// En cada método que procese ACH Orders:
if (payment.RecordTypeId == achRecordTypeId && payment.SM_ACH_Order__c != null) {
    achOrderIds.add(payment.SM_ACH_Order__c);
}

if (achOrderIds.isEmpty()) {
    return;  // No procesar si no hay ACH Orders válidos
}
```

---

## ✅ Resultado Esperado

Después de aplicar estos cambios:

1. ✅ El batch **SM_PaymentBatch** ejecutará sin errores
2. ✅ Solo procesará Payments tipo **ACH** con ACH Order válido
3. ✅ Ignorará Payments de **Credit Card** (Chargent)
4. ✅ No intentará consultar con NULL en la query

---

## 🚀 Pasos Siguientes

1. Modificar `SM_PaymentHandler.cls` con las validaciones
2. Ejecutar tests: `SM_PaymentHandlerTest`
3. Desplegar a producción
4. Monitorear próxima ejecución del batch
5. Investigar por qué se crean Payments ACH sin ACH Order