# Mis pendientes — Carlos (no forma parte de la entrega a Juan)

## Checklist para cerrar la entrega a Juan

**Estado:** en curso (anotado 2026-10-08).

### ⚠️ PRIORITARIO — Adobe Acrobat Sign conectado con el usuario de Carlos

La conexión activa Adobe Acrobat Sign ↔ Salesforce está autorizada con `clopez@legal-credit.com` (token OAuth desde 2025-10-20, uso diario). Antes estuvo con Legal Credit Solutions (hasta 2025-09-24) y un mes con Juan. Al desactivar el usuario de Carlos, Salesforce revoca el token: Adobe Sign deja de actualizar estado, documento firmado y fecha de firma de los Agreements (los contratos se firman en Adobe pero Salesforce no se entera).

- [ ] 1. Entrar a la administración de Adobe Acrobat Sign (cuenta administradora de Adobe) → conexión con Salesforce → reconectar/reautorizar.
- [ ] 2. Autorizarla con el usuario **Legal Credit Solutions** (`salesforceadmin-qkv6@force.com`), no con una persona.
- [ ] 3. Verificar: Setup → Connected Apps OAuth Usage → el token de "Adobe Acrobat Sign" con uso reciente es el de Legal Credit Solutions; y un contrato de prueba firmado pasa a `Signed` en Salesforce con fecha de firma.
- [ ] 4. Solo entonces revocar el token de Carlos (se revoca solo al desactivar el usuario).

Hacerlo **antes** de desactivar el usuario de Carlos. El token "Adobe Acrobat Sign For Salesforce" (paquete) ya es de Legal Credit Solutions: no depende de Carlos.

**Repositorios y archivos**
- [x] Push de ENTREGA_JUAN hasta `b52a949`.
- [ ] **Push de ENTREGA_JUAN** (5 commits nuevos, último `df3259c`: script de traspaso, Apex/triggers/flows de MONEE, ajustes de la prueba punta a punta, PDF): `git push origin main` desde la sesión de ENTREGA_JUAN.
- [ ] Push de SCRIPTS_LCS_2025 (4 commits de MIS_PENDIENTES): `git push origin main`.
- [x] Push de SCRIPTS_LCS_2025 (2026-10-08).
- [x] Acceso de Juan a `LegalCredit/legal-credit-carlos-tools` (Juan lo creó y tiene acceso).
- [x] PDF del documento de entrega re-exportado con Word desde el .docx actual (`df3259c`, versión v1).
- [x] Zip de respaldo regenerado con todo (`df3259c`) y reemplazado en OneDrive (mismo nombre). Si cambia algo más, regenerarlo otra vez.
- [x] Respaldo `C:\SALESFORCE\LCS\ENTREGA_JUAN_respaldo_2026-10-08.zip` subido a OneDrive: https://legalcredit-my.sharepoint.com/:f:/g/personal/clopez_legal-credit_com/IgBCTioAmX-hQK4nrRjYBu9lAQhTNquAumK8XamRGbpFGZ4?e=TCvexl
- [ ] **Pasarle a Juan el respaldo** (OneDrive no transfiere propiedad entre personas: Juan hace su copia):
  1. Restringir el enlace: OneDrive web, sobre la carpeta → **Compartir** → **Configuración de vínculo** → **"Personas específicas"** → `jduarte@legal-credit.com`, **"Puede editar"**. No "Cualquier persona con el vínculo" (el zip trae cuentas bancarias).
  2. Juan copia: **Mi OneDrive → Compartido** → selecciona la carpeta → **Copiar en** → **Mis archivos**.
  3. Juan confirma que el zip está en su OneDrive, que abre, y manda su enlace nuevo.
  4. Opcional, por TI: al desactivar la cuenta, "Conceder a otro usuario acceso a los archivos de OneDrive" → Juan. Red de seguridad, no plan principal.
- [x] **`COMPILADO COLLECTIONS\ACH Reportados`** copiada a la carpeta de entrega del Drive (698 archivos). `ACH Returns` y `Check Collection` no se copian: son accesos directos a las carpetas de Elba (ver INSTALACION sección 2).
- [ ] Pedirle a Elba que comparta con Juan sus carpetas `ACH Returns` y `Check Collection` (`Collections Campaign\Reportes de Banca`).
- [ ] Correo a Juan: enviar la última versión (sección PRIORITARIO de Adobe Sign, `COMPILADO COLLECTIONS` con accesos directos, y en "Día del cierre" correr `scripts/traspaso/traspaso_usuario.py`).

