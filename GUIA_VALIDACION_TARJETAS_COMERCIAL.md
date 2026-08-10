# 🎯 GUÍA: VALIDACIÓN DE TARJETAS PARA USUARIOS COMERCIALES  (OPCION APEX)

## 📋 RESUMEN EJECUTIVO

Esta guía presenta **3 opciones arquitectónicas** para permitir que usuarios del área comercial validen y actualicen payment methods en Chargent Orders, manteniendo la seguridad de campos encriptados.

### ✅ REQUERIMIENTOS CUMPLIDOS
- ✅ Usuarios comerciales pueden ejecutar validaciones
- ✅ Actualización de Payment Methods y Chargent Orders
- ✅ Validación de tokens duplicados
- ✅ Limpieza de PMs duplicados no utilizados
- ✅ **SEGURIDAD**: Usuarios NO ven campos encriptados (*****)
- ✅ Usuarios solo ven datos completos al CREAR un PM

---

## 🏗️ OPCIÓN 1: SCREEN FLOW + INVOCABLE APEX ⭐ RECOMENDADA

### **Por qué es la mejor opción:**
1. ✅ **NO requiere desarrollo UI custom** (solo configuración)
2. ✅ **Fácil de mantener** - cambios por admins, no developers
3. ✅ **Seguridad robusta** - Apex `without sharing` accede a campos encriptados
4. ✅ **Auditoría automática** - Flow Interview Logs
5. ✅ **Mobile friendly** - funciona en Salesforce App
6. ✅ **Rápida implementación** - 2-3 días

### **Arquitectura:**

```
┌─────────────────────────────────────────────────────────┐
│  USUARIO COMERCIAL                                       │
│  1. Abre página del Contrato                            │
│  2. Click en botón "Validar Tarjeta" (Quick Action)     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│  SCREEN FLOW: "ValidarTarjetaCreditoFlow"                │
│                                                          │
│  🖥️ SCREEN 1: Inputs del Usuario                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │  🔒 Validar Tarjeta de Crédito                    │ │
│  │                                                    │ │
│  │  Número de Contrato: [00316772]                   │ │
│  │  Payment Method: [PM-204801]                      │ │
│  │  Últimas 4 dígitos: [7303]                        │ │
│  │                                                    │ │
│  │  [Cancelar]  [Validar] 🔄                         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ▼ Llama Invocable Apex (WITHOUT SHARING)               │
│  ┌────────────────────────────────────────────────────┐ │
│  │  SM_ValidarTarjetaInvocable.validarTarjeta()      │ │
│  │  - Obtiene Contrato y Payment Method              │ │
│  │  - Valida últimas 4 dígitos                       │ │
│  │  - Detecta tokens duplicados                      │ │
│  │  - Usa historial si hay duplicados                │ │
│  │  - Actualiza Contrato + Chargent Orders           │ │
│  │  - Limpia PMs duplicados no usados                │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  🖥️ SCREEN 2: Resultado                                 │
│  ┌────────────────────────────────────────────────────┐ │
│  │  ✅ Validación Exitosa                            │ │
│  │                                                    │ │
│  │  - Contrato actualizado                           │ │
│  │  - 3 Orders TC actualizados                       │ │
│  │  - 2 PMs duplicados eliminados                    │ │
│  │  - Token: tok_1234...5678                         │ │
│  │  - Payment Method: PM-204801                      │ │
│  │                                                    │ │
│  │  [Cerrar]                                          │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### **Componentes a crear:**

#### 1️⃣ **Apex Class** ✅ CREADO
- `SM_ValidarTarjetaInvocable.cls` - Invocable method con toda la lógica
- `SM_ValidarTarjetaInvocable.cls-meta.xml`

#### 2️⃣ **Screen Flow**
- Nombre: `ValidarTarjetaCreditoFlow`
- Tipo: Screen Flow
- API Name: `Validar_Tarjeta_Credito_Flow`

**Elementos del Flow:**

```yaml
Flow Elements:
  1. Screen "Inputs":
     - Text Input: numeroContrato (requerido)
     - Text Input: paymentMethodName (requerido)
     - Text Input: ultimasCuatro (requerido, 4 caracteres)
  
  2. Action "Validar":
     - Type: Apex Action
     - Apex Class: SM_ValidarTarjetaInvocable
     - Method: validarTarjeta
     - Inputs:
       - numeroContrato → {!numeroContrato}
       - paymentMethodName → {!paymentMethodName}
       - ultimasCuatro → {!ultimasCuatro}
     - Store Output: validacionResult
  
  3. Decision "¿Exitoso?":
     - Condition: {!validacionResult.success} = true
  
  4. Screen "Éxito":
     - Display Text: {!validacionResult.message}
     - Display Text: Token: {!validacionResult.tokenParcial}
     - Display Text: PM ID: {!validacionResult.paymentMethodId}
  
  5. Screen "Error":
     - Display Text: {!validacionResult.errores}
