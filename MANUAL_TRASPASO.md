# Manual de traspaso — SCRIPTS_LCS_2025

> **Para quién es esto:** la persona (técnica — desarrollador/admin Salesforce) que recibe este
> puesto. Es el punto de entrada: te dice qué existe, dónde está, qué corre cada día y qué NO
> tocar sin preguntar antes. No repite el detalle que ya está bien documentado en otro lado — te
> manda al archivo correcto en cada sección.
>
> **Fecha de corte:** 2026-10-02. Todo lo que dice "pendiente" o "en pausa" aquí puede haberse
> resuelto después de esta fecha — cruza siempre contra `TAREAS_PENDIENTES.md` (que si se mantiene
> al día) antes de asumir que algo sigue abierto.

---

## 1. El puesto en una frase

Mantener el pipeline de cobranza bancaria (ACH/cheques) y la cancelación de contratos de
**Legal Credit Solutions** sincronizados entre el banco (Banco Popular), Chargebee, y la org de
Salesforce **MONEE** (producción, sin sandbox propio salvo **PREPROD**) — vía un conjunto de
scripts Python/Apex que se corren manualmente (nunca 100% desatendidos) más un puñado de
automatizaciones nativas de Salesforce (triggers, flows, jobs programados) que sí corren solas.

No es un rol de "soporte Salesforce" general — las decisiones de negocio (a quién cobrarle, si
se condona una deuda, cuándo escalar con el banco) son de **Comercial**. Ver sección 10.

---

## 2. Accesos que necesitas antes de poder trabajar

| Qué | Para qué | Cómo se confirma que funciona |
|---|---|---|
| `sf` CLI autenticado a **MONEE** (`clopez@legal-credit.com`, producción) | Todo: queries, deploys, `apex run` | `sf org list` debe mostrar `MONEE` como `Connected` |
| `sf` CLI autenticado a **PREPROD** (`clopez@legal-credit.com.preprod`, sandbox) | Validar antes de desplegar algo riesgoso; es donde vive la migración de Chargent en curso (sección 7) | `sf org list` → `PREPROD` `Connected` |
| Acceso al repo de GitHub `calopezp/SCRIPTS_LCS_2025`, rama `main` | Todo el código vive aquí — es la fuente de verdad compartida entre las dos máquinas del usuario anterior (ver `CLAUDE.md` intro) | `git remote -v` — confirma el nombre del remoto, **no asumas que es `origin`**, puede ser distinto por máquina |
| Acceso a **OneDrive** con los PDFs/CSV que sube el banco (Check Collection, ACH Returns) y los archivos `ACH_YYYYMMDD*.csv` de transmisión | Sin esto, `COLLECTIONS/build_index.py` y `ACH_REPORTADOS/build_index.py` no tienen qué leer — el pipeline diario no puede correr | Ruta configurada dentro de los scripts (`COLLECTIONS/build_index.py`, revisar constante de ruta) |
| Python 3 instalado, con las dependencias de `COLLECTIONS/` (ver si hay `requirements.txt`, si no, instalar sobre la marcha lo que falte: `pdfplumber`/similar para leer PDFs del banco) | Correr los scripts de `COLLECTIONS/` | `python COLLECTIONS/buscar_payment.py PY-00000000` no debe tronar por import faltante |
| Correo `clopez@legal-credit.com` (o uno nuevo que lo reemplace en `NOTIFY_EMAIL` de cada clase) | Todos los reportes automáticos (return codes, Trigger Panel Monitor, Weekly Digest, etc.) hoy mandan **solo** a esa dirección — hardcodeada en cada clase Apex, ver sección 5.3 | — |
| Credenciales de **Chargebee** (vía Named Credential ya configurada en Setup de MONEE: `Chargebee API`, `harmoneyllc`) | `CancelarContratosRunner.cls` llama la API de Chargebee para void invoices / cancelar subscriptions | No está en el repo (es config de Setup, no metadata) — pedir acceso aparte |
| Conector "Salesforce - Beta" (vía MCP/claude.ai) | **Descartado** — nunca se logró autorizar, no vale la pena perseguirlo. `sf` CLI cubre todo lo necesario de solo-lectura | — |

