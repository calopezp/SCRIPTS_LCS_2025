# Base de conocimiento — SCRIPTS_LCS_2025

## Cómo usar este archivo

Este archivo es la **fuente de verdad compartida entre las dos máquinas** del usuario (calopezp) — viaja con el repo (`git push`/`pull` vía GitHub, `https://github.com/calopezp/SCRIPTS_LCS_2025.git`, rama `main`). A diferencia de esto, la memoria local de Claude Code (`~/.claude/projects/.../memory/`) vive por separado en cada máquina y **no** se sincroniza — si algo debe estar disponible sin importar en qué máquina se abra una sesión nueva, tiene que quedar escrito aquí (o en un Skill dentro de `.claude/skills/`, que también viaja con el repo).

**Máquinas:**
- **ANTIGUA** — `C:\SALESFORCE\LCS\SCRIPTS_LCS_2025\` (usuario Windows: Carlos Lopez New) — remoto
  configurado como **`SCRIPTS_LCS_2025`**, no `origin`.
- **NUEVA** — `C:\LCS 2026\SCRIPTS_LCS_2025\` (usuario Windows: Gatito) — el nombre del remoto es
  config local de git y puede ser distinto al de ANTIGUA; confirmar con `git remote -v` antes de
  asumir el nombre.

**Índice:**
1. [Reglas de trabajo permanentes](#1-reglas-de-trabajo-permanentes) — git, sincronización
2. [Collections / Cobranza](#2-collections--cobranza) — comandos diarios, reglas explícitas del usuario
3. [Chargent — migración en curso (NO TOCAR)](#3-chargent--migración-en-curso-no-tocar)
4. [Winter '27 Release Readiness](#4-winter-27-release-readiness--análisis-puntual-2026-09-06) (análisis puntual, revisar después del 10-oct-2026)

---

## 1. Reglas de trabajo permanentes

- Hacer commits locales para preservar historial de versiones; el push a GitHub no es automático — se hace solo cuando el usuario lo pide explícitamente.
- Nunca usar `git add -A`. Agregar archivos específicos por nombre al hacer stage.
- Antes de empezar a trabajar en cualquiera de las dos máquinas: `git pull <remoto> main` (revisar
  el nombre del remoto con `git remote -v` primero — no asumir que es `origin`).
- Al terminar una sesión de trabajo: commit (y push si el usuario lo confirma) para que la otra máquina pueda traer los cambios.

---

## 2. Collections / Cobranza

Pipeline de cobranza bancaria (ACH Returns, Check Collection, ACH Reportados/Transmission) bajo `COLLECTIONS/`. Para el detalle técnico completo (estructura de archivos, columnas de CSV, reglas de negocio en los `.apex`, clases Apex relacionadas) usar el **Skill `/collections`** (`.claude/skills/collections/SKILL.md`) — se carga automáticamente al preguntar sobre payments, reportes de banco, o al validar archivos de `COLLECTIONS/`. Esta sección solo cubre los comandos operativos diarios y las reglas de negocio explícitas del usuario que no deben perderse entre sesiones/máquinas.

### 2.1 Comandos diarios

```bash
cd COLLECTIONS
./run_daily_new_files.sh apply        # uso DIARIO normal
```

Este es **el comando de uso diario** (requerimiento explícito del usuario, 2026-09-09) — hace las 3 cosas en un solo paso: busca archivos de RETURN/COLLECTION nunca antes indexados, procesa TODOS los payments de esos archivos (sin importar la fecha interna de cada fila — Rule 1, ver 2.2), y corre ACH Reportados al final. Antes de `apply`, correrlo sin argumento (`./run_daily_new_files.sh`) para ver el preview en DRY RUN.

```bash
cd COLLECTIONS
./run_daily_catchup.sh apply                 # reprocesa historico YA indexado, ultimos 2 meses
CONFIRM_OLD=1 ./run_daily_catchup.sh apply    # + fechas de mas de 2 meses (backlog historico real)
```

Este es **distinto** — es para cuando hay que reprocesar a propósito un rango de fechas del histórico *ya indexado* (ej. algo se saltó, o el guard de regresión bloqueó algo que ya se revisó manualmente). Por defecto solo aplica fechas de los últimos 2 meses (Rule 2, ver 2.2); las más viejas se listan pero no se aplican salvo `CONFIRM_OLD=1`.

`run_all_imports.sh` quedó **reemplazado** por estos dos — no usarlo más.

### 2.2 Dos reglas explícitas del usuario (2026-09-09) — no revertir sin su confirmación

**Rule 1 — procesar todo lo que traiga un archivo que se está trabajando, sin importar su fecha interna.** El campo `SM_Check_Collection_Date__c` (fecha del cheque/transacción) suele ser mucho más viejo que la fecha en que el banco realmente publicó el reporte que lo contiene — el atraso de Banco Popular es variable, no un fijo de 2-3 días. Cualquier payment que aparezca en un archivo de RETURN o COLLECTION que se esté procesando se debe aplicar, sin importar qué tan vieja sea esa fecha interna.

**Rule 2 — nunca tocar payments reportados hace más de 2 meses sin confirmación directa del usuario.** Reprocesar histórico genuinamente viejo (que no es "el archivo que se está trabajando" hoy) es una acción deliberada aparte que necesita autorización explícita cada vez, no un default silencioso.

**Por qué existen ambas, en orden — caso real 2026-09-09:**
1. `run_daily_catchup.sh` (entonces con `--days-back 7` por defecto) descartó en silencio 15 de 28 payments de un solo reporte de Check Collection del 4-sep porque sus fechas internas tenían 8-35 días de atraso — incluyendo `PY-01890575`, atascado en `REJECTED/PENDING` mientras el banco ya decía `ACCEPTED/COLLECTED`. Se corrigió quitando el corte de recencia (nace la Rule 1).
2. Sobre-corrigiendo ese fix, una corrida sin acotar recorrió **todo** el índice histórico hasta 2025-08-27 (245 fechas) — el usuario reaccionó con alarma ("PORQUE ESTAMOS MODIFICANDO DATOS DE 2025??"). Auditado por completo: cero regresiones reales, pero ~99% de lo tocado tenía más de 2 meses y nunca se autorizó explícitamente ese alcance. Nace la Rule 2 en respuesta directa a esto.

**Implementado (commits `1d4c940`, `461dc21`, `de72acd`):**
- `build_pending_deltas.py` (usado también por el flujo estándar diario, no solo por el catch-up) fuerza-incluye los payments de `*_last_run_delta.csv` (archivos nuevos de hoy) sin importar la ventana `--days-back` — Rule 1 para el camino diario normal.
- `run_daily_catchup.sh` lista TODAS las fechas pendientes sin corte (Rule 1), pero en modo `apply` separa recientes (≤2 meses, se aplican solo) de viejas (>2 meses, se listan con aviso pero se saltan salvo `CONFIRM_OLD=1`) — Rule 2. El modo DRY RUN sigue mostrando todo libremente porque no escribe nada.
- `run_daily_new_files.sh` es el comando nuevo de uso diario que junta los 3 pipelines en un solo paso, con su propio corte de "archivo nunca visto pero de más de 7 días en disco" (reportado en `index/archivos_viejos_pendientes_confirmacion.csv`, para procesarlo hay que indicarlo explícitamente con el modo de un solo archivo).

**Cómo aplicar esto a futuro:** cualquier cambio a estos scripts (o uno nuevo que cubra lo mismo) debe preservar ambas reglas juntas — no volver a un corte de recencia silencioso (viola Rule 1), y no quitar el gate de confirmación de datos viejos ni aplicarlo al preview de dry-run (sería sobre-restrictivo) ni auto-confirmarlo (viola Rule 2). Si se pide correr un catch-up real de más de 2 meses atrás, pedir confirmación explícita del usuario antes de poner `CONFIRM_OLD=1` — no inferirlo de un lenguaje tipo "procesa todo", que fue exactamente el error que disparó la Rule 2.

### 2.3 Asunto de migración conocido — no investigar salvo que se pida

**84 contratos ACH legacy (2019-2025) sin `SM_ACH_Order__c` tipo AC.** Encontrado 2026-09-09 al diagnosticar/backfillear un bug real (`CONTRACT_10_After_Save_Orchestrator` v5 atascado en Draft desde 2026-08-26, por lo que la orden AC nunca se creó para contratos ACH llegando a Payment Process/Activated). Después de corregir ese hueco real (8 órdenes AC + 25 Subscription creadas), una query sin acotar mostró que estos ~84 contratos más viejos (`ContractNumber` aprox. 00241xxx-00316xxx, `CreatedDate` 2019-02-27 a 2025-12-24) tampoco tienen ninguna orden AC. El usuario confirmó que es un asunto de migración separado y preexistente, no relacionado con el bug — **no tocar/backfillear proactivamente**, solo si se pide explícitamente. Si una validación futura (`Contract` WHERE `SM_Payment_methods__c='ACH'` AND `Status IN ('Payment Process','Activated')` AND sin orden AC) vuelve a mostrar esta misma cola de 84, es esperado. Contratos **nuevos** (`CreatedDate` reciente) que aparezcan en esa misma query sí son un caso distinto y deben investigarse normalmente.

---

## 3. Chargent — migración en curso (NO TOCAR)

Hay 2 orgs conectadas por `sf` CLI: **MONEE** (producción) y **PREPROD** (sandbox, alias `clopez@legal-credit.com.preprod`). Durante el análisis de Winter '27 (2026-09-06) se comparó el `Body` real (Tooling API, `SELECT Body FROM ApexClass`) de 4 clases entre ambos orgs y el repo local, por una falla inesperada al correr `SM_ContractHandlerTest` en MONEE. Resultado:

| Clase | MONEE (producción) | PREPROD (sandbox) | Repo local |
|---|---|---|---|
| **`SM_ContractHandler`** | 2026-07-09, Juan Duarte — **cuerpo vacío**, los 12 métodos (`beforeUpdate`, `afterUpdate`, `processAssetsByContractStatusChange`, `checkUpdateMasterStatus`, etc.) son no-op `{}`, incluye un `testGarbage()` | 2026-07-09, Carlos Lopez — **62 KB, lógica completa real** (incluye `hasChargentObjectAccess()`) | idéntico byte a byte a MONEE (la cáscara vacía) |
| **`SM_ContractHandlerTest`** | **2022-08-27** (Legal Credit Solutions) — versión pre-cancelación de Chargent, usa `ChargentOrders__ChargentOrder__c`/`getChargentorder()`, no asigna `SM_Bank__c` → falla PM003 al correrla | 2026-07-09, Carlos Lopez — versión actualizada, ya asigna Banco a los Payment Methods ACH | idéntico byte a byte a PREPROD (ya tiene el fix) |
| `SM_ContractHelper` | 2022-11-13 (igual en ambos orgs) | 2022-11-13 (igual) | idéntico a ambos — sin divergencia |
| `SM_TestSmartDataFactory` | 2022-11-13 (igual en ambos orgs) | 2022-11-13 (igual) | idéntico a ambos — sin divergencia |

**Implicación:** ahora mismo en producción, toda la lógica del trigger de Contract (activación de assets, status maestro/dependiente, condiciones de pago) corre como no-op porque `SM_ContractHandler` está vaciado — el reemplazo real solo existe en PREPROD. El repo local heredó la cáscara vacía de MONEE para `SM_ContractHandler`, pero la versión corregida de `SM_ContractHandlerTest` desde PREPROD.

**Instrucción explícita del usuario (2026-09-06): no modificar ni desplegar estas clases (`SM_ContractHandler`, `SM_ContractHandlerTest`, ni las relacionadas con la migración de Chargent) — es un trabajo en curso que el propio usuario está validando y sincronizará manualmente entre MONEE/PREPROD/repo cuando esté listo.** Si aparece una sesión nueva y se necesita tocar algo relacionado con Contract/Chargent, preguntar primero — no asumir que el repo o MONEE tienen la versión "correcta".

---

## 4. Winter '27 Release Readiness — análisis puntual 2026-09-06

> **Nota de vigencia:** este es un análisis fechado, no una regla permanente. Winter '27 se aplica a MONEE el **10-oct-2026**. Después de esa fecha, revisar si sigue siendo relevante o si conviene archivarlo/resumirlo.

Contexto: se pidió analizar el impacto de la actualización Winter '27 de Salesforce sobre la org de producción MONEE, ya que se trabaja directo en producción sin sandbox propio.

**Fecha de actualización confirmada (Trust Status API):** org `00D1U000000sQGE`, instancia **USA588** → Winter '27 el **10 de octubre de 2026**, ventana 05:30–06:00 UTC (Hyperforce Core; el resto de Industry Clouds hasta el 12 oct).

**El único enforcement de Winter '27 que cambia acceso a datos: "Enable Profile Filtering".** Confirmado por búsqueda web (release notes oficiales + softwareinsights.dev): disponible opt-in desde Summer '26, se **impone automáticamente en Winter '27**. Un usuario sin uno de 8 permisos "bypass" (View All Profiles, Customize Application, Manage Users, entre otros) deja de poder ver `Profile.Name` de un perfil que no sea el suyo — la consulta simplemente no devuelve esa fila/campo (falla silenciosamente en lógica de negocio, o lanza `List has no rows` si el código asume que la fila existe). Leer el propio perfil (`UserInfo.getProfileId()`, o el merge field `$Profile` en fórmulas/validation rules) siempre es seguro, sea cual sea el permiso.

Búsqueda en todo `force-app/main/default` de patrones `FROM Profile`, `Profile.Name`, `$Profile.Name`:
- **Riesgo real — impacta corridas de test / deploys:**
  - `SM_TestSmartDataFactory.cls:21` — `public static Profile profileObj = [SELECT Id FROM Profile WHERE Name='Standard User'];`. Es un campo estático, se ejecuta en cuanto cualquier test referencia la clase. **15 clases de test la usan** (`SM_UtilsTest`, `SM_PaymentHandlerTest`, `SM_ContractHandlerTest`, etc. — ver `grep SM_TestSmartDataFactory`). Si esta query devolviera 0 filas para el usuario que corre los tests, **todos los deploys a producción se bloquearían** (Salesforce exige que pasen los tests locales).
  - `SM_ContractHandlerTest.cls:294,373` — mismo patrón, `[SELECT Id FROM Profile WHERE Name =: 'Sales Agent']`.
  - **Verificado en la org real (`sf data query -o MONEE`):** el usuario que hace los deploys, `clopez@legal-credit.com`, tiene perfil **System Administrator** con `PermissionsCustomizeApplication = true` y `PermissionsManageUsers = true` — dos de los 8 permisos bypass. Esto significa que, corriendo como este usuario, los tests **no deberían romperse**. Los perfiles `Sales Agent` y `Standard User` referenciados en los tests siguen existiendo en la org (confirmado por query).
  - Pendiente igual: probar esto en el **Sandbox Preview** haciendo *login-as* como un usuario NO-admin (no basta con probar como admin — el admin tiene los permisos bypass y el problema no se manifiesta). Softwareinsights.dev insiste en esto explícitamente.
- **Sin riesgo (confirmado por patrón, no requiere prueba adicional):**
  - `SM_CustomerCancellationActionController.cls:140` — `[SELECT Name FROM Profile WHERE Id = :UserInfo.getProfileId()]`: lee el propio perfil, exento por diseño.
  - 4 validation rules en `Contract` y `SM_Payment_Method__c` que usan `$Profile.Name` / `$Profile <> "System Administrator"`: el merge field `$Profile` siempre refleja el perfil propio del usuario corriendo la operación, no el de otro registro/usuario. Mismo patrón exento.
  - Ningún Flow referencia `Profile` (`grep` sobre los 27 flows: 0 resultados).

**API version 37.0 en `SM_ContractHelper.cls` — reclasificado, NO es un riesgo de Winter '27:**
- `createRequestCongaAPI()` (línea ~131) construye `'/services/Soap/u/37.0/' + UserInfo.getOrganizationId()` como server URL de la Partner API para el callback de Conga Composer — no es una llamada `login()`, así que el retiro de `login()` (Summer '27) no le aplica directamente.
- Fuente real (help.salesforce.com / apexhours.com): las versiones 31.0–40.0 (incluye 37.0) entran en **deprecation en Summer '27** (sin nuevos fixes/seguridad) y **retiro total el 1-jun-2028** (ahí sí dejan de funcionar todas las operaciones, no solo login). O sea: no hay riesgo para el rollout de Winter '27 (10-oct-2026), pero sí una fecha dura real 18 meses después.
- Sigue siendo recomendable el fix de una línea `37.0` → `64.0` (coincide con `sourceApiVersion` de `sfdx-project.json`) simplemente porque no cuesta nada y quita el ítem del radar para 2027-2028. Análisis previo sin terminar: `REPORTE_SOAP_API_USAGE.md` (7 mayo 2026), `scripts/apex/Analizar_SOAP_API_Usage.apex`, `scripts/soql/SOAP_API_Analysis.soql` — creadas pero nunca ejecutadas contra la org real.

**Descartado (revisado directamente en el código, sin riesgo):**
- Retiro del flujo OAuth Username-Password (ahora pospuesto por Salesforce al 20-feb-2027 de todas formas): todos los scripts de integración (`COLLECTIONS/`, `ACH_REPORTADOS/`, `RETURNS/`) se conectan vía Salesforce CLI (`sf apex run -o MONEE`, `sf org display`), no con usuario/contraseña. Sin impacto.
- Fin de URLs de instancia clásicas (`usa588.salesforce.com`) — este cambio en particular ("Update Instanced URLs in API Traffic") se movió a Spring '27 según release notes: el único script con llamadas REST directas, `COLLECTIONS/ACH_REPORTADOS/fetch_salesforce_files.py`, obtiene `instanceUrl` dinámicamente de `sf org display --json`, no lo tiene hardcodeado de todas formas. Sin impacto.

**Menor (housekeeping, no urgente):**
- `fetch_salesforce_files.py` usa `API_VERSION = "v60.0"` (Spring '24); el resto del proyecto ya usa v64.0 (la org corre v67.0 actualmente). Conviene alinear.
- Los dos LWC `validarTarjetaCredito` y `sM_CustomerCancellationLWC` declaran `apiVersion 60.0` en su `js-meta.xml`; sin urgencia, mismo criterio de alineación.

**Confirmado directamente en Setup → Release Updates de MONEE (screenshots del usuario, 2026-09-06):**

Tab **NEEDS ACTION** (23 updates) y tab **OVERDUE** revisados contra el código del repo:

| Update | Estado en MONEE | Relevancia para este repo |
|---|---|---|
| **Enable Profile Filtering** | **OVERDUE** — 0 de 3 pasos, vencido desde 1-sep-2026, se fuerza igual en Winter '27 (10-oct-2026) | **El más relevante.** Ver detalle arriba: `SM_TestSmartDataFactory.cls:21` (15 test classes) y `SM_ContractHandlerTest.cls:294,373`. El usuario que despliega (`clopez@legal-credit.com`) ya tiene permisos bypass, pero falta probar con "Get Started" (tiene TEST RUN SUPPORTED) o *login-as* no-admin antes del 10-oct. |
| **Update Instanced URLs in API Traffic** | OVERDUE, Enforcement Scheduled: **Winter '27** (la org lo tiene calendarizado para Winter '27, no Spring '27 como sugerían artículos genéricos — el Setup de la org manda) | **CERRADO — validado con datos reales, no solo código.** Ver detalle completo abajo. |
| **Adopt Authorized Email Domains** | OVERDUE, Winter '27 | Ningún script/Apex de este repo actualiza `User.Email` en masa (`grep` sin resultados). Riesgo solo si en el pasado se le pidió a Salesforce Support desactivar la verificación de cambio de email para MONEE — eso no es visible desde el código, hay que confirmarlo con el usuario/soporte. |
| **Enable Accessibility Enhancements** (Cards/Paneles, Date pickers/Popovers, Page headers/Modals, To Do Lists) — 4 updates | OVERDUE/NEEDS ACTION, Winter '27, TEST RUN SUPPORTED | Comportamiento estándar de Lightning Experience (zoom/WCAG), no hay componentes Aura en este repo (`grep` de carpeta `aura` = 0 resultados) y los LWC custom no tocan estos patrones. Sin acción de código; validar visualmente tras el rollout si acaso. |
| Enforce Sharing Rules when Apex Launches a Flow | Needs Action, recomendado desde Winter '25 | **Descartado** — cero usos de `Flow.Interview` / `System.Flow` en Apex (`grep` sin resultados). |
| Enforcing No-Argument Constructor for Invocable Action Parameters | Needs Action, Summer '26 | Único caso relevante: `SM_ValidarTarjetaInvocable.ValidarTarjetaInput/Output` — sin constructor explícito, usan el constructor implícito sin argumentos. **Ya cumple**, no requiere cambio. |
| Evaluate Criteria Based on Original Record Values in Process Builder | Needs Action, sin fecha de enforcement fija | Hay 3 procesos Process Builder activos: `SM_Update_original_type_in_late_payment_fee`, `ContractPaymentActions` (2 record updates), `ChargentOrderPB`. Pendiente revisar manualmente si alguno combina múltiples criterios + record update sobre el mismo registro (no se pudo confirmar solo con grep, requiere abrir cada Process Builder). |
| Restrict OAuth 2.0 Device Flow / Salesforce to Salesforce Retirement / Upgrade to Enhanced LWR Sites / Block Apex Anonymous Code Execution from Managed Packages (Chargent) | Needs Action, fechas Nov'26–Summer'27 | Metadata de Connected Apps, Partner Network y Sites **no está en este repo** (no hay carpetas `connectedApps`/`networks`/`experiences`), así que no se puede confirmar por código. El de Managed Packages sí aplica en teoría porque Chargent (`ChargentOrders__`) es paquete gestionado, pero es Summer '27, no urgente todavía — preguntar a soporte de Chargent si su paquete ejecuta anonymous Apex internamente. |

### "Update Instanced URLs in API Traffic" — cerrado 2026-09-06 con datos reales de `LoginHistory`

Validado con `sf data query -o MONEE -q "SELECT Application, LoginUrl, COUNT(Id) cnt FROM LoginHistory GROUP BY Application, LoginUrl"` (28 combinaciones app×URL, todo el historial disponible):

- **Ninguna integración real usa la URL de instancia vieja.** Todo el tráfico de API/aplicaciones usa `monee.my.salesforce.com` (My Domain) o el redirector estándar `login.salesforce.com` — ambos sobreviven una migración de instancia sin romperse. Volumen por sistema: Tableau Online for Salesforce (17,919), Salesforce CLI (17,057 — nuestros propios scripts vía `sf apex run`/`sf org display`), Browser (6,246), ChargeBee for salesforce (4,555), Microsoft Power Query (723), n8n (480), Adobe Acrobat Sign (397), Zapier (90), apps móviles Salesforce, dataloader.io, Workbench, XL-Connector 365, AppFrontier, Cloud4J.
- Los únicos 4 registros con `usa588.sfdc-lywfpd.salesforce.com` son logins de **navegador** (`Application: Browser`, `ApiType: null`, no tráfico de API) de **Richard Cantres** (`rcantres@legal-credit.com`) y **Joan Crespi** (`jcrespi@legal-credit.com`), mayo 2026 — probablemente un bookmark viejo. No bloquean nada al activar "Block API traffic that uses an incorrect instanced URL"; solo valdría avisarles que actualicen el link a `https://monee.my.salesforce.com`.
- De paso se confirmaron 4 Named Credentials configuradas directo en Setup (no están en este repo, no se pueden ver por metadata): `harmoneyllc`→`https://harmoneyllc.chargebee.com`, `GHL_API`, `N8N_Production_Instance`, `Chargebee API` — todas para llamadas salientes de Salesforce hacia esos sistemas, no relevantes para este update (que es sobre tráfico entrante).
- Respecto al aviso "Add API traffic to your test plans" (tráfico que hoy usa la URL de instancia *correcta* pero se rompería si la org cambia de instancia): no aplica, no se encontró ningún sistema que dependa de una URL de instancia fija — no hace falta agregar nada a un test plan por este motivo.
- **Seguro activar el release update completo.**

