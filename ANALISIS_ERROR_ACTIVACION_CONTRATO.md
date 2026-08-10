# 🔍 Análisis del Error de Activación de Contrato

## Contrato ID: 800UU00000XeCYwYAN

---

## 📌 Resumen del Problema

**Error recibido:**
```
"Please Meake Sure That you filled the AC/Subscription information and that you've filled al the ach fields in the payment method."
```

---

## 🔎 Ubicación del Error

**Archivo:** `SM_ACHPaymentProcessHandler.cls`  
**Método:** `validateMandatoryFields()`  
**Línea:** ~166

---

## 🔄 Flujo de Validación

### 1. Trigger de Contrato
Cuando se intenta activar un contrato, se dispara el trigger `SM_ContractTrigger` que llama al handler.

### 2. Creación de ACH Orders
El sistema intenta crear registros de `SM_ACH_Order__c` mediante:
- `CreateACOrderRecordsACH()` - Para pagos AC (Administration Cost)
- `CreateSubscriptionOrderRecordsACH()` - Para pagos recurrentes/Subscription

### 3. Validación de Campos Requeridos
**Método:** `SM_Utils.getRequiredFieldsByProcess()`

Este método consulta el objeto custom: **`SM_Required_Field_Info__c`**

**Query ejecutado:**
```sql
SELECT SM_Api_Field_Name__c, SM_Company_Setting__c
FROM SM_Required_Field_Info__c
WHERE SM_Source_Object__c = 'Contract'
  AND SM_Company_Setting__c IN :companySettingIds
  AND SM_Process__c IN ('AC', 'Subscription')
```

### 4. Validación Campo por Campo
**Método:** `validateMandatoryFields()`

```apex
for(String required: requiredFields.get(crCSetting)){
    if(obj.get(required) == null){  // ⚠️ AQUÍ FALLA
        resp.put(crKey,false);
        break;
    }
}
```

Si **CUALQUIER** campo requerido está **NULL**, se marca como fallido.

### 5. Error se Dispara
```apex
if(!resp.containsKey(crKey)){
    resp.put(crKey,true);
}
else{
    // ⚠️ AQUÍ SE LANZA EL ERROR
    Trigger.new[0].adderror(new ObjectException('Please Meake Sure...'));
}
```

---

## 🎯 Causa Raíz Identificada

El error **NO es genérico**. Se dispara cuando:

1. ✅ Los campos requeridos están configurados en `SM_Required_Field_Info__c`
2. ❌ Al menos **UN campo** de esa configuración está **NULL/vacío** en el contrato
3. ⚠️ **IMPORTANTE:** La validación ocurre en el contexto del trigger, por lo que `Trigger.new[0]` se refiere al **primer registro** en el trigger, no necesariamente al contrato que estás validando

---

## 🔧 Posibles Causas del Error

### Opción A: Campo del Contrato Vacío
Alguno de estos campos podría estar vacío:
- `SM_Payment_Method__c` (lookup al método de pago)
- `SM_Email_to_send_contract__c`
- `SM_AC_start_date__c` (si requiere AC)
- `SM_Total_AC__c` (si requiere AC)
- `SM_Way_of_AC_Payment__c` (si requiere AC)
- `SM_Start_date__c` (si requiere Subscription)
- `SM_Monthly_offer__c` (si requiere Subscription)
- `SM_Frecuency__c` (si requiere Subscription)

### Opción B: Campos del Payment Method Vacíos
Si el Payment Method es tipo ACH, estos campos deben estar llenos:
- `SM_ACH_Account_Holder_Name__c`
- `SM_ACH_Account_Number__c`
- `SM_ACH_Routing_Number__c`
- `SM_ACH_Account_Type__c`

### Opción C: ACH Orders Ya Existen
El código verifica:
```apex
if(!response.get(ctr.Id) || ctr.ACH_Orders__r.size()>0){
    continue; // No crea órdenes si ya existen
}
```