---

## 3. Mapa del repositorio (dónde está cada cosa)

```
SCRIPTS_LCS_2025/
├── CLAUDE.md                        # Base de conocimiento operativa — reglas de negocio confirmadas,
│                                     # bitácora de decisiones, qué NO tocar. LÉELO COMPLETO antes de
│                                     # tocar nada de Collections/Cancelar Contratos/Chargent.
├── BITACORA_HALLAZGOS_TECNICOS.md   # Tabla acumulativa de bugs reales encontrados (fecha/causa/
│                                     # solución/estado) — útil para no repetir un diagnóstico ya hecho.
├── TAREAS_PENDIENTES.md             # Todo lo que quedó abierto/pausado — LÉELO cada vez que te
│                                     # pregunten "¿qué falta?" en vez de reconstruirlo de cero.
├── .claude/skills/
│   ├── collections/SKILL.md         # Detalle técnico completo del pipeline de cobranza
│   └── cancelar-contratos/SKILL.md  # Detalle técnico completo de la cancelación masiva
├── COLLECTIONS/                     # Pipeline de cobranza — ver sección 4.1
│   ├── COLLECTIONS/                 # Sub-pipeline "Check Collection" (cheques, PDF Banco Popular)
│   ├── RETURNS/                     # Sub-pipeline "ACH Returns" (devoluciones ACH, códigos R01-R16)
│   ├── ACH_REPORTADOS/              # Sub-pipeline "Transmission" (qué se mandó al banco y cuándo)
│   ├── CANCELACIONES/               # Cancelación masiva de contratos — ver sección 4.2
│   ├── UTILITARIOS/                 # Scripts manuales sueltos (timeout de 15 días, fixes puntuales)
│   └── index/                       # CSVs de índice histórico (NO son basura, son el estado persistido)
├── force-app/main/default/          # Metadata de Salesforce (90 clases Apex, 14 triggers, ~27 flows,
│                                     # LWC, custom metadata) — lo que se despliega a MONEE/PREPROD
├── scripts/apex/                    # Scripts de Execute Anonymous puntuales (81 archivos) — backfills,
│                                     # programar jobs (`Schedule_*.apex`), diagnósticos
├── scripts/soql/                    # Queries SOQL guardadas para reutilizar
├── CHARGENT_MIGRACION/              # Exports CSV de la data legacy de Chargent (para la migración
│                                     # en curso, sección 7) — no tocar sin contexto de esa migración
├── TEMP/                            # Exports/reportes puntuales (CSVs ad-hoc, backfills) — SÍ se
│                                     # commitea desde 2026-09-15, no es scratch descartable
└── manifest/, config/, sfdx-project.json   # Config estándar de un proyecto Salesforce DX
```

**No hay sandbox de desarrollo propio** fuera de PREPROD — casi todo el trabajo de diagnóstico se
hace con queries de solo lectura directo contra MONEE (producción) vía `sf data query`. Por eso la
regla de `RunSpecifiedTests` en todo deploy (sección 8) es crítica: no hay red de seguridad de un
sandbox intermedio para un deploy roto.

---

## 4. Operación diaria/semanal (runbook)

### 4.1 Collections / cobranza — **el trabajo de todos los días**

```bash
cd COLLECTIONS
./run_daily_new_files.sh          # sin "apply" = DRY RUN, revisa el preview primero
./run_daily_new_files.sh apply    # aplica: busca archivos nuevos del banco, procesa TODO lo que
                                   # traigan (sin importar la fecha interna de cada fila — Rule 1),
                                   # corre ACH Reportados, marca timeouts de 15 días, manda 6 correos
                                   # de alerta (return codes) a Comercial
```

Detalle completo (estructura, reglas de negocio Rule 1/2/3, por qué existen): **skill `/collections`**
y `CLAUDE.md` sección 2. No reinventar esto — ya está verificado línea por línea contra el código.

Diagnóstico rápido de un payment puntual: `python COLLECTIONS/buscar_payment.py PY-01234567`
(cruza estado en vivo de Salesforce contra los 3 índices históricos).

### 4.2 Cancelar Contratos — recurrente, nunca automático