```

#### 3️⃣ **Quick Action** (en objeto Contract)
- Label: "Validar Tarjeta"
- Name: `Validar_Tarjeta`
- Type: Lightning Component
- Target: Flow
- Flow: `Validar_Tarjeta_Credito_Flow`
- Icon: `utility:record_create`

#### 4️⃣ **Permission Set** ✅ CREADO
- `SM_ValidadorTarjetas` - Asignar a usuarios comerciales

---

## 🏗️ OPCIÓN 2: LIGHTNING WEB COMPONENT + QUICK ACTION

### **Ventajas:**
- ✅ UX moderna y responsive
- ✅ Feedback en tiempo real con spinners
- ✅ Validación de inputs en el frontend
- ✅ Puede integrarse con otros componentes LWC

### **Desventajas:**
- ⚠️ Requiere desarrollo JavaScript
- ⚠️ Mayor tiempo de implementación (5-7 días)
- ⚠️ Requiere habilidades LWC

### **Arquitectura:**

```
┌─────────────────────────────────────────────┐
│  LWC: validarTarjetaCredito                  │
│  ┌───────────────────────────────────────┐  │
│  │  🔒 Validar Tarjeta de Crédito       │  │
│  │                                       │  │
│  │  Contrato: [00316772]                │  │
│  │  Payment Method: [PM-204801]         │  │
│  │  Últimas 4: [7303]                   │  │
│  │                                       │  │
│  │  ⚠️ Validará y actualizará datos     │  │
│  │                                       │  │
│  │  [Cancelar]  [Validar] 🔄            │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ▼ Llama @AuraEnabled Apex                 │
│  SM_ValidarTarjetaController.validar()     │
│  (usa SM_ValidarTarjetaInvocable)          │
└─────────────────────────────────────────────┘
```

### **Componentes a crear:**

1. **LWC Component** - `validarTarjetaCredito/`
2. **Apex Controller** - `SM_ValidarTarjetaController.cls` (@AuraEnabled)
3. **Quick Action** en Contract
4. **Permission Set**

---

## 🏗️ OPCIÓN 3: VISUALFORCE + CUSTOM BUTTON

### **Ventajas:**
- ✅ Implementación rápida (2 días)
- ✅ Familiar para admins Salesforce

### **Desventajas:**
- ⚠️ UI menos moderna
- ⚠️ No mobile-optimized
- ⚠️ Visualforce en deprecation path

### **NO RECOMENDADA** para nuevos desarrollos

---

## 📊 COMPARACIÓN DETALLADA

| Criterio                    | Screen Flow   | LWC           | Visualforce   |
|-----------------------------|---------------|---------------|---------------|
| **Tiempo implementación**   | 2-3 días      | 5-7 días      | 2 días        |
| **Complejidad técnica**     | Baja          | Media-Alta    | Media         |
| **Facilidad mantenimiento** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐▪️  | ⭐⭐⭐▪️▪️ |
| **UX moderna**              | ⭐⭐⭐⭐▪️ | ⭐⭐⭐⭐⭐  | ⭐⭐▪️▪️▪️ |
| **Mobile friendly**         | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐  | ⭐⭐▪️▪️▪️ |
| **Sin código custom UI**    | ⭐⭐⭐⭐⭐ | ⭐▪️▪️▪️▪️  | ⭐⭐▪️▪️▪️ |
| **Auditoria nativa**        | ⭐⭐⭐⭐⭐ | ⭐⭐⭐▪️▪️  | ⭐⭐⭐▪️▪️ |
| **Seguridad**               | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐  | ⭐⭐⭐⭐⭐ |
| **Escalabilidad**           | ⭐⭐⭐⭐▪️ | ⭐⭐⭐⭐⭐  | ⭐⭐⭐▪️▪️ |
| **Futuro-proof**            | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐  | ⭐⭐▪️▪️▪️ |

---

## 🔐 MODELO DE SEGURIDAD

### **Cómo funciona la seguridad:**

1. **Usuario Comercial** → Solo permisos básicos en objetos
2. **Permission Set** → Acceso a ejecutar el Flow/Apex pero SIN campos encriptados
3. **Apex `without sharing`** → Ejecuta con permisos del sistema
4. **Field-Level Security** → Usuario NUNCA ve campos encriptados en UI

### **Flujo de Permisos:**

```
┌───────────────────────────────────────────────────────┐
│  USUARIO COMERCIAL                                     │
│  - Profile: Sales User                                │
│  - Permission Set: SM_ValidadorTarjetas               │
│  - FLS: readable=false en campos encriptados          │
└──────────────┬────────────────────────────────────────┘
               │
               │ Ejecuta Flow
               │
               ▼