**Pendiente real:**
1. Antes del 10-oct-2026: correr el "Test Run" o *login-as* no-admin para "Enable Profile Filtering" y confirmar que `SM_TestSmartDataFactory` y los tests de `SM_ContractHandlerTest` siguen pasando. **OJO:** esto toca clases de la migración de Chargent (`SM_ContractHandlerTest`) que el usuario está sincronizando manualmente — ver sección 3, no tocar/desplegar sin confirmar con él primero.
2. Revisar manualmente los 3 Process Builder por el bug de "Evaluate Criteria Based on Original Record Values" — **hecho 2026-09-06**: `SM_Update_original_type_in_late_payment_fee` no aplica (1 solo criterio). `ContractPaymentActions` **sí está expuesto** (7 nodos de criterio en el mismo proceso, 2 de ellos — `isChangedDecision8`→"Update Opportunity" y `myDecision9`→"Update Gateway" — seguidos de un record update; no es Chargent, se puede seguir revisando/probando libremente). `ChargentOrderPB` también expuesto (4 criterios + 1 record update) pero es parte de la migración de Chargent — no tocar, queda para cuando el usuario sincronice ese bloque.
3. Confirmar con el usuario si alguna vez se pidió a Salesforce Support desactivar la verificación de cambio de email (para "Adopt Authorized Email Domains").
4. El conector "Salesforce - Beta" sigue sin poder autorizar (ref. error `ofid_d0347292fb8fe49c`) — mientras tanto, `sf` CLI autenticado a MONEE (y ahora también a **PREPROD**, sandbox `clopez@legal-credit.com.preprod`) ya permite consultas SOQL de solo lectura directas que sirven para verificar hechos de la org sin depender del conector.

**Fuentes:**
- [Enable Profile Filtering (Release Update) — Salesforce Help](https://help.salesforce.com/s/articleView?id=release-notes.rn_permissions_profile_filtering_enforced.htm&language=en_US&type=5)
- [Salesforce Winter '27 Turns On Profile Filtering: What Breaks, and How to Test It First — Software Insights](https://www.softwareinsights.dev/posts/salesforce-winter-27-profile-filtering-breaking-change/)
- [SOAP API login() Call Retirement (Release Update) — Salesforce Help](https://help.salesforce.com/s/articleView?id=release-notes.rn_api_upcoming_retirement_258rn.htm&language=en_US&release=258&type=5)
- [Salesforce API Versions 31.0–40.0 Retire June 2028 — Vantagepoint](https://vantagepoint.io/blog/sf/salesforce-api-versions-31-40-retirement)
- [Salesforce Winter '27 Release: What to Expect and How to Prepare — Salesforce Ben](https://www.salesforceben.com/salesforce-winter-27-release-what-to-expect-and-how-to-prepare/)