```bash
cd COLLECTIONS/CANCELACIONES
./run_check_estado.sh                          # recalcula el estado de cada contrato de la lista
cat Contratos_para_Cancelar_ESTADO.csv         # 5 categorías posibles, ver skill
python generate_run_batch.py --limite 50       # arma el bloque Apex para los próximos N
# pegar el bloque en scripts/apex/-CANCELAR_CONTRATOS_FULL.apex, correr con sf apex run,
# SIEMPRE en dry-run primero (el segundo parámetro de CancelarContratosRunner.run())
```

Agregar un contrato nuevo a la cola: una línea en `Contratos_para_Cancelar_LOG.csv`
(`ContractNumber<TAB>fecha<TAB>motivo`). Detalle completo, gotchas de Chargebee (picklist/callout)
y las 5 categorías de estado: **skill `/cancelar-contratos`** y `CLAUDE.md` sección 6.

### 4.3 Reportes/correos automáticos para Comercial (ya desplegados, corren solos)

No requieren que tú hagas nada — están en cron (sección 5.3). Lo único que sí requiere acción
humana: **todos siguen mandando solo a `clopez@legal-credit.com`** porque nunca se definió la
lista real de destinatarios de Comercial (ver `TAREAS_PENDIENTES.md`, varias filas). Si Comercial
pide recibirlos directamente, ahí es donde se actualiza `NOTIFY_EMAIL` en cada clase.

---

## 5. Automatizaciones en Salesforce (MONEE) — qué corre solo, sin que nadie lo dispare

### 5.1 Triggers activos y qué hacen

| Trigger | Objeto | Handler | Qué hace |
|---|---|---|---|
| `SM_PaymentTrigger` | `SM_Payment__c` | `SM_PaymentHandler.cls` | **El motor principal** de todo el pipeline de payments — clona pagos a contratos dependientes, actualiza órdenes ACH relacionadas según el estado del pago. |
| `SM_ACPaymentActivationTrigger` | `SM_Payment__c` (solo `after insert`/`after update`) | `SM_ACPaymentActivationHandler.cls` | Activa contratos ChargeBee/Credit Card/Cash cuando se paga el AC. |
| `SM_LateFeeReconciliationTrigger` | `SM_Payment__c` (solo `after update`) | `SM_LateFeeReconciliationHandler.cls` | Cancela Late Payment Fees huérfanas cuando el pago original resuelve a `COLLECTED`. |
| `SM_ACHOrderTrigger` | `SM_ACH_Order__c` | — | Lógica de órdenes ACH. |
| `SM_ContractTrigger` | `Contract` | `SM_ContractHandler.cls` | **⚠️ Ver sección 7 — migración de Chargent en curso, NO TOCAR.** En MONEE hoy es un no-op vacío. |
| `SM_PaymentTGR` | `SM_Payment__c` | — | **Trampa de nombres** — pasa el nombre equivocado a su handler (`'SM_ChargentTransactionTGR'`), y su registro de Trigger Panel correspondiente a ese nombre está apagado. Reemplazado por el Flow `PAYMENT_Accumulate_AC_On_Contract`. No reactivar sin confirmar. |
| `SM_ChargentOrderTrigger` | `ChargentOrders__ChargentOrder__c` | `SM_ChargentOrderHandler.cls` | Apagado (Trigger Panel en `false` los 7 contextos) — Chargent ya no está activo en MONEE. No reactivar. |
| `SM_AgreementTrigger`, `SM_AttachmentTrigger`, `SM_CompanySettingTrigger`, `SM_OpportunityLineItemTrigger`, `SM_OpportunityTrigger`, `SM_TaskTrigger`, `SM_TrackingInboundTrigger` | varios | varios | Fuera del alcance directo de este puesto (no tocan payments/cobranza/cancelación) — revisar código si hace falta, no documentados aquí a propósito. |

**Antes de tocar cualquier trigger:** revisar `SM_Trigger_Panel__mdt` (Custom Metadata) — un
checkbox apagado ahí no borra el trigger, solo evita que llame al handler en ese contexto.
**Tabla completa de qué está prendido/apagado y por qué, con el "por qué" de cada caso especial
(Chargent, la trampa de `SM_PaymentTGR`): `CLAUDE.md` sección 5.** No es intuitivo — léela antes
de asumir que un trigger apagado es un bug.