┌───────────────────────────────────────────────────────┐
│  SCREEN FLOW                                          │
│  - Ejecuta con permisos del usuario                   │
│  - Usuario NUNCA ve campos encriptados                │
└──────────────┬────────────────────────────────────────┘
               │
               │ Llama Invocable Method
               │
               ▼
┌───────────────────────────────────────────────────────┐
│  APEX: SM_ValidarTarjetaInvocable                     │
│  - Declarado como `without sharing`                   │
│  - Ejecuta con TODOS los permisos del sistema         │
│  - PUEDE leer/escribir campos encriptados             │
│  - Usuario NUNCA ve el contenido real                 │
└──────────────┬────────────────────────────────────────┘
               │
               │ Retorna datos enmascarados
               │
               ▼
┌───────────────────────────────────────────────────────┐
│  OUTPUT AL USUARIO                                    │
│  - success: true/false                                │
│  - message: "✅ Validación exitosa"                   │
│  - tokenParcial: "tok_1234...5678" (ENMASCARADO)     │
│  - paymentMethodId: "a0X..."                          │
└───────────────────────────────────────────────────────┘
```

---

## 📝 PASOS DE IMPLEMENTACIÓN - OPCIÓN 1 (RECOMENDADA)

### **FASE 1: Preparación (30 min)**

1. ✅ Desplegar Apex Class: `SM_ValidarTarjetaInvocable.cls`
2. ✅ Desplegar Permission Set: `SM_ValidadorTarjetas.permissionset-meta.xml`
3. Asignar Permission Set a usuarios piloto

```bash
# Desplegar con SF CLI
sf project deploy start --source-dir force-app/main/default/classes
sf project deploy start --source-dir force-app/main/default/permissionsets