**Día del cierre (lo corre Juan, con Carlos presente)**
- [ ] Reconexión de Adobe Sign con Legal Credit Solutions y verificación (ver PRIORITARIO).
- [ ] `python3 scripts/traspaso/traspaso_usuario.py` (vista previa, con validación check-only) y luego `--apply` con la sesión de Juan. Cubre labels, alertas, dashboards, carpetas y el CC del correo ACH.
- [ ] Recrear con el usuario de Juan los 3 jobs que el script lista (DataExport, job e2cb73ab…, RPT- ACH Payment).
- [ ] Primera corrida diaria con `apply` hecha por Juan; él comitea los índices.
- [ ] Al final, el script en vista previa: no debe quedar nada a nombre de Carlos. Recién entonces, desactivar el usuario.

**Salesforce, antes de soltar el usuario (barrido en MONEE 2026-10-08; tocan producción, confirmar cada uno)**

Crítico (deja de funcionar al desactivar el usuario):
- [ ] **Adobe Acrobat Sign**: ver **PRIORITARIO** al inicio del checklist.
- [ ] **Custom Label `UPGRADED_CONTRACT_TASK_OWNER_USERNAME` = `clopez@legal-credit.com`**: lo usa `SM_TaskHelper.cls` como dueño de las Tasks de error en contratos upgraded. Con el usuario inactivo el insert falla. Cambiar al username de Juan (Setup → Custom Labels, sin deploy).
- [ ] **3 jobs a nombre de Carlos** (los demás ya están bajo Legal Credit Solutions o Juan):
  - `DataExport` (jueves 8:03, WAITING): recrear desde Setup → Data Export con el usuario nuevo.
  - `e2cb73ab-a3eb-0ba3-0621-76eaabaa1167` (tipo A = reporte/dashboard programado, diario 12:00, WAITING): identificarlo en Setup → Tareas programadas y reprogramarlo con el usuario nuevo.
  - `RPT- ACH Payment` (PAUSED): decidir si se borra o se reprograma bajo Legal Credit Solutions.
- [ ] **6 dashboards que corren como Carlos** (usuario de ejecución fijo): `Credit Elevator`, `Campaign, Lead & Activity Data Quality`, `Case & Contract Data Quality`, `Source and Path`, `TC Dahsboard`, `ACH Dahsboard`. Cambiar el "Ver dashboard como" a otro usuario.

Correos:
- [ ] Custom Labels `LCS_Notify_Email_Tecnico` y `LCS_Notify_Email_Comercial`: quitar `clopez@legal-credit.com` (dejar Juan).
- [ ] Alerta de email `SM_Nacha_Alert_Ttransaction_Limit` (`SM_Nacha_File__c`): quitar a Carlos de CC.
- [ ] Alerta del workflow de `SM_Payment__c` (recipient `clopez@legal-credit.com`): cambiar el destinatario.
- [ ] `B. Enviar Correo Reporte ACH.apex`: quitar a Carlos de `CC_REALES` (repo ENTREGA_JUAN).
- [ ] Carpetas `CollectionsFolder` de reportes y dashboards: compartidas con Carlos; agregar a Juan.

Integraciones con tu usuario (avisar a quien las use):
- [ ] **Microsoft Power Query** (228 logins en 60 días): algún Excel/Power BI refresca datos con tu usuario. Identificar cuál y reconectarlo.
- [ ] **Slack** y **XL-Connector 365**: pocos logins; reconectar si se siguen usando.

Registros a nombre de Carlos (no se rompe nada; reasignar solo si alguien los trabaja):
- 34 Contracts, 25 Accounts, 28 Opportunities, 12 Cases, 14 Agreements, 598 Leads (279 No Contact, 167 New, 124 Not Oriented…).

Sin acción:
- `NOTIFY_EMAIL` en las clases de monitoreo: solo se usa en mensajes de debug, no manda correos.
- Scripts de ENTREGA_JUAN: ya no tienen el OwnerId de Carlos fijo (solo `AgreementMaintenance.apex`, que reasigna *desde* Carlos).

**Accesos y acompañamiento**
- [ ] Usuarios de Cybersource (LCS y HARMONEY) y Authorize.net para Juan.
- [ ] Corrida acompañada: diaria completa (preview → apply) y envío ACH (A → B → C).
- [ ] Acordar el día de corte: nunca `apply` desde dos máquinas el mismo día. El archivo ACH del 7-oct todavía no está procesado.

## Caso 06 — lote ADJ_AC_ERR_12AGO: reembolso de $4,382.47 (60 contratos sobrecobrados)

**Estado:** decisión de mecanismo pendiente. Por ahora no se aplica nada.

**Opción elegida como propuesta:** crédito en el próximo ciclo. Reducir `SM_Total__c` de la próxima Subscription en el monto sobrecobrado, con nota `AUTO:` y un Task por contrato. Primero dry-run, después apply.

**Pendientes para retomar:**
- 27 contratos tienen un sobrecobro mayor que su mensualidad. Quedan $1,107.65 que habría que descontar en ciclos siguientes. Falta definir la regla de arrastre.
- 5 contratos no tienen Subscription activa. Falta decidir la vía (devolución directa o aplicar a una LPF).
- No se tocan fechas de Subscription para esto.
- Caso aparte: `00316168` cobró $74 de menos. Decidir si corresponde cobrarle la diferencia.