### 5.2 Jobs programados (Schedulable / cron) — confirmados en vivo 2026-10-02

| Job (nombre en `CronTrigger`) | Horario | Clase Apex | Qué hace | Estado |
|---|---|---|---|---|
| `SM_TriggerPanelMonitor_Daily` | 8:20 AM España | `SM_TriggerPanelMonitor.cls` | Compara el Trigger Panel contra el baseline esperado (sección 5.1) y avisa por correo si algo cambió | **WAITING** (activo) |
| `SM_AgreementSignedDateMonitor_Daily` | 8:15 AM España | `SM_AgreementSignedDateMonitor.cls` | Detecta `echosign_dev1__SIGN_Agreement__c` con `Status='Signed'` pero sin `DateSigned` (fallo del callback de Adobe Sign) — solo reporta, no corrige | **WAITING** (activo) |
| `SM Contracts Activated Monitor - Daily` | 2:00 PM org (hora que cae a 8:00 AM Puerto Rico en horario de verano España — ver `TAREAS_PENDIENTES.md`, hay que reprogramar quando termine el DST) | `SM_ACH_Flow_Monitor.cls` | Valida que los contratos activados en las últimas 24h tengan su orden AC/Subscription creada correctamente — detecta huecos de automatización nuevos (no los 84 legacy, sección 7) | **WAITING** (activo) |
| `SM_WeeklyComercialDigest_Monday` | Lunes 8:00 AM | `SM_WeeklyComercialDigestScheduler.cls` → `SM_ReturnCodeNotifier.sendWeeklyComercialDigest(false)` | Compilado semanal de los 5 return codes (R02/R04+R13/R07/R10+R11/R16) para Comercial, formato reducido | **WAITING** (activo) |
| `Chargent Recurring Batch` (+ 2 variantes `x`/`_(1)`) | — | paquete Chargent | Jobs del paquete gestionado Chargent | **PAUSED** — migración en curso, sección 7, no reactivar |
| `RPT chargent TC`, `RPT- ACH Payment`, `ACH Payment 14:50 PR.` | — | — | Jobs legacy relacionados a Chargent/reportes viejos | **PAUSED** — no reactivar sin confirmar |

El resto de `CronTrigger` en la org (`Rollup Helper *`, `CommSitemapJob-*`, `Metalytics Data
Loader`, `SRT Semantic Graph`, `DataExport`, `GHL Sync`, `Chargebee_4_4_*`/`Chargebee_8_1_*`,
`Loan_Daily_Balance_*`, `MciDashboardUpdateJobType`, `SyncLogDeletionSchedule`, y varios jobs con
nombre UUID que son Scheduled Paths de Flow) son **jobs de plataforma o de otros paquetes
gestionados** (Chargebee connector, un paquete de Loan Management, herramientas de reporting) —
fuera del alcance de este puesto. Si alguno falla o se necesita entender, es un paquete de
terceros, no código de este repo.

Para reprogramar o crear un job nuevo: `scripts/apex/Schedule_*.apex` tiene el patrón exacto
(`System.schedule(...)`) usado para cada uno de los 4 jobs propios de arriba.

### 5.3 Flows clave (de ~27 totales en el repo)

No se documenta cada uno aquí — usa `force-app/main/default/flows/` y abre el que necesites en
Setup (Flow Builder) para ver el diagrama. Los que sí importan para este puesto:

- **`CONTRACT_Create_ACH_AC_Order`** / **`CONTRACT_Create_ACH_Subscription_Order`** — crean las
  órdenes ACH (AC inicial y recurrente) cuando un contrato pasa a Payment Process/Activated.
- **`PAYMENT_Accumulate_AC_On_Contract`** — reemplazo permanente del trigger legacy
  `SM_PaymentTGR`/Chargent para acumular pagos AC en el contrato.
- **`CONTRACT_05_Before_Save_Orchestrator`** / **`CONTRACT_10_After_Save_Orchestrator`** —
  orquestadores principales del ciclo de vida de `Contract` (llaman a varios de los flows de
  arriba y a `SM_ContractHandler` — ver sección 7 para la parte rota/en migración).