# Asignar Permission Set
sf org assign permset --name SM_ValidadorTarjetas --target-org <alias>
```

### **FASE 2: Crear Screen Flow (1-2 horas)**

**Flow Builder Steps:**

1. **Crear nuevo Flow**
   - Setup → Flows → New Flow
   - Tipo: Screen Flow
   - API Name: `Validar_Tarjeta_Credito_Flow`

2. **Screen 1: "Datos de Entrada"**
   - Agregar componente: Display Text
     - Texto: "Ingrese los datos de la tarjeta a validar"
   - Agregar componente: Text
     - Label: "Número de Contrato"
     - API Name: `numeroContrato`
     - Required: ✅
   - Agregar componente: Text
     - Label: "Payment Method Name"
     - API Name: `paymentMethodName`
     - Required: ✅
   - Agregar componente: Text
     - Label: "Últimas 4 dígitos"
     - API Name: `ultimasCuatro`
     - Required: ✅
     - Max Length: 4

3. **Action: "Ejecutar Validación"**
   - Type: Apex Action
   - Apex Class: `SM_ValidarTarjetaInvocable`
   - Action: `validarTarjeta`
   - Set Input Values:
     - numeroContrato = `{!numeroContrato}`
     - paymentMethodName = `{!paymentMethodName}`
     - ultimasCuatro = `{!ultimasCuatro}`
   - Store Output Values:
     - `validacionResult` (Variable, tipo: Apex-Defined, Class: ValidarTarjetaOutput)

4. **Decision: "Validación Exitosa?"**
   - Outcome 1: "Éxito"
     - Condition: `{!validacionResult.success}` Equals `true`
   - Outcome 2: "Error"
     - Default

5. **Screen 2a: "Resultado Exitoso"** (después de Outcome "Éxito")
   - Display Text: `{!validacionResult.message}`
   - Display Text: "Token: `{!validacionResult.tokenParcial}`"
   - Display Text: "Payment Method ID: `{!validacionResult.paymentMethodId}`"

6. **Screen 2b: "Error"** (después de Outcome "Error")
   - Display Text: "❌ Error en la validación"
   - Display Text: `{!validacionResult.errores}`

7. **Activar Flow**
   - Save → Activate

### **FASE 3: Crear Quick Action (30 min)**

1. **Setup → Object Manager → Contract**
2. **Buttons, Links, and Actions → New Action**
   - Action Type: Flow
   - Flow: `Validar_Tarjeta_Credito_Flow`
   - Label: "Validar Tarjeta"
   - Name: `Validar_Tarjeta`
   - Icon: `utility:record_create`
   - Save

3. **Agregar a Page Layout**
   - Contract Page Layout → Mobile & Lightning Actions
   - Drag "Validar Tarjeta" a la sección
   - Save

### **FASE 4: Testing (1-2 horas)**

**Test Plan:**

```
Test Case 1: Validación Exitosa Simple
  Input:
    - Número Contrato: "00316772"
    - Payment Method: "PM-204801"
    - Últimas 4: "7303"
  Expected:
    ✅ Contrato actualizado
    ✅ Orders TC actualizados
    ✅ Token enmascarado mostrado

Test Case 2: Token Duplicado con Historial
  Input:
    - Contrato con PM que tiene token duplicado
  Expected:
    ⚠️ Mensaje de token duplicado
    ✅ Usa OldValue del historial
    ✅ Actualización exitosa

Test Case 3: Últimas 4 No Coinciden
  Input:
    - Últimas 4 incorrectas
  Expected:
    ❌ Error de validación
    ❌ No actualiza nada

Test Case 4: Contrato Inactivo
  Input:
    - Contrato con Status = "Canceled"
  Expected:
    ❌ Error: "Contrato no encontrado o inactivo"

Test Case 5: PM Inactivo
  Input:
    - Payment Method con SM_Active__c = false
  Expected:
    ❌ Error: "Payment Method no válido"