**Archivos:** `COLLECTIONS/ACH_REPORTADOS/ADJ_AC_ERR_12AGO_Analisis_Pagos_61.csv`, `ADJ_AC_ERR_12AGO_candidatos_refund.csv`, `ADJ_AC_ERR_12AGO_ultimos2cobros.csv`.

## `00316826` — día de pago por fin de semana sin restaurar

**Estado:** por revisar (anotado 2026-10-07).

El contrato tiene `Reasons_for_change__c = 'Date Restored (Weekend)'` desde hace más de 8 días. El utilitario `UTILITARIOS/-LIMPIA_ChangePaymentDay.apex` (en dry-run) le restauraría el día de pago original (30) y limpiaría la marca. Confirmar y correrlo en real, o dejarlo.

## `00317976` — Subscription creada quedó en 14-nov (sábado)

**Estado:** por revisar (anotado 2026-10-07).

El 07-oct se crearon, a pedido de Comercial, las LPF de agosto, septiembre y octubre (ACH-30305, ACH-30306, ACH-30307; $79 sin multa, cobro 07-oct) y la Subscription que faltaba (ACH-30308), con inicio 16-ago y próximo cobro 16-nov. Al insertarla, `SM_ACHOrderHandler` ("suggested business day") recalculó inicio, próximo cobro y fin a **14-nov (sábado)**. Decidir si se corrige a 16-nov a mano. Script: `TEMP/fix_00317976_cuotas_y_subscription_2026-10-07.apex`.

## `00318713` — AC de tarjeta no cobrado y tarjeta que no se ve

**Estado:** por revisar (anotado 2026-10-08).

Pedido de Comercial: "crea facturas de AC / registré TC y no la visualizo 3065 mastercard". El contrato está en `Payment Process` y no tiene pago AC ni ninguna `CB_Transaction__c`: el AC nunca se intentó cobrar. El contrato apunta a `PM-207388`, un Payment Method vacío creado a mano el 25-sep. La tarjeta real es `PM-207529` (Mastercard 3065, sincronizada el 07-oct). La Subscription `AzqQx7VWGU9Sp3wU` (FUTURE, inicio 30-oct) existe y usa la 3065, pero no está enlazada al contrato. Pasos: TAREAS_OCASIONALES 1.1 de ENTREGA_JUAN (enlazar PM y Subscription; confirmar en Chargebee y en el procesador que no hay cargo; Comercial cobra el AC).

## `00318562` — mismo patrón que 00318713

**Estado:** por revisar (anotado 2026-10-08).

Lo encontró la consulta de detección de TAREAS_OCASIONALES 1.1: tarjeta, `Payment Process` desde el 14-sep, sin Subscription enlazada y con el Payment Method `PM-201544` vacío. No revisé el detalle.

## Entrega final — prompt para el bot de Slack (Claude) que arma Juan

**Estado:** para hacer al final, cuando Carlos indique "entrega final" (anotado 2026-10-07).

Diseñar el prompt para que el bot de Slack tome el pedido de un agente tal como lo escribe (ej. "crea facturas SIN FEE de agosto, sept y oct, cobro INMEDIATO <contrato>") y lo resuelva con los scripts de la entrega:
- **El prompt interpreta, los scripts ejecutan:** traduce el vocabulario de los agentes ("facturas" = LPF en ACH / Charge Request en Chargebee; "sin fee" = sin multa; "inmediato" = próximo día hábil; meses = una cuota por mes) y elige el script y sus parámetros (`-COBRO_A_PEDIDO`, `-CREAR_ORDEN_ACH_MANUAL`).
- **Flujo:** pedido en Slack → dry-run → vista previa en el hilo → aprobación de una persona autorizada → aplicar, con marca `AUTO:` "pedido por <agente> vía Slack".
- **Cuándo se detiene a preguntar:** contrato sin Subscription, cuotas que todavía no vencen, fechas que puedan generar cobro doble, contrato VIP/Test o con Customer Cancellation, y cualquier caso que los scripts no cubran.
- **Antes de diseñarlo, saber del bot de Juan:** qué acceso tiene a Salesforce (¿ejecuta Apex anónimo o solo consulta?), con qué usuario escribe en MONEE, y si ya tiene un paso de aprobación en Slack.
- **Prerrequisito propuesto (no aprobado todavía):** agregar a `-CREAR_ORDEN_ACH_MANUAL` los parámetros opcionales `fechaInicio` y `fechaProximoCobro`, para cubrir con un solo script el caso "contrato sin Subscription: cuotas atrasadas o adelantadas" (hoy se resolvió con un script puntual en `TEMP/`).
- El resultado va como documento para Juan, junto con todo lo trabajado en la entrega.