- **`ACH_ORDER_Subscription_Stopped_Monitoring`** (desplegado y activado 2026-10-05) — cuando
  **cualquier usuario** pasa una `SM_ACH_Order__c` tipo `Subscription` a `Stopped` (solo en el
  *cambio* a ese estado): (1) si el contrato no está en monitoreo (casilla apagada o sin
  responsable), marca `SM_ContractMonitoring__c = true`, asigna `Contract_Monitoring_By__c` = el
  usuario que detuvo la orden y deja la marca `AUTO: ...` en `SM_Id_Salesforce_LCS__c`; si ya tenía
  monitoreo con responsable, **lo respeta**; (2) **siempre** crea una Task `Open` sobre el contrato
  (Subject `Collections-Subscription Stopped`, a nombre del usuario, como nota histórica — hoy no se
  gestionan los estados de las Tasks). Si la actualización del contrato falla (validation rule
  sobre datos viejos), no bloquea el Stopped del agente: la Task se crea igual con el texto
  `ERROR: no se pudo activar Contract Monitoring...` para revisarlo a mano. **Desmarcar el
  monitoreo es manual** (lo hace el agente). Ojo: corre también cuando tú/tus scripts por `sf` CLI
  detienen Subscriptions (por trazabilidad, a propósito — decisión del usuario).
- **`COLLECTIONS_*`** (4 flows) — sincronizan `SM_Payment__c`/Bills con el estado de cobranza.
- **`ChargentOrderPB`** / lo relacionado a Chargent dentro de `ContractPaymentActions` — **en
  pausa por la migración, no tocar** (sección 7).

Toda automatización **nueva** que toque `SM_Payment__c`, `SM_ACH_Order__c` o `Contract` debe dejar
una marca `"AUTO: <Proceso> - <qué hizo> - <fecha>"` en `SM_Id_Salesforce_LCS__c` (campo
"ANOTACIONES") — ver `CLAUDE.md` sección 1 para el porqué (todo corre bajo el mismo usuario
técnico, sin esto es imposible distinguir después qué tocó un registro) y el helper
`SM_AutomationLogHelper.appendNote(...)`.

---

## 6. Reglas de negocio que no son obvias desde el código — resumen ejecutivo

Esto es un resumen de referencia rápida. **La versión completa, con el caso real que la originó y
la fecha de confirmación, está en `CLAUDE.md` sección 2.2** — no tomes decisiones solo con este
resumen si el caso es ambiguo, ve a la fuente.

1. **Procesar todo lo que trae un archivo del banco que se está trabajando, sin importar la fecha
   interna de cada fila** (Rule 1) — pero **nunca tocar histórico de más de 2 meses sin
   confirmación explícita** (Rule 2).
2. **`PENDING`/`RETURN` con más de 26 días desde la transmisión → `NOT_COLLECTED`** (Rule 3), salvo
   un código de retorno "definitivo" (R02/R04/R07/R10/R13/R16) que lo puede saltar — pero solo en
   limpiezas puntuales pedidas explícitamente, nunca por defecto.
3. **R10 siempre gana** — puede revertir incluso un `ACCEPTED`/`COLLECTED` ya resuelto (es un
   contracargo/disputa posterior, no un error de reporte). Los otros 5 códigos definitivos NO
   heredan esta prioridad.
4. **La fuente de verdad del estado real de un payment es siempre el reporte del banco** (el
   índice local o el PDF), **nunca `SM_Payment__History`** — el historial de Salesforce sirve para
   diagnosticar qué hizo la automatización, no para decidir qué pasó de verdad.
5. **Una orden ACH activa en un contrato que se va a cancelar se detiene (`Stopped`), no se
   cancela (`Canceled`)** — el estado final `Canceled` solo lo aplica `CancelarContratosRunner`
   cuando el contrato realmente termina de cancelarse.
6. **84 contratos ACH legacy (2019-2025) sin orden AC son un asunto de migración conocido — no
   investigar/backfillear proactivamente.** Contratos nuevos con el mismo síntoma sí son un bug real.
