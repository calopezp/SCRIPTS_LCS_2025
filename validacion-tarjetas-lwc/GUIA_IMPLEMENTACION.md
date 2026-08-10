# 📚 GUÍA DE IMPLEMENTACIÓN - VALIDACIÓN DE TARJETAS LWC

## 🎯 Objetivo

Implementar un componente Lightning Web Component que permita a usuarios comerciales validar y actualizar payment methods en Chargent Orders, manteniendo la seguridad de campos encriptados.

## 📋 Tabla de Contenidos

1. [Prerrequisitos](#prerrequisitos)
2. [Fase 1: Preparación del Entorno](#fase-1-preparación-del-entorno)
3. [Fase 2: Despliegue de Metadata](#fase-2-despliegue-de-metadata)
4. [Fase 3: Configuración del Quick Action](#fase-3-configuración-del-quick-action)
5. [Fase 4: Testing](#fase-4-testing)
6. [Fase 5: Rollout a Producción](#fase-5-rollout-a-producción)
7. [Troubleshooting](#troubleshooting)
8. [FAQs](#faqs)

---

## Prerrequisitos

### Herramientas Requeridas

- ✅ **Salesforce CLI** v2.0+
  ```bash
  sf --version
  ```
- ✅ **VS Code** con extensiones:
  - Salesforce Extension Pack
  - ESLint
  - Prettier  ⚠️ ¿que version ?

### Permisos Requeridos

- ✅ System Administrator o permisos para:
  - Desplegar metadata
  - Crear/modificar Quick Actions
  - Asignar Permission Sets
  - Modificar Page Layouts

### Org Requirements

- ✅ Objetos personalizados:
  - ✅ `Contract` (estándar)
  - ✅ `SM_Payment_Method__c`
  - ✅ `ChargentOrders__ChargentOrder__c`
  - ✅ Field History Tracking habilitado en `SM_Payment_Method__c.SM_Card_Token__c`

---

## Fase 1: Preparación del Entorno

### 1.1 Autenticar con la Org

```bash
# Producción
sf org login web --alias prod --instance-url https://monee.salesforce.com

# Sandbox
☑️ sf org login web --alias sandbox --instance-url https://monee--preprod.sandbox.my.salesforce.com/

# Establecer org por defecto
☑️ sf config set target-org=sandbox
```

### 1.2 Verificar Estructura del Proyecto

```bash
☑️ cd validacion-tarjetas-lwc

# Listar archivos
☑️ ls -la force-app/main/default/

# Debes ver:
# - classes/
# - lwc/
# - permissionsets/
```

### 1.3 Validar Metadata antes de Desplegar

```bash
# Validar sin desplegar
☑️ sf project deploy validate --source-dir force-app --target-org sandbox

# Si hay errores, corregir antes de continuar
```
⚠️ aparece un error para registrs de tipo ACH.. No aplican
---

## Fase 2: Despliegue de Metadata

### 2.1 Desplegar Apex Classes

```bash
# Desplegar solo Apex
☑️ sf project deploy start --source-dir force-app/main/default/classes --target-org sandbox --verbose

☑️ # Verificar despliegue exitoso
# ✅ Deployed Source:
#  - SM_ValidarTarjetaController
#  - SM_ValidarTarjetaService
```

### 2.2 Desplegar LWC

```bash
# Desplegar Lightning Web Component
☑️ sf project deploy start --source-dir force-app/main/default/lwc --target-org sandbox --verbose

☑️ # Verificar despliegue exitoso
# ✅ Deployed Source:
#  - validarTarjetaCredito
```

### 2.3 Desplegar Permission Set

```bash
# Desplegar Permission Set
☑️ sf project deploy start --source-dir force-app/main/default/permissionsets --target-org sandbox --verbose

☑️ # Verificar despliegue exitoso
# ✅ Deployed Source:
#  - SM_ValidadorTarjetasLWC
```

                      ### 2.4 Despliegue Completo (Alternativa)   OJO, despliega todo lo del proyecto.

                      ```bash
                      # Desplegar todo a la vez
                      ⛔ sf project deploy start --source-dir force-app --target-org sandbox --test-level RunLocalTests --verbose

                      ⛔ # Esperar a que complete...
                      # ✅ Deploy Succeeded
                      ```

### 2.5 Asignar Permission Set

```bash
# Asignar a usuario específico
☑️ sf org assign permset --name SM_ValidadorTarjetasLWC --on-behalf-of user@example.com --target-org sandbox
          rmontiel@legal-credit.com.preprod


# O asignar a ti mismo para testing
☑️ sf org assign permset --name SM_ValidadorTarjetasLWC --target-org sandbox
---

## Fase 3: Configuración del Quick Action

☑️ ### 3.1 Crear Quick Action (Manual en UI)

1. **Navegar a Setup**
 - Setup → Object Manager → Contract

2. **Crear Nueva Acción**
 - Buttons, Links, and Actions → New Action
   
3. **Configurar Acción**
   ```
   Action Type: Lightning Web Component
   Lightning Web Component: c:validarTarjetaCredito
   Height: 500
   Label: Validar Tarjeta
   Name: Validar_Tarjeta
   Icon: utility:record_create
   Description: Valida y actualiza payment method del contrato
   ```

4. **Guardar**

☑️ ### 3.2 Agregar Acción al Page Layout

1. **Abrir Contract Page Layout**
 - Setup → Object Manager → Contract → Page Layouts
 - Seleccionar el layout usado por usuarios comerciales

2. **Agregar Acción**
 - Click en "Mobile & Lightning Actions"
 - Drag "Validar Tarjeta" desde la paleta a la sección "Salesforce Mobile and Lightning Experience Actions"
 - Ordenar según preferencia

3. **Guardar**

☑️ ### 3.3 Verificar Visibilidad

1. Abrir un Contract en Lightning Experience
2. Verificar que aparece el botón "Validar Tarjeta" en las acciones
3. Click para verificar que abre el componente

---

## Fase 4: Testing

### 4.1 Test Plan

#### Test Case 1: Validación Exitosa Simple

```
Prerrequisitos:
- Contrato activo con Payment Method
- PM con últimas 4 dígitos conocidas
- Usuario con Permission Set asignado

Steps:
1. Abrir contrato
2. Click "Validar Tarjeta"
3. Verificar pre-población de campos
4. Ingresar últimas 4 dígitos
5. Click "Validar Tarjeta"

Expected Result:
✅ Mensaje de éxito
✅ Token parcial mostrado (tok_xxxx...xxxx)
✅ Contrato actualizado
✅ Chargent Orders actualizados
```

#### Test Case 2: Validación con Token Duplicado

```
Prerrequisitos:
- PM con token duplicado en la cuenta
- Historial de cambios en SM_Card_Token__c

Steps:
1. Ejecutar validación

Expected Result:
⚠️ Mensaje "Token duplicado. Usando OldValue"
✅ Usa token del historial
✅ Actualización exitosa
```

#### Test Case 3: Error - Últimas 4 No Coinciden

```
Steps:
1. Ingresar últimas 4 dígitos incorrectas
2. Click "Validar Tarjeta"

Expected Result:
❌ Error: "Las últimas 4 dígitos no coinciden"
❌ No actualiza nada
```

#### Test Case 4: Seguridad - Campos Encriptados

```
Steps:
1. Usuario comercial intenta ver campo SM_Credit_Card_Number__c
2. Usuario comercial intenta ver campo SM_Card_Token__c

Expected Result:
❌ Campos aparecen como "****" o no visibles
✅ Permission Set bloquea lectura
```

### 4.2 Ejecutar Tests

```bash
# Ejecutar tests Apex
sf apex run test --class-names SM_ValidarTarjetaController,SM_ValidarTarjetaService --result-format human --target-org sandbox

# Ver cobertura
sf apex get test --code-coverage --result-format human --target-org sandbox
```

### 4.3 Testing Manual - Checklist

```
[ ] Pre-población de campos funciona
[ ] Validación de 4 dígitos (solo números)
[ ] Spinner de carga aparece
[ ] Toast messages aparecen
[ ] Resultado exitoso muestra todos los datos
[ ] Resultado de error muestra detalles
[ ] Botón "Cerrar" cierra el modal
[ ] Funciona en mobile (Salesforce App)
[ ] Permission Set bloquea campos encriptados
[ ] Debug logs no muestran datos sensibles
```

---

## Fase 5: Rollout a Producción

### 5.1 Preparación

```bash
# 1. Autenticar con producción
☑️ sf org login web --alias MONEE

# 2. Validar en producción SIN desplegar
sf project deploy validate --source-dir validacion-tarjetas-lwc/force-app --target-org MONEE --test-level RunLocalTests


force-app/main/default/classes
validacion-tarjetas-lwc/force-app


sf project deploy validate --source-dir force-app --target-org sandbox

# 3. Esperar validación exitosa
```

### 5.2 Change Set (Alternativa)

Si prefieres usar Change Sets:

1. **Crear Outbound Change Set en Sandbox**
 - Setup → Change Sets → Outbound Change Sets
 - New → "Validacion Tarjetas LWC"

2. **Agregar Componentes**
 - Apex Classes (2):
   - SM_ValidarTarjetaController
   - SM_ValidarTarjetaService
 - Lightning Component Bundles (1):
   - validarTarjetaCredito
 - Permission Sets (1):
   - SM_ValidadorTarjetasLWC

3. **Upload y Deploy**
 - Upload to Production
 - Deploy desde Setup en Producción

### 5.3 Despliegue Directo

```bash
# Desplegar a producción con tests
sf project deploy start --source-dir force-app --target-org prod --test-level RunLocalTests --verbose

# Monitorear progreso
# ✅ Running Tests: 100%
# ✅ Deploy Succeeded
```

### 5.4 Post-Deployment

1. **Asignar Permission Set a usuarios comerciales**
2. **Configurar Quick Action en Contract**
3. **Agregar a Page Layouts relevantes**
4. **Comunicar cambios al equipo**

---

## Troubleshooting

### Error: "Component c:validarTarjetaCredito is not available"

**Causa**: LWC no desplegado correctamente o cache

**Solución**:
```bash
# Re-desplegar LWC
sf project deploy start --source-dir force-app/main/default/lwc

# Limpiar cache del navegador
# Hard refresh: Ctrl+Shift+R (Windows) / Cmd+Shift+R (Mac)
```

### Error: "Insufficient privileges"

**Causa**: Usuario no tiene Permission Set asignado

**Solución**:
```bash
sf org assign permset --name SM_ValidadorTarjetasLWC
```

### Error: "FIELD_CUSTOM_VALIDATION_EXCEPTION"

**Causa**: Reglas de validación bloqueando actualización

**Solución**:
- Revisar validation rules en Contract y PM
- Temporalmente desactivar o ajustar lógica

### LWC no muestra datos pre-poblados

**Causa**: Wire service no recibiendo recordId

**Solución**:
1. Verificar que se usa como Quick Action (no standalone)
2. Revisar `@api recordId` en JS
3. Ver Browser Console para errores

### Toast messages no aparecen

**Causa**: Import incorrecto o eventos no disparados

**Solución**:
```javascript
// Verificar import
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Verificar dispatch
this.dispatchEvent(new ShowToastEvent({...}));
```

### Debug Logs

```bash
# Ver logs en tiempo real
sf apex tail log --target-org sandbox

# O en Setup:
# Setup → Debug Logs → New → Select User → Save
# Ejecutar acción → View Log
```

---

## FAQs

### ¿Por qué usar LWC en lugar de Screen Flow?

**LWC Ventajas:**
- ⭐ UI más moderna y personalizable
- ⭐ Validación en tiempo real
- ⭐ Mejor performance
- ⭐ Más control sobre UX

**Screen Flow Ventajas:**
- ⭐ Más fácil de implementar (sin código)
- ⭐ Más fácil de mantener por admins
- ⭐ Deployment más simple

**Recomendación**: Usa LWC si necesitas UX personalizada. Usa Flow si priorizas simplicidad.

### ¿Los usuarios comerciales pueden ver datos encriptados?

**NO**. El Permission Set `SM_ValidadorTarjetasLWC` tiene:
```xml
<fieldPermissions>
  <editable>false</editable>
  <field>SM_Payment_Method__c.SM_Card_Token__c</field>
  <readable>false</readable>
</fieldPermissions>
```

El Apex `without sharing` accede a los campos, pero retorna valores enmascarados.

### ¿Cómo agregar más validaciones?

**En Apex Service** (`SM_ValidarTarjetaService.cls`):
```java
// Agregar validación personalizada
if (pm.SM_Credit_Card_expiration_year__c < Date.today().year()) {
    throw new ServiceException('Tarjeta expirada');
}
```

### ¿Cómo personalizar la UI?

**En el HTML** (`validarTarjetaCredito.html`):
- Modificar textos
- Cambiar iconos
- Agregar campos

**En el CSS** (`validarTarjetaCredito.css`):
- Cambiar colores
- Ajustar spacing
- Modificar fonts

### ¿Funciona en Salesforce Mobile App?

**SÍ**. El componente está configurado para Quick Actions y es responsive.

### ¿Cómo hacer backup antes de desplegar?

```bash
# Backup de metadata existente
sf project retrieve start --metadata ApexClass:SM_ValidarTarjetaController --metadata ApexClass:SM_ValidarTarjetaService --target-org prod --output-dir backup/

# Guardar en Git
git add backup/
git commit -m "Backup before LWC deployment"
```

### ¿Cómo rollback si algo sale mal?

**Opción 1: Metadata API**
```bash
# Desplegar versión anterior desde backup
sf project deploy start --source-dir backup/
```

**Opción 2: Manual**
1. Desactivar Quick Action del Page Layout
2. Desactivar Permission Set
3. Eliminar componentes desde Setup

### ¿Se puede usar con otros objetos además de Contract?

**SÍ**. Modificar:
1. `@wire` en JS para obtener datos del nuevo objeto
2. Quick Action en el nuevo objeto
3. Lógica de validación en Apex si es necesario

---

## Mejores Prácticas

### 1. Logging

```java
// En Apex Service
System.debug(LoggingLevel.INFO, 'Validando PM: ' + pm.Name);
System.debug(LoggingLevel.ERROR, 'Error: ' + e.getMessage());
```

### 2. Error Handling

```javascript
// En LWC JS
try {
    const result = await validarTarjeta({...});
    // Manejar resultado
} catch (error) {
    console.error('Error:', error);
    this.showToast('Error', error.body?.message, 'error');
}
```

### 3. Testing

- ✅ Cobertura Apex >75%
- ✅ Test con datos reales en sandbox
- ✅ Test en mobile antes de producción
- ✅ Test con diferentes perfiles de usuario

### 4. Documentación

- ✅ Documentar cambios en código
- ✅ Mantener README actualizado
- ✅ Training para usuarios

### 5. Monitoreo

```bash
# Monitorear uso
SELECT COUNT(Id), HOUR_IN_DAY(CreatedDate) 
FROM ApexLog 
WHERE Operation = 'SM_ValidarTarjetaController'
GROUP BY HOUR_IN_DAY(CreatedDate)
```

---

## Recursos Adicionales

### Documentación Salesforce

- [Lightning Web Components Dev Guide](https://developer.salesforce.com/docs/component-library/documentation/en/lwc)
- [Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/)
- [Quick Actions](https://help.salesforce.com/s/articleView?id=sf.actions_overview.htm)

### Herramientas

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli)
- [VS Code Extensions](https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode)
- [Lightning Design System](https://www.lightningdesignsystem.com/)

---

## Contacto

**Desarrollador**: Carlos Lopez  
**Email**: dev@example.com  
**Fecha**: 2026-05-18  
**Versión**: 1.0

---

**FIN DE LA GUÍA DE IMPLEMENTACIÓN**
