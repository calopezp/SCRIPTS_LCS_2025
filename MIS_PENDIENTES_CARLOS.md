# Mis pendientes — Carlos (no forma parte de la entrega a Juan)

## Checklist para cerrar la entrega a Juan

**Estado:** en curso (anotado 2026-10-08).

**Repositorios y archivos**
- [ ] Push de ENTREGA_JUAN (desde la sesión de ENTREGA_JUAN): `git push origin main`.
- [ ] Push de SCRIPTS_LCS_2025: `git push origin main`.
- [ ] Acceso de escritura para Juan en `LegalCredit/legal-credit-carlos-tools` (GitHub → Settings → Collaborators).
- [ ] Exportar a PDF desde Word `2026-10-05 Entrega de Puesto Carlos Lopez.docx`, reemplazar el PDF (está desactualizado), commit y push. Si se exporta después del zip, regenerar el zip.
- [ ] Respaldo `C:\SALESFORCE\LCS\ENTREGA_JUAN_respaldo_2026-10-08.zip` subido a OneDrive: https://legalcredit-my.sharepoint.com/:f:/g/personal/clopez_legal-credit_com/IgBCTioAmX-hQK4nrRjYBu9lAQhTNquAumK8XamRGbpFGZ4?e=TCvexl
- [ ] **Pasarle a Juan el respaldo** (OneDrive no transfiere propiedad entre personas: Juan hace su copia):
  1. Restringir el enlace: OneDrive web, sobre la carpeta → **Compartir** → **Configuración de vínculo** → **"Personas específicas"** → `jduarte@legal-credit.com`, **"Puede editar"**. No "Cualquier persona con el vínculo" (el zip trae cuentas bancarias).
  2. Juan copia: **Mi OneDrive → Compartido** → selecciona la carpeta → **Copiar en** → **Mis archivos**.
  3. Juan confirma que el zip está en su OneDrive, que abre, y manda su enlace nuevo.
  4. Opcional, por TI: al desactivar la cuenta, "Conceder a otro usuario acceso a los archivos de OneDrive" → Juan. Red de seguridad, no plan principal.
- [ ] **`COMPILADO COLLECTIONS`** (también en el OneDrive de Carlos): **Mover a** un SharePoint/Teams de la empresa y que Juan la sincronice con el mismo nombre en la raíz de su OneDrive.

**Salesforce, antes de soltar el usuario (tocan producción)**
- [ ] Reprogramar con el usuario nuevo los jobs a nombre de Carlos: los de `scripts/apex/Schedule_Jobs_LegalCreditSolutions_PR.apex`, `SM_WeeklyComercialDigest_Monday`, `DataExport` (recrear en Setup → Data Export, 07:00 PR).
- [ ] Jobs dudosos: confirmar propósito de `ACH Payment 14:50 PR.` (no pausar sin saber), identificar el job GUID (diario 12:00), reprogramar `RPT- ACH Payment` después.
- [ ] Custom Labels `LCS_Notify_Email_Tecnico` y `LCS_Notify_Email_Comercial`: quitar `clopez@legal-credit.com`.
- [ ] `B. Enviar Correo Reporte ACH.apex`: quitar a Carlos de `CC_REALES`.
- [ ] Alerta de email del workflow de `SM_Payment__c` y carpetas `CollectionsFolder` de reportes/dashboards.
- [ ] OwnerId fijo `0051U000007bbx5QAA` en scripts → usuario nuevo (lista en `TRASPASO_JOBS_CARLOS.txt` 2.1).

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