7. **Todo deploy de Apex a MONEE/PREPROD usa `RunSpecifiedTests` con `--tests` explícito, nunca
   `RunLocalTests`** — MONEE tiene ~31 tests rotos org-wide sin relación con lo que despliegues.

---

## 7. Qué NO tocar sin confirmar primero (trabajo en curso de otra persona)

**Migración de Chargent — `SM_ContractHandler`, `SM_ContractHandlerTest`, y lo relacionado
(`SM_ChargentOrderTrigger`, `SM_PaymentTGR`, `ChargentOrderPB`, jobs `Chargent Recurring Batch*`,
`CHARGENT_MIGRACION/`).** Producción (MONEE) tiene hoy una versión *vacía* (no-op) de
`SM_ContractHandler` — la versión real con la lógica completa solo existe en **PREPROD**. Esto es
deliberado: el dueño anterior del puesto lo está validando y sincronizará manualmente
MONEE/PREPROD/repo cuando esté listo. **Si necesitas tocar algo de Contract/Chargent, pregunta
primero** — no asumas que el repo o MONEE tienen la versión "correcta". Detalle técnico completo
con el diff real entre orgs: `CLAUDE.md` sección 3.

Cualquier otra fila marcada "esperando decisión de Comercial" o "no tocar" en
`TAREAS_PENDIENTES.md` aplica igual — es la lista viva de qué está pausado y por qué.

---

## 8. Reglas de trabajo (git, deploys) — resumen

Las reglas completas están en `CLAUDE.md` sección 1. Las más importantes para no romper nada el
primer día:

- `git pull <remoto> main` antes de empezar en cualquier máquina — confirma el nombre del remoto
  con `git remote -v` primero.
- Nunca `git add -A` — agregar archivos específicos por nombre.
- Commits locales para preservar historial; push a GitHub solo cuando se confirme explícitamente.
- Todo deploy a MONEE/PREPROD: `--test-level RunSpecifiedTests --tests <ClasesRelevantes>` — nunca
  el default.
- `TEMP/` es para exports/reportes puntuales que sí se commitean (desde 2026-09-15) — no un
  scratchpad descartable.

---

## 9. Mapa de toda la documentación existente

| Documento | Para qué sirve | Cuándo consultarlo |
|---|---|---|
| **Este archivo** (`MANUAL_TRASPASO.md`) | Orientación general, runbook, qué no tocar | Primer día, y cada vez que no recuerdes dónde vive algo |
| `CLAUDE.md` | Reglas de negocio confirmadas, con el caso real y la fecha que las originó; es la fuente de verdad operativa | Antes de tomar cualquier decisión sobre Collections/Cancelar Contratos/Chargent/Winter '27/Trigger Panel |
| `.claude/skills/collections/SKILL.md` | Detalle técnico línea-por-línea del pipeline de cobranza | Al tocar cualquier archivo bajo `COLLECTIONS/` |
| `.claude/skills/cancelar-contratos/SKILL.md` | Detalle técnico línea-por-línea de la cancelación masiva | Al tocar cualquier archivo bajo `COLLECTIONS/CANCELACIONES/` |
| `BITACORA_HALLAZGOS_TECNICOS.md` | Bugs reales ya diagnosticados (fecha/causa/consecuencia/solución/estado) | Antes de investigar algo que "se siente raro" — puede que ya esté resuelto o documentado |
| `TAREAS_PENDIENTES.md` | Todo lo abierto/pausado, con contexto para retomarlo sin releer la conversación original | Cuando te pregunten "¿qué falta?" o antes de cerrar algo que podría estar bloqueado por otra razón |

---

## 10. Alcance: qué es trabajo técnico vs. de Comercial

**Cobranza y seguimiento de cliente (llamar, negociar, decidir si se cancela por falta de pago) es
responsabilidad de Comercial, no de este puesto.** El trabajo técnico es: que los 3 sub-pipelines
de Collections reflejen correctamente lo que dice el banco, que los 6 correos de alerta
(return codes) salgan a tiempo, y que `CancelarContratosRunner` ejecute limpio cuando Comercial (o
el propio proceso de Collections) determina que un contrato debe cancelarse. Si una validación
técnica encuentra un contrato con un patrón de pago sospechoso, el entregable es **reportarlo con
los datos** (como se hizo repetidamente en `TAREAS_PENDIENTES.md`/`BITACORA_HALLAZGOS_TECNICOS.md`)
— no perseguir el caso ni decidir la acción de cobranza.

