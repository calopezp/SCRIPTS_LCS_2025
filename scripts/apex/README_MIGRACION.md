# 📦 SCRIPT DE MIGRACIÓN DE CONTRATO A SANDBOX

## 🎯 Objetivo

Migrar el contrato **00316311** de producción a sandbox con todos sus datos relacionados para poder realizar pruebas de la funcionalidad de validación de tarjetas.

## 📋 Datos que se Migran

El script migra los siguientes datos:

1. ✅ **Account** - Cuenta del cliente
2. ✅ **SM_Billing_Address__c** - Dirección de facturación
3. ✅ **SM_Payment_Method__c** - Métodos de pago (con datos de prueba)
4. ✅ **Contract** - Contrato
5. ✅ **ChargentOrders__ChargentOrder__c** - Órdenes de Chargent

## 🔒 Nota Importante sobre Datos Encriptados

⚠️ **Los campos encriptados NO se pueden extraer directamente de producción por seguridad.**

El script genera:
- **Tokens de prueba**: `tok_sandbox_1_7303`
- **Números de tarjeta enmascarados**: `****7303`
- **Preserva las últimas 4 dígitos** para poder hacer validaciones

Esto es **perfecto para testing** ya que simula el comportamiento real sin exponer datos sensibles.

---

## 📝 INSTRUCCIONES DE USO

### PASO 1: Ejecutar en PRODUCCIÓN

1. **Abrir Developer Console** en tu org de producción
2. **Debug → Open Execute Anonymous Window**
3. **Copiar y pegar** el contenido completo de `Migrar_Contrato_Sandbox.apex`
4. **Marcar** "Open Log" checkbox
5. **Click "Execute"**

### PASO 2: Copiar el Output

1. En el **Debug Log**, buscar la sección:
   ```
   ========================================
   SCRIPT PARA EJECUTAR EN SANDBOX
   ========================================
   ```

2. **Copiar TODO** el código desde ahí hasta el final

3. Debe verse algo como:
   ```apex
   // 1️⃣ CREAR ACCOUNT
   Account acc = new Account(
       Name = 'Cliente Nombre (SANDBOX)',
       ...
   );
   ```

### PASO 3: Ejecutar en SANDBOX

1. **Abrir Developer Console** en tu SANDBOX
2. **Debug → Open Execute Anonymous Window**
3. **Pegar** el código copiado del paso anterior
4. **Marcar** "Open Log" checkbox
5. **Click "Execute"**

### PASO 4: Verificar Creación

Deberías ver en el log:
```
========================================
MIGRACIÓN COMPLETADA EXITOSAMENTE
Account: 001XXXXXXX - Cliente Nombre (SANDBOX)
Contrato: 800XXXXXXX - Número: 00316311
Payment Methods: X
Chargent Orders: X
========================================
```

---

## 🧪 DATOS DE PRUEBA GENERADOS

### Payment Methods
```
Name: PM-204801 (ejemplo)
SM_Card_Token__c: tok_sandbox_1_7303
SM_Credit_Card_Number__c: ****7303
SM_Credit_Card_expiration_month__c: 12
SM_Credit_Card_expiration_year__c: 2027
```

### Chargent Orders
```
ChargentOrders__Tokenization__c: tok_sandbox_1_7303
ChargentOrders__Card_Last_4__c: 7303
ChargentOrders__Card_Expiration_Month__c: 12
ChargentOrders__Card_Expiration_Year__c: 2027
ChargentOrders__Payment_Status__c: Recurring
```

---

## ✅ TESTING DE LA FUNCIONALIDAD

Una vez migrados los datos, puedes probar:

### Test Case 1: Validación Exitosa
```
1. Abrir el contrato creado en sandbox
2. Click en "Validar Tarjeta" (LWC o Flow)
3. Datos pre-poblados automáticamente
4. Ingresar últimas 4: 7303
5. Click "Validar Tarjeta"

Expected:
✅ Validación exitosa
✅ Token actualizado
✅ Chargent Orders actualizados
```

### Test Case 2: Error - Últimas 4 Incorrectas
```
1. Ingresar últimas 4: 1234 (incorrecto)
2. Click "Validar Tarjeta"

Expected:
❌ Error: "Las últimas 4 dígitos no coinciden"
```

### Test Case 3: Seguridad - Campos Encriptados
```
1. Usuario comercial abre el contrato
2. Intenta ver campo SM_Credit_Card_Number__c
3. Intenta ver campo SM_Card_Token__c

Expected:
❌ Campos muestran **** (enmascarados)
✅ Usuario NO puede ver datos reales
✅ Permission Set funcionando correctamente
```