```

### **FASE 5: Rollout (1 semana)**

1. **Piloto** (Días 1-3)
   - 3-5 usuarios comerciales de prueba
   - Monitorear Flow Interview Logs
   - Recopilar feedback

2. **Producción** (Día 4-7)
   - Desplegar a todos los usuarios comerciales
   - Training session (30 min)
   - Documentación de usuario

---

## 📚 DOCUMENTACIÓN DE USUARIO

### **Guía Rápida para Usuarios Comerciales**

**¿Cuándo usar "Validar Tarjeta"?**

- ✅ Cuando un cliente reporta problemas con su tarjeta
- ✅ Después de actualizar datos de payment method
- ✅ Cuando hay que sincronizar PM con Chargent Orders
- ✅ Para limpiar PMs duplicados

**¿Cómo usar?**

1. Abrir el **Contrato** del cliente
2. Click en botón **"Validar Tarjeta"**
3. Ingresar:
   - Número de Contrato (ej: 00316772)
   - Payment Method Name (ej: PM-204801)
   - Últimas 4 dígitos (ej: 7303)
4. Click **"Validar"**
5. Ver resultado

**¿Qué hace el proceso?**

- ✅ Valida que el PM pertenece al contrato
- ✅ Verifica las últimas 4 dígitos
- ✅ Detecta tokens duplicados
- ✅ Actualiza Contrato y todos los Chargent Orders activos
- ✅ Limpia Payment Methods duplicados que no están en uso

**Datos que necesitas:**

1. **Número de Contrato**: Lo encuentras en el campo "Contract Number"
2. **Payment Method Name**: En la sección de Payment Method del Contrato
3. **Últimas 4 dígitos**: Las que el cliente te proporciona

**¿Qué NO puedo ver?**

- ❌ Número completo de tarjeta (encriptado)
- ❌ Token completo (solo verás parcial: tok_1234...5678)
- ❌ CVV u otros datos sensibles

**Esto es CORRECTO** - es por seguridad PCI compliance.

---

## 🔍 TROUBLESHOOTING

### **Errores Comunes y Soluciones**

| Error | Causa | Solución |
|-------|-------|----------|
| "Contrato no encontrado o inactivo" | Contrato cancelado o número incorrecto | Verificar que el contrato esté Active |
| "Payment Method no válido" | PM inactivo o no pertenece a la cuenta | Verificar que SM_Active__c = true |
| "Las últimas 4 dígitos no coinciden" | Dígitos incorrectos | Pedir al cliente las últimas 4 correctas |
| "Error: Unauthorized endpoint" | Falta configuración de Remote Site | Admin debe configurar Chargent endpoint |

### **Monitoreo y Auditoría**

**Para Administradores:**

```sql
-- Consultar ejecuciones del Flow
SELECT Id, InterviewLabel, InterviewStatus, CurrentElement, 
       CreatedDate, CreatedBy.Name
FROM FlowInterview
WHERE FlowVersionViewId IN (
    SELECT Id FROM FlowVersionView 
    WHERE FlowDefinitionView.ApiName = 'Validar_Tarjeta_Credito_Flow'
)
ORDER BY CreatedDate DESC
LIMIT 100

-- Ver resultados exitosos vs errores
SELECT InterviewStatus, COUNT(Id) Total
FROM FlowInterview
WHERE FlowVersionViewId IN (
    SELECT Id FROM FlowVersionView 
    WHERE FlowDefinitionView.ApiName = 'Validar_Tarjeta_Credito_Flow'
)
AND CreatedDate = LAST_N_DAYS:7
GROUP BY InterviewStatus
```

---

## 🎯 RECOMENDACIÓN FINAL

### **✅ OPCIÓN RECOMENDADA: SCREEN FLOW + INVOCABLE APEX**

**Razones:**

1. **Balance perfecto** entre complejidad y funcionalidad
2. **Rápida implementación** - puedes tenerlo funcionando en 2-3 días
3. **Bajo mantenimiento** - admins pueden modificar el Flow sin developers
4. **Seguridad sólida** - campos encriptados protegidos
5. **Auditoría completa** - cada ejecución queda registrada
6. **Mobile ready** - funciona en Salesforce Mobile App
7. **Escalable** - fácil agregar validaciones adicionales

**Próximos pasos sugeridos:**

1. ✅ **Ya completado**: Apex Class + Permission Set creados
2. **Siguiente**: Crear el Screen Flow (1-2 horas)
3. **Después**: Crear Quick Action en Contract (30 min)
4. **Testing**: Probar con casos de uso reales (1-2 horas)
5. **Piloto**: 3-5 usuarios por 2-3 días
6. **Producción**: Rollout completo

---

## 📞 CONTACTO Y SOPORTE

**Desarrollador:** Carlos Lopez  
**Fecha Creación:** 2026-05-18  
**Versión:** 1.0

**Archivos Creados:**
- ✅ `force-app/main/default/classes/SM_ValidarTarjetaInvocable.cls`
- ✅ `force-app/main/default/classes/SM_ValidarTarjetaInvocable.cls-meta.xml`
- ✅ `force-app/main/default/permissionsets/SM_ValidadorTarjetas.permissionset-meta.xml`
- ✅ `GUIA_VALIDACION_TARJETAS_COMERCIAL.md` (este documento)

**Para soporte técnico:**
- Review de código Apex
- Configuración del Screen Flow
- Troubleshooting de errores
- Training para usuarios comerciales

---

## 📊 APÉNDICE: LÓGICA DEL SCRIPT VALIDACREDITCARD

### **Flujo del Script Original**

El script ValidaCreditCard realiza los siguientes pasos:

1. **Validación de Inputs**
   - Número de contrato
   - Payment Method Name
   - Últimas 4 dígitos

2. **Obtención de Datos**
   - Contrato activo (excluye Canceled/Finalized)
   - Payment Method de la misma Account
   - Validación de últimas 4 dígitos

3. **Detección de Duplicados**
   - Busca otros PMs con el mismo token
   - Si encuentra duplicados:
     - Consulta historial (`SM_Payment_Method__History`)
     - Usa `OldValue` del cambio más reciente
     - Si no hay historial, deja token en blanco

4. **Actualización de Chargent Orders**
   - Solo Orders con status 'Recurring' o 'Stopped'
   - Actualiza todos los campos de tarjeta:
     - Tokenization
     - Card Last 4
     - Expiration Month/Year
     - Billing Country
     - Card indicators

5. **Actualización del Contrato**
   - SM_Payment_Method__c → Payment Method seleccionado
   - SM_Registered_Card_Token__c → Token final

6. **Limpieza de Duplicados**
   - Identifica PMs duplicados (mismo token, últimas 4, mes y año)
   - Verifica que NO estén en uso por:
     - Contratos
     - Chargent Orders (TC)
   - Elimina solo los que NO están en uso

### **Campos Encriptados Manejados**

| Objeto | Campo | Tipo | Acceso Usuario |
|--------|-------|------|----------------|
| SM_Payment_Method__c | SM_Card_Token__c | Text | ❌ No |
| SM_Payment_Method__c | SM_Credit_Card_Number__c | Text(Encrypted) | ❌ No |
| ChargentOrders__Payment_Method__c | ChargentOrders__Card_Number__c | Text(Encrypted) | ❌ No |
| ChargentOrders__Payment_Method__c | ChargentOrders__Tokenization__c | Text | ❌ No |

**Nota importante:** El Apex con `without sharing` puede acceder a estos campos, pero el usuario comercial NUNCA los ve directamente. Solo recibe valores enmascarados como `tok_1234...5678` o `****`.

---

## 🚀 MEJORAS FUTURAS (ROADMAP)

### **Fase 2 (Opcional):**

1. **Pre-poblar campos automáticamente**
   - Obtener datos del contexto del Contrato
   - Usuario solo confirma los datos

2. **Integración con Chargent API real**
   - Validar tarjeta con Chargent Gateway
   - Obtener nuevo token si es necesario

3. **Notificaciones automáticas**
   - Email al cliente cuando se valida su tarjeta
   - Chatter post en el Contrato

4. **Dashboard de validaciones**
   - Report de validaciones por usuario
   - Métricas de éxito/error

5. **Batch processing**
   - Validar múltiples contratos a la vez
   - Procesamiento nocturno automático

---

**FIN DEL DOCUMENTO**