---

## 11. Snapshot de pendientes abiertos al momento del traspaso (2026-10-02)

Lista resumida — **la tabla completa y actualizada vive en `TAREAS_PENDIENTES.md`**, no la
dupliques de memoria:

- Proceso de contracargos R10/R11 — **piloto 2026 completo** (45 payments: Payment ACCEPTED/
  COLLECTED + Payment REFUNDED + flag `Historical_Claim_On_Record__c`/`Has_Refund_History__c` +
  Task `'TIADM - REFUND CONTRA CARGO (R10/R11)'`, ver `scripts/apex/-CONTRACARGO_ACH_R10_R11*.apex`).
  **El resto del backlog histórico (pagos de antes de enero 2026, ~300 payments) queda
  deliberadamente sin tocar y FUERA de este traspaso — decisión explícita de Carlos (2026-10-06):
  no se entrega a Juan; queda retenido por Carlos hasta evaluarlo con Comercial.** Razón: esos payments se procesaron antes de que
  existiera la regla de contracargo, con la lógica vieja (`NOT_COLLECTED`); aplicarles la regla
  nueva ahora los pasaría a `ACCEPTED`/`COLLECTED`, lo que haría que esos contratos **pasen a deber
  las cuotas siguientes** — un impacto financiero real sobre contratos ya resueltos de otra forma.
  **No es una decisión técnica — requiere evaluarlo con Comercial primero** (¿se reclasifican bajo
  la regla nueva, o se dejan tal como quedaron?). Si se decide retomarlo, los 3 scripts del piloto
  (`_BATCH_CANCELLED_2026`, `_BATCH_PAYMENTPROCESS_2026`, `_BATCH_ACTIVATED_2026`) son la plantilla
  a reutilizar.
- 539 payments 2026 sin decisión final en algunos tiers ambiguos (ver detalle en el archivo).
- Lista real de destinatarios de Comercial para los correos automáticos — pendiente que la
  definan (hoy todo llega solo a `clopez@legal-credit.com`).
- Horario del job `SM Contracts Activated Monitor - Daily` — reprogramar cuando España salga de
  horario de verano (~fin de octubre 2026).
- ~~Winter '27 (aplica a MONEE el 10-oct-2026) — falta correr el Test Run de "Enable Profile
  Filtering"~~ **Cerrado 2026-10-05.** Validado con login-as un usuario no-admin (Sales Agent) en
  PREPROD (que ya tiene el release adelantado) usando la extensión Chrome "Salesforce Inspector":
  una query de perfil ajeno (`'Standard User'`) devolvió 0 registros (bloqueada, confirma que el
  filtro ya está activo), una del propio perfil (`'Sales Agent'`) devolvió 1 (exento por diseño,
  como documenta Salesforce). Como `clopez@legal-credit.com` sigue con los 4 permisos bypass
  intactos, el enforcement no afecta los deploys reales en MONEE — sin acción pendiente. Detalle en
  `TAREAS_PENDIENTES.md` (Cerrado recientemente) y `CLAUDE.md` sección 4.
- Varios casos de doble cobro / reembolso pendientes de decisión de negocio (`00317786`,
  contratos del caso 06, etc.).
- 1 contrato (`00317915`) en cola de cancelación esperando el plazo normal de la Rule 3.

---

## 12. A quién preguntar

- **Decisiones de negocio / cobranza / cancelación**: Comercial.
- **Dueño anterior del puesto** (sincronización de la migración de Chargent, contexto histórico de
  decisiones ya tomadas): Carlos López (`clopez@legal-credit.com`).
- **Acceso a Chargebee, OneDrive, correo de notificaciones**: pedir credenciales/alta como usuario
  nuevo — no están documentadas en este repo por diseño (son config de Setup/cuentas externas, no
  metadata versionable).