### Test Case 4: Múltiples Payment Methods
```
1. Si el contrato tiene múltiples PMs
2. Validar con diferentes últimas 4 dígitos
3. Verificar que se actualiza el PM correcto

Expected:
✅ Solo el PM correcto se actualiza
✅ Otros PMs no se modifican
```

---

## 🔧 TROUBLESHOOTING

### Error: "REQUIRED_FIELD_MISSING"

**Causa**: Algún campo requerido falta en el objeto

**Solución**: 
- Revisar que todos los objetos personalizados existen en sandbox
- Verificar que los campos requeridos tienen valores

### Error: "FIELD_CUSTOM_VALIDATION_EXCEPTION"

**Causa**: Validation rules bloqueando la creación

**Solución**:
- Temporalmente desactivar validation rules en sandbox
- O ajustar los valores para cumplir las validaciones

### Error: "DUPLICATE_VALUE"

**Causa**: Ya existe un registro con el mismo valor único

**Solución**:
- Modificar el nombre del Account agregando timestamp
- O eliminar datos previos en sandbox

### Script no genera output completo

**Causa**: Log demasiado largo

**Solución**:
1. Aumentar Debug Log Level
2. O copiar en secciones más pequeñas
3. O ejecutar el script por partes

---

## 📊 EJEMPLO DE EJECUCIÓN

### Output en Producción:
```
INICIANDO EXTRACCIÓN DE DATOS
Contrato: 00316311

✅ Contrato encontrado: 800XXXXXXX
✅ Account encontrada: Cliente Test (001XXXXXXX)
✅ Billing Address encontrada: BA-001
✅ Payment Methods encontrados: 2
✅ Chargent Orders encontrados: 3

SCRIPT PARA EJECUTAR EN SANDBOX

// 1️⃣ CREAR ACCOUNT
Account acc = new Account(
    Name = 'Cliente Test (SANDBOX)',
    BillingStreet = '123 Main St',
    ...
);
insert acc;
...
```

### Output en Sandbox:
```
✅ Account creada: 001YYYYYYYY
✅ Billing Address creada: a0XZZZZZZZZ
✅ Payment Methods creados: 2
✅ Contrato creado: 800WWWWWWWW
✅ Contrato activado
✅ Chargent Orders creados: 3

MIGRACIÓN COMPLETADA EXITOSAMENTE
Account: 001YYYYYYYY - Cliente Test (SANDBOX)
Contrato: 800WWWWWWWW - Número: 00316311
Payment Methods: 2
Chargent Orders: 3
```

---

## 🎯 PRÓXIMOS PASOS

Después de migrar los datos:

1. ✅ **Desplegar componente LWC** en sandbox
   ```bash
   cd validacion-tarjetas-lwc
   sf project deploy start --target-org sandbox
   ```

2. ✅ **Asignar Permission Set**
   ```bash
   sf org assign permset --name SM_ValidadorTarjetasLWC --target-org sandbox
   ```

3. ✅ **Configurar Quick Action** (ver GUIA_IMPLEMENTACION.md)

4. ✅ **Ejecutar tests** con el contrato migrado

5. ✅ **Documentar resultados** de las pruebas

---

## 📞 SOPORTE

Si encuentras problemas durante la migración:

1. **Verificar logs** en Developer Console
2. **Revisar permisos** del usuario ejecutando el script
3. **Consultar documentación**:
   - [GUIA_IMPLEMENTACION.md](../../validacion-tarjetas-lwc/GUIA_IMPLEMENTACION.md)
   - [README.md](../../validacion-tarjetas-lwc/README.md)

---

## ⚠️ NOTAS IMPORTANTES

1. **Sandbox Refresh**: Si haces refresh de sandbox, deberás volver a ejecutar el script

2. **Datos de Prueba**: Los tokens y números de tarjeta son ficticios y seguros

3. **No Producción**: NUNCA ejecutar el script de creación en producción

4. **Backup**: Siempre hacer backup de sandbox antes de pruebas masivas

5. **Cleanup**: Después de las pruebas, puedes eliminar los registros creados

---

## 📝 CHECKLIST DE MIGRACIÓN

```
Pre-Migración:
[ ] Acceso a producción verificado
[ ] Acceso a sandbox verificado
[ ] Developer Console abierto en ambas orgs
[ ] Script descargado y listo

Durante Migración:
[ ] Script ejecutado en producción
[ ] Output copiado completo
[ ] Script ejecutado en sandbox
[ ] Registros creados verificados

Post-Migración:
[ ] Contrato visible en sandbox
[ ] Payment Methods verificados
[ ] Chargent Orders verificados
[ ] Datos de prueba correctos
[ ] Listo para testing de funcionalidad
```

---

**FIN DE LA GUÍA DE MIGRACIÓN**

Fecha: 2026-05-18  
Versión: 1.0  
Autor: Carlos Lopez
