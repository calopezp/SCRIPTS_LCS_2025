# Contexto del repo

## Dos máquinas sincronizadas por git

El usuario (calopezp) trabaja este repo desde dos computadoras, sincronizadas vía GitHub (`origin` = `https://github.com/calopezp/SCRIPTS_LCS_2025.git`, rama `main`):

- **ANTIGUA** — `C:\SALESFORCE\LCS\SCRIPTS_LCS_2025\` (usuario Windows: Carlos Lopez New)
- **NUEVA** — `C:\SALESFORCE\LCS\SCRIPTS_LCS_2025\`

Este archivo viaja con el repo (se sincroniza en cada `push`/`pull`), a diferencia de la memoria local de Claude Code (`~/.claude/projects/.../memory/`), que vive por separado en cada máquina y **no** se sincroniza automáticamente. Si trabajas desde una sesión nueva en cualquiera de las dos máquinas, este archivo es la fuente de verdad compartida — la memoria local de Claude Code puede tener detalle adicional pero es específica de esa máquina.

## Flujo de trabajo con git (preferencia del usuario)

- Hacer commits locales para preservar historial de versiones; el push a GitHub no es automático — se hace solo cuando el usuario lo pide explícitamente.
- Nunca usar `git add -A`. Agregar archivos específicos por nombre al hacer stage.
- Antes de empezar a trabajar en cualquiera de las dos máquinas: `git pull origin main`.
- Al terminar una sesión de trabajo: commit (y push si el usuario lo confirma) para que la otra máquina pueda traer los cambios.

## ⚠️ Clases en migración por cancelación de CHARGENT — NO TOCAR, el usuario las sincroniza manualmente

Hay 2 orgs conectadas por `sf` CLI: **MONEE** (producción) y **PREPROD** (sandbox, alias `clopez@legal-credit.com.preprod`). Durante el análisis de Winter '27 (2026-09-06) se comparó el `Body` real (Tooling API, `SELECT Body FROM ApexClass`) de 4 clases entre ambos orgs y el repo local, por una falla inesperada al correr `SM_ContractHandlerTest` en MONEE. Resultado:

| Clase | MONEE (producción) | PREPROD (sandbox) | Repo local |
|---|---|---|---|
| **`SM_ContractHandler`** | 2026-07-09, Juan Duarte — **cuerpo vacío**, los 12 métodos (`beforeUpdate`, `afterUpdate`, `processAssetsByContractStatusChange`, `checkUpdateMasterStatus`, etc.) son no-op `{}`, incluye un `testGarbage()` | 2026-07-09, Carlos Lopez — **62 KB, lógica completa real** (incluye `hasChargentObjectAccess()`) | idéntico byte a byte a MONEE (la cáscara vacía) |
| **`SM_ContractHandlerTest`** | **2022-08-27** (Legal Credit Solutions) — versión pre-cancelación de Chargent, usa `ChargentOrders__ChargentOrder__c`/`getChargentorder()`, no asigna `SM_Bank__c` → falla PM003 al correrla | 2026-07-09, Carlos Lopez — versión actualizada, ya asigna Banco a los Payment Methods ACH | idéntico byte a byte a PREPROD (ya tiene el fix) |
| `SM_ContractHelper` | 2022-11-13 (igual en ambos orgs) | 2022-11-13 (igual) | idéntico a ambos — sin divergencia |
| `SM_TestSmartDataFactory` | 2022-11-13 (igual en ambos orgs) | 2022-11-13 (igual) | idéntico a ambos — sin divergencia |

**Implicación:** ahora mismo en producción, toda la lógica del trigger de Contract (activación de assets, status maestro/dependiente, condiciones de pago) corre como no-op porque `SM_ContractHandler` está vaciado — el reemplazo real solo existe en PREPROD. El repo local heredó la cáscara vacía de MONEE para `SM_ContractHandler`, pero la versión corregida de `SM_ContractHandlerTest` desde PREPROD.

**Instrucción explícita del usuario (2026-09-06): no modificar ni desplegar estas clases (`SM_ContractHandler`, `SM_ContractHandlerTest`, ni las relacionadas con la migración de Chargent) — es un trabajo en curso que el propio usuario está validando y sincronizará manualmente entre MONEE/PREPROD/repo cuando esté listo.** Si aparece una sesión nueva y se necesita tocar algo relacionado con Contract/Chargent, preguntar primero — no asumir que el repo o MONEE tienen la versión "correcta".

## Winter '27 Release Readiness — análisis 2026-09-06, revisado 2026-09-06 con fuentes reales (release notes ya públicas desde el 19-ago-2026)

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
1. Antes del 10-oct-2026: correr el "Test Run" o *login-as* no-admin para "Enable Profile Filtering" y confirmar que `SM_TestSmartDataFactory` y los tests de `SM_ContractHandlerTest` siguen pasando. **OJO:** esto toca clases de la migración de Chargent (`SM_ContractHandlerTest`) que el usuario está sincronizando manualmente — ver sección de arriba, no tocar/desplegar sin confirmar con él primero.
2. Revisar manualmente los 3 Process Builder por el bug de "Evaluate Criteria Based on Original Record Values" — **hecho 2026-09-06**: `SM_Update_original_type_in_late_payment_fee` no aplica (1 solo criterio). `ContractPaymentActions` **sí está expuesto** (7 nodos de criterio en el mismo proceso, 2 de ellos — `isChangedDecision8`→"Update Opportunity" y `myDecision9`→"Update Gateway" — seguidos de un record update; no es Chargent, se puede seguir revisando/probando libremente). `ChargentOrderPB` también expuesto (4 criterios + 1 record update) pero es parte de la migración de Chargent — no tocar, queda para cuando el usuario sincronice ese bloque.
3. Confirmar con el usuario si alguna vez se pidió a Salesforce Support desactivar la verificación de cambio de email (para "Adopt Authorized Email Domains").
4. El conector "Salesforce - Beta" sigue sin poder autorizar (ref. error `ofid_d0347292fb8fe49c`) — mientras tanto, `sf` CLI autenticado a MONEE (y ahora también a **PREPROD**, sandbox `clopez@legal-credit.com.preprod`) ya permite consultas SOQL de solo lectura directas que sirven para verificar hechos de la org sin depender del conector.

**Fuentes:**
- [Enable Profile Filtering (Release Update) — Salesforce Help](https://help.salesforce.com/s/articleView?id=release-notes.rn_permissions_profile_filtering_enforced.htm&language=en_US&type=5)
- [Salesforce Winter '27 Turns On Profile Filtering: What Breaks, and How to Test It First — Software Insights](https://www.softwareinsights.dev/posts/salesforce-winter-27-profile-filtering-breaking-change/)
- [SOAP API login() Call Retirement (Release Update) — Salesforce Help](https://help.salesforce.com/s/articleView?id=release-notes.rn_api_upcoming_retirement_258rn.htm&language=en_US&release=258&type=5)
- [Salesforce API Versions 31.0–40.0 Retire June 2028 — Vantagepoint](https://vantagepoint.io/blog/sf/salesforce-api-versions-31-40-retirement)
- [Salesforce Winter '27 Release: What to Expect and How to Prepare — Salesforce Ben](https://www.salesforceben.com/salesforce-winter-27-release-what-to-expect-and-how-to-prepare/)