Si ya existen ACH Orders y algún campo requerido está vacío, el error se dispara igual.

---

## 📋 Pasos para Diagnosticar

### 1. Ejecutar Query Manual en Salesforce
Abre Developer Console o Workbench y ejecuta:

```sql
SELECT Id, ContractNumber, Status,
       SM_Company_Setting__c,
       SM_Payment_Method__c,
       SM_Requires_AC_Payment__c,
       SM_Way_of_AC_Payment__c,
       SM_Total_AC__c,
       SM_AC_start_date__c,
       SM_AC_Split_Date__c,
       SM_Requires_RC_Payment__c,
       SM_Way_of_Contract_Payment__c,
       SM_Frecuency__c,
       SM_Monthly_offer__c,
       SM_Start_date__c,
       SM_Plan_Months__c,
       SM_Email_to_send_contract__c,
       (SELECT Id, SM_Payment_Type__c FROM ACH_Orders__r)
FROM Contract
WHERE Id = '800UU00000XeCYwYAN'
```

### 2. Verificar Configuración de Campos Requeridos

```sql
SELECT Id, Name, 
       SM_Api_Field_Name__c, 
       SM_Process__c,
       SM_Company_Setting__r.Name
FROM SM_Required_Field_Info__c
WHERE SM_Source_Object__c = 'Contract'
  AND SM_Company_Setting__c = [Company_Setting_ID_del_Contrato]
  AND SM_Process__c IN ('AC', 'Subscription')
ORDER BY SM_Process__c, SM_Api_Field_Name__c
```

### 3. Verificar Payment Method

```sql
SELECT Id, Name, RecordType.DeveloperName,
       SM_ACH_Account_Holder_Name__c,
       SM_ACH_Account_Number__c,
       SM_ACH_Routing_Number__c,
       SM_ACH_Account_Type__c,
       SM_Bank_Name__c
FROM SM_Payment_Method__c
WHERE Id = [Payment_Method_ID_del_Contrato]
```

---

## 🚨 BUG Identificado en el Código

### Problema de Lógica en `validateMandatoryFields()`

```apex
if(!resp.containsKey(crKey)){
    resp.put(crKey,true);
}
else{
    Trigger.new[0].adderror(...); // ⚠️ PROBLEMA AQUÍ
}
```

**Este código tiene un problema:**
1. Si **TODOS los campos están OK**, `resp.containsKey(crKey)` es **FALSE**, entonces se agrega como `true`
2. Si **ALGÚN campo está vacío**, `resp.containsKey(crKey)` es **TRUE** (ya se agregó como false), entonces lanza el error

**PERO:** El error se agrega a `Trigger.new[0]`, que es el **primer registro del trigger**, no necesariamente el contrato actual siendo validado en el loop.

---

## ✅ Solución Recomendada

### Solución Inmediata: Llenar el Campo Faltante
1. Ejecutar las queries de diagnóstico arriba
2. Identificar qué campo específico está NULL
3. Llenar ese campo en el contrato
4. Intentar activar nuevamente

### Solución a Largo Plazo: Mejorar el Mensaje de Error
El código debería indicar **QUÉ campo específico está vacío**:

```apex
// Mejorar el mensaje de error
List<String> missingFields = new List<String>();
for(String required: requiredFields.get(crCSetting)){
    if(obj.get(required) == null){
        missingFields.add(required);
    }
}
if(!missingFields.isEmpty()){
    String errorMsg = 'Los siguientes campos requeridos están vacíos: ' + 
                      String.join(missingFields, ', ');
    obj.adderror(errorMsg); // Usar obj, no Trigger.new[0]
}
```

---

## 📞 Siguiente Paso

**Por favor proporciona:**
1. El `SM_Company_Setting__c` ID del contrato
2. O ejecuta las queries manualmente en Developer Console y comparte los resultados

Esto nos permitirá identificar exactamente qué campo está causando el problema.