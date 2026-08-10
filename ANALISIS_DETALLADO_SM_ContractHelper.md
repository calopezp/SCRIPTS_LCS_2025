# Análisis Detallado - SM_ContractHelper.cls

**Fecha:** 7 de Mayo, 2026  
**Archivo:** `force-app/main/default/classes/SM_ContractHelper.cls`  
**Tipo:** Clase Helper (without sharing)

---

## 🔍 USO DE SOAP API DETECTADO

### Línea 118-119: Construcción de URL SOAP

```apex
String sessionId = UserInfo.getSessionId();
String serverUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/37.0/' + UserInfo.getOrganizationId();
```

### Contexto de Uso

**Método:** `createRequestCongaAPI()`

**Propósito:** Crear una petición para la API de Conga Composer para generación de documentos PDF

**Flujo completo:**

1. Obtiene sessionId del usuario actual
2. Construye URL SOAP con versión **37.0** (Winter '17)
3. Codifica la URL para pasarla como parámetro a Conga
4. Agrega parámetros adicionales: `sessionId`, `serverUrl`, `APIMODE=13`

### Código Completo del Método

```apex
public static SM_ServiceInvokation createRequestCongaAPI() {

    SM_ServiceInvokation requestSI = new SM_ServiceInvokation(false);
    SM_SetupWebService__mdt setup = [SELECT SM_EndPoint__c, SM_Method__c, SM_timeOut__c, SM_Integration__c 
                                        FROM SM_SetupWebService__mdt 
                                        WHERE DeveloperName = 'SM_Create_PDF_via_Conga_API' LIMIT 1];

    String sessionId = UserInfo.getSessionId();
    String serverUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/37.0/' + UserInfo.getOrganizationId();
    
    requestSI.endPoint = setup.SM_EndPoint__c + '?sessionId=' + sessionId + '&serverUrl=' + EncodingUtil.urlEncode(serverUrl, 'UTF-8') + '&APIMODE=13';
    requestSI.method = setup.SM_Method__c;
    requestSI.integrationName = setup.SM_Integration__c;
    requestSI.timeout = Integer.valueOf(setup.SM_timeOut__c);

    return requestSI;
}
```

---

## 📊 ANÁLISIS TÉCNICO

### ⚠️ Problemas Identificados

#### 1. **CRÍTICO: API Version 37.0 (Winter '17)**
- **Release:** Enero 2017 (hace más de 8 años)
- **Estado:** Deprecada
- **Riesgo:** Alto - puede dejar de funcionar en cualquier momento
- **Impacto:** Generación de documentos Conga fallaría completamente

#### 2. **MEDIO: Uso de SessionId directamente**
- **Problema:** `UserInfo.getSessionId()` no es la mejor práctica
- **Alternativa:** OAuth 2.0 con Named Credentials
- **Riesgo:** Menos seguro, dificulta auditoría

#### 3. **BAJO: Hardcoded APIMODE**
- **Valor:** `APIMODE=13`
- **Problema:** No está parametrizado
- **Recomendación:** Mover a Custom Metadata

---

## 🔗 INTEGRACION CONGA COMPOSER

### ¿Qué es Conga Composer?

Conga Composer es una herramienta de terceros para:
- Generar documentos (PDF, Word, Excel)
- Combinar plantillas con datos de Salesforce
- Enviar documentos por email
- Almacenar en Salesforce Files

### Flujo de Integración Actual

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│  Salesforce │ ----> │ SM_ContractHelper│ ----> │ Conga API   │
│  Contract   │       │ createRequest... │       │ (External)  │
└─────────────┘       └──────────────────┘       └─────────────┘
                              │
                              │ Pasa:
                              │ - SessionId
                              │ - ServerUrl (SOAP)
                              │ - Contract Data
                              ▼
                      ┌──────────────────┐
                      │   Genera PDF     │
                      │   Envía Email    │
                      └──────────────────┘
```

### Métodos Relacionados

1. **`createRequestCongaAPI()`** - Crea la petición base
2. **`addAdditionalParamsToURLCongaAPI()`** - Agrega parámetros del contrato
3. **`getRequiredInfoToCongaAPI()`** - Obtiene datos del contrato

### Custom Metadata Involucrado

**DeveloperName:** `SM_Create_PDF_via_Conga_API`

Campos usados:
- `SM_EndPoint__c` - URL base de Conga API
- `SM_Method__c` - HTTP Method (probablemente GET)
- `SM_timeOut__c` - Timeout en milisegundos
- `SM_Integration__c` - Nombre de integración para logs

---

## 🎯 CASOS DE USO

### Escenarios donde se usa esta integración:

1. **Generación de Contratos PDF**
   - Cuando un contrato pasa a estado "Payment Process"
   - Necesita firmas electrónicas
   - Requiere documento formal

2. **Envío Automático por Email**
   - Usa campo `SM_Email_to_send_contract__c`
   - Envía al cliente final
   - Incluye datos del contrato

3. **Parámetros Dinámicos**
   ```apex
   .replace('{!Contract.Id}', ct.Id)
   .replace('{!Contract.Account}', EncodingUtil.urlEncode(ct.SM_Account_Name__c + ' - ' + ct.ContractNumber, 'UTF-8'))
   .replace('{!Account.PersonEmail}', ct.SM_Email_to_send_contract__c)
   ```

---

## 🔧 DEPENDENCIAS

### Objetos Salesforce Relacionados

1. **Contract** - Objeto principal
2. **SM_SetupWebService__mdt** - Custom Metadata Type
3. **APXTConga4__Conga_Solution__c** - Configuración Conga
4. **SM_ServiceInvokation** - Wrapper class para requests

### Otros Métodos en la Clase

La clase `SM_ContractHelper` contiene:
- **Enums:** Status, WayOfContract, Payment types, etc.
- **Métodos de consulta:** `getContractsByOppId()`, `getContractWithOrders()`
- **Métodos de negocio:** `updateContract()`, `getCongaSolutionSetupByContractId()`

---

## 💡 PLAN DE MODERNIZACIÓN

### Opción 1: Actualizar Versión SOAP (Rápido)

**Esfuerzo:** 1-2 horas  
**Riesgo:** Bajo  
**Beneficio:** Mantiene compatibilidad, versión actual

```apex
// Cambiar de:
String serverUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/37.0/' + UserInfo.getOrganizationId();

// A (versión más reciente):
String serverUrl = Url.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/60.0/' + UserInfo.getOrganizationId();
```

**Testing necesario:**
- ✅ Validar que Conga API acepta v60.0
- ✅ Probar generación de PDF
- ✅ Verificar envío de emails

---

### Opción 2: Migrar a Named Credentials (Recomendado)

**Esfuerzo:** 3-5 días  
**Riesgo:** Medio  
**Beneficio:** Seguridad mejorada, OAuth 2.0, auditoría

#### Paso 1: Crear Named Credential

```
Setup > Named Credentials > New Named Credential

Name: Conga_Composer_API
URL: [Conga API Base URL]
Identity Type: Named Principal
Authentication Protocol: OAuth 2.0
```

#### Paso 2: Refactorizar Código

```apex
public static SM_ServiceInvokation createRequestCongaAPI() {
    
    SM_ServiceInvokation requestSI = new SM_ServiceInvokation(false);
    
    // Usar Named Credential en lugar de construcción manual
    requestSI.endPoint = 'callout:Conga_Composer_API/v1/composer';
    requestSI.method = 'POST'; // REST API moderna
    
    // Los headers OAuth se manejan automáticamente
    requestSI.integrationName = 'Conga_PDF_Generation';
    requestSI.timeout = 120000;
    
    return requestSI;
}
```

#### Paso 3: Actualizar addAdditionalParamsToURLCongaAPI

```apex
public static void addAdditionalParamsToURLCongaAPI(SM_ServiceInvokation requestSI, Contract ct, String congaComposerParameters) {
    
    // Construir body JSON en lugar de query params
    Map<String, Object> requestBody = new Map<String, Object>{
        'recordId' => ct.Id,
        'templateId' => 'xxx', // De Conga Solution
        'outputFormat' => 'PDF',
        'recipient' => ct.SM_Email_to_send_contract__c,
        'fileName' => ct.SM_Account_Name__c + ' - ' + ct.ContractNumber + '.pdf'
    };
    
    requestSI.body = JSON.serialize(requestBody);
    requestSI.headers = new Map<String, String>{
        'Content-Type' => 'application/json'
    };
}
```

---

### Opción 3: Evaluar Alternativas a Conga

**Esfuerzo:** 4-8 semanas  
**Riesgo:** Alto  
**Beneficio:** Modernización completa, menor costo

#### Alternativas Modernas:

1. **Salesforce Document Generation (Nativo)**
   - Feature nativo de Salesforce
   - No requiere integración externa
   - Menor costo de licencias

2. **Nintex DocGen**
   - Moderna y cloud-native
   - Better UX
   - API REST nativa

3. **PandaDoc**
   - Especializado en firmas electrónicas
   - Workflow moderno
   - API REST robusta

---

## 📋 CHECKLIST DE IMPLEMENTACIÓN

### Para Opción 1 (Actualizar Versión)

- [ ] Backup del código actual
- [ ] Cambiar `37.0` a `60.0` en línea 119
- [ ] Deploy a Sandbox
- [ ] Probar generación de PDF con contrato de prueba
- [ ] Verificar email enviado correctamente
- [ ] Validar PDF generado (formato, contenido)
- [ ] Deploy a Producción
- [ ] Monitorear por 1 semana

**Estimado:** 2-4 horas

---

### Para Opción 2 (Named Credentials)

#### Fase 1: Configuración (1 día)
- [ ] Registrar aplicación en Conga
- [ ] Obtener Client ID y Client Secret
- [ ] Crear Named Credential en Salesforce
- [ ] Configurar OAuth Flow
- [ ] Probar autenticación

#### Fase 2: Desarrollo (2 días)
- [ ] Refactorizar `createRequestCongaAPI()`
- [ ] Actualizar `addAdditionalParamsToURLCongaAPI()`
- [ ] Modificar `SM_ServiceInvokation` si es necesario
- [ ] Actualizar Custom Metadata `SM_Create_PDF_via_Conga_API`
- [ ] Crear/actualizar test classes

#### Fase 3: Testing (1 día)
- [ ] Unit tests con 85%+ coverage
- [ ] Integration tests en Sandbox
- [ ] User Acceptance Testing (UAT)
- [ ] Performance testing

#### Fase 4: Deployment (1 día)
- [ ] Deploy a Sandbox Full
- [ ] Smoke tests en Sandbox Full
- [ ] Deploy a Producción (ventana de cambios)
- [ ] Monitoreo post-deployment
- [ ] Documentación actualizada

**Estimado:** 3-5 días

---

## 🚨 RIESGOS Y MITIGACIÓN

### Riesgo 1: Conga API no soporta versión nueva
**Probabilidad:** Baja  
**Impacto:** Alto  
**Mitigación:**
- Contactar soporte de Conga antes de cambiar
- Validar en documentación de Conga
- Probar exhaustivamente en Sandbox

### Riesgo 2: Cambio rompe generación de documentos
**Probabilidad:** Media  
**Impacto:** Alto  
**Mitigación:**
- Implementar feature flag
- Mantener código legacy como fallback
- Testing completo antes de deploy

### Riesgo 3: Usuarios reportan problemas post-deployment
**Probabilidad:** Media  
**Impacto:** Medio  
**Mitigación:**
- Deploy en horario de bajo uso
- Plan de rollback inmediato
- Comunicación previa a usuarios
- Monitoreo activo 24-48h post-deploy

---

## 📊 MÉTRICAS DE ÉXITO

### KPIs a Monitorear

1. **Tasa de Éxito de Generación de PDF**
   - Meta: 99%+ success rate
   - Baseline actual: [Por determinar]

2. **Tiempo de Respuesta**
   - Meta: < 5 segundos
   - Baseline actual: [Por determinar]

3. **Errores de Integración**
   - Meta: < 1% error rate
   - Baseline actual: [Por determinar]

4. **User Satisfaction**
   - Meta: Sin tickets post-cambio
   - Monitoreo: 30 días

---

## 🔍 QUERIES PARA ANÁLISIS

### Verificar uso de esta funcionalidad

```sql
-- Contratos que han generado PDFs (últimos 30 días)
SELECT COUNT(Id), Status, CreatedDate
FROM Contract
WHERE Status = 'Payment Process'
AND CreatedDate = LAST_N_DAYS:30
GROUP BY Status, CALENDAR_MONTH(CreatedDate)

-- Verificar configuración Conga actual
SELECT DeveloperName, SM_EndPoint__c, SM_Method__c, SM_timeOut__c
FROM SM_SetupWebService__mdt
WHERE DeveloperName = 'SM_Create_PDF_via_Conga_API'

-- Buscar errores de integración recientes
SELECT Id, Operation, Request, Response, CreatedDate
FROM SM_Integration_Log__c
WHERE Integration_Name__c = 'Conga_PDF_Generation'
AND CreatedDate = LAST_N_DAYS:7
AND Status__c = 'Error'
ORDER BY CreatedDate DESC
```

---

## 💰 ESTIMACIÓN DE COSTOS

### Opción 1: Actualizar Versión
- **Desarrollo:** 2-4 horas × $100/hr = $200-400
- **Testing:** 1-2 horas × $100/hr = $100-200
- **Total:** $300-600

### Opción 2: Named Credentials
- **Desarrollo:** 3 días × $800/día = $2,400
- **Testing:** 1 día × $800/día = $800
- **Deployment:** 1 día × $800/día = $800
- **Total:** $4,000

### Opción 3: Cambiar a Alternativa
- **Evaluación:** 1 semana × $4,000/semana = $4,000
- **Implementación:** 6-8 semanas × $4,000/semana = $24,000-32,000
- **Licencias:** Variable (depende de proveedor)
- **Total:** $28,000-36,000+

---

## 🎯 RECOMENDACIÓN FINAL

### Corto Plazo (Inmediato)
✅ **OPCIÓN 1: Actualizar a API v60.0**
- Menor riesgo
- Rápida implementación
- Resuelve problema crítico de versión deprecada

### Medio Plazo (3-6 meses)
✅ **OPCIÓN 2: Migrar a Named Credentials**
- Mejora seguridad
- Mejor práctica de Salesforce
- Facilita auditoría y compliance

### Largo Plazo (12+ meses)
📋 **OPCIÓN 3: Evaluar alternativas**
- Cuando se renegocie contrato con Conga
- Si hay presupuesto para modernización
- Como parte de iniciativa de arquitectura cloud

---

## 📝 PRÓXIMOS PASOS INMEDIATOS

1. ✅ **Validar versión soportada por Conga**
   - Contactar: Conga Support
   - Revisar: Documentación API Conga

2. ✅ **Crear ticket de trabajo**
   - Título: "Actualizar SOAP API de v37 a v60 en SM_ContractHelper"
   - Prioridad: Alta
   - Sprint: Próximo disponible

3. ✅ **Ejecutar script de análisis**
   - Correr: `Analizar_SOAP_API_Usage.apex`
   - Obtener: Datos de uso real
   - Documentar: Patrones de uso

4. ✅ **Preparar ambiente de pruebas**
   - Sandbox: Con datos de produc