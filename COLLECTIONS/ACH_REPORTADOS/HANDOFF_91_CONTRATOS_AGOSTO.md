# Traspaso — Revisión 91 contratos (cobro de agosto 2026) y hallazgos derivados

**Última actualización: 2026-09-10, sesión en NUEVA (`C:\SALESFORCE\LCS\SCRIPTS_LCS_2025`).**
Este archivo es la fuente de verdad para retomar este trabajo desde cualquiera de las dos
máquinas (ver `CLAUDE.md`) — la memoria local de Claude Code (`~/.claude/projects/.../memory/`)
tiene más detalle narrativo pero **no viaja entre máquinas**; este archivo sí, vía git.

## Origen

Carlos entregó una lista de 91 números de contrato (02-sep-2026) para validar si tuvieron su
cobro de agosto. La investigación se expandió mucho más allá de eso — ver secciones abajo.

## 1. Los 91 + 12 contratos originales — CERRADO

103 contratos revisados (91 + 12 hallados en un barrido org-wide). Todos resueltos dentro de su
alcance, salvo los puntos abiertos de las secciones 2-4 más abajo (que nacieron de este trabajo
pero son temas aparte). Reportes detallados por grupo (A-E + Barrido) ya entregados a Carlos en
conversación — no repetidos aquí para no duplicar; si hace falta el detalle grupo por grupo,
pedírselo a Carlos o reconstruir desde los CSV en esta misma carpeta.

**Causa raíz de fondo (de todo lo derivado de aquí):** el trigger panel `SM_ChargentTransactionTGR`
(mal nombrado — sin relación real con Chargent) quedó deshabilitado por error al retirar Chargent,
rompiendo semanas el flujo "AC cobrado → activar contrato → crear Subscription". Fix permanente:
Flow `PAYMENT_Accumulate_AC_On_Contract`, en producción desde 2026-09-02.

**2 seguimientos menores nuevos, detectados 2026-09-09** (no bloqueantes, bajo monto): las LPF de
agosto de los contratos **00316731** (`ACH-29214`, $75) y **00316732** (`ACH-29215`, $75), creadas
el 03-sep, fueron **rechazadas por el banco** (`RETURN`) y la orden volvió a `Stopped`. Igual que
el resto de casos "Stopped nunca reactivada" — falta decidir si reactivar (`Initiated`, sin tocar
fecha salvo instrucción) o dejarlas para el próximo barrido de ese patrón.

## 2. Bug "AC Completed sin Payment" (update masivo 2026-08-14) — CERRADO

15 órdenes AC afectadas (12 en contratos activos, Grupo D del análisis original + 3 en contratos
ya cancelados). Todas corregidas y **ya confirmado que cobraron con éxito**: **$1,348 recuperados**
(12 órdenes activas, todas `Completed` al 2026-09-09). Las 3 de contratos cancelados se corrigieron
a `Canceled` (sin cobro esperado, correcto).

## 3. LPF `Stopped` nunca reactivadas (rechazo ya resuelto `Not_Collected`) — CERRADO

101 órdenes encontradas org-wide → 100 tras exclusiones (Cancelled/Finalized/VIP/Test/FullPayment/
PaymentCompleted + lista "Contratos para Cancelar") → **97 activadas** (`Initiated`, 08-sep) por
Claude + 3 procesadas directamente por Carlos. **Verificado 2026-09-09: 96 de las 97 cobraron con
éxito (`Completed`), 1 terminó `Canceled`** (revisar cuál si se necesita el detalle exacto — no
crítico). **Total recuperado: ≈$12,046** (menos el valor de la 1 cancelada).

Aparte, **20 LPF estaban mal etiquetadas** (tenían pago `ACCEPTED` pero no en `Completed`) —
corregidas a `Completed`. Sin impacto monetario (ya estaban cobradas, solo la etiqueta era
incorrecta).

**Regla de conteo validada esta investigación — ver `feedback_rc_payment_counting_method.md` en
memoria local si se necesita el detalle completo del método** (neto = aceptados+transmitidos-
reembolsos, excluir LPF de origen AC, cuidado con contratos que tuvieron doble cobro compensado
por un mes saltado después, y con la relación correcta Payment→Order para encontrar la orden
`Stopped` asociada a un pago en `RETURN`).

## 4. Patrón de doble cobro (29-jul + 24-26 ago) — ABIERTO, EN ESPERA

12 órdenes LPF que ya habían cobrado una vez el 29-jul volvieron a generar intentos de cobro entre
el 24 y 26 de agosto. **Re-verificado en vivo contra MONEE 2026-09-10 (SOQL directo sobre
`SM_ACH_Order__c`/`SM_Payment__c`, no solo el índice): SIGUE SIN RESOLVER, sin cambios desde
2026-09-09** — los pagos `ACH TRANSMITTED` de esas fechas todavía no tienen estado final. Esto ya
no parece un simple "está esperando al banco" — vale la pena escalarlo o investigar si el import
diario de Collections/Returns los está tomando (ver nota de la sección 5 sobre el fix del
2026-09-07).

**Detalle nuevo 2026-09-10, no visible en el resumen anterior:** cada una de las 10 órdenes
abiertas no tuvo solo 1 reintento — tuvo **entre 2 y 4 pagos duplicados** (36 en total, 32 todavía
`ACH TRANSMITTED` sin resolver + los 4 ya `ACCEPTED`), todos confinados a la ventana del 24-26 de
agosto (nada después — no es un bug de re-envío diario en curso, fue un evento acotado a esos 3
días). Los 4 casos ya confirmados como doble cobro **también tienen 2-3 intentos duplicados extra
sin resolver cada uno** — riesgo de un tercer/cuarto cobro si el banco los acepta, no cerrado del
todo.

- **2 ya resueltas** vía reembolso bancario real (`ACH-28196`, `ACH-28216`) — confirmadas `Completed`
  por Carlos.
- **4 dobles cobros CONFIRMADOS** (2 pagos `ACCEPTED` reales, sin reembolsar todavía):
  `ACH-28201` (00316463, $99), `ACH-28194` (00314444, $79), `ACH-28208` (00316863, $99), y
  `ACH-28214` (00317219, $89). **Total confirmado a reembolsar: $366.**
- **6 más sin resolver, en riesgo de convertirse en doble cobro** si su `ACH TRANSMITTED` pendiente
  se acepta: `ACH-28192` ($49), `ACH-28193` ($79), `ACH-28195` ($99), `ACH-28197` ($79),
  `ACH-28207` ($99), `ACH-28209` ($139) — **exposición adicional: $544**. (El informe ejecutivo HTML
  traía por error `$694`/8 contratos en el tile resumen, desincronizado del detalle del caso —
  corregido 2026-09-10 a `$544`/6, que es lo que realmente suma la tabla.)

**No tocar ninguna de estas 10 hasta que el banco/collections resuelva sus pagos en proceso**
(instrucción explícita de Carlos, 2026-09-05, sigue vigente).

## 5. Lote `ADJ_AC_ERR_12AGO` (proceso masivo erróneo, 2026-08-14) — ANALIZADO, PENDIENTE DECISIÓN

90 órdenes originadas por un proceso masivo que creó AC Orders con montos erróneos. Estado:
- 61 con status `Completed` (ya cobraron con el monto erróneo) — **analizado a fondo 2026-09-09**,
  ver `ADJ_AC_ERR_12AGO_Analisis_Pagos_61.csv` en esta misma carpeta.
  - **60 contratos sobrecobrados: $4,382.47 total a reembolsar** (diferencia entre lo cobrado y la
    mensualidad real).
  - **1 contrato subcobrado $74** (`00316168`) — cobró de menos, no de más; caso invertido, revisar
    aparte (puede que sí corresponda cobrarlo).
  - Cada contrato tuvo exactamente 1 cobro erróneo (no repetido) — confirmado con el historial
    completo de pagos de cada uno.
- ~23 en `Stopped`, 3 en `Canceled`, 1 en blanco (auto-corregido a `Stopped`) — ya seguros, sin
  acción necesaria salvo revalidar que sigan así.

**Pendiente: decisión de negocio sobre cómo procesar el reembolso de los $4,382.47** (¿reembolso
directo, crédito al próximo ciclo, ajuste de LPF futura?) — Carlos no ha decidido el mecanismo
todavía.

## 6. Contratos que no se deben tocar (lista "para cancelar")

479 contratos con `SM_Customer_Cancellation__c=true`; 472 ya `Cancelled`, 7 aún activos. **Regla
permanente: nunca activar un cobro en un contrato de esta lista** — si algún candidato a
reactivación pertenece a esta lista, pasarlo a `Canceled` en vez de `Initiated` y registrar en
`Contratos_para_Cancelar_LOG.csv`. Sin cambios pendientes aquí (cruce ya validado, 0 solapamiento
con los 100 reactivados de la sección 3).

## 7. Pagos "en Collection" sin veredicto final, dentro de los 217 contratos del informe — ANALIZADO 2026-09-10, PENDIENTE DECISIÓN

A pedido de Carlos, se categorizaron todos los pagos de Check Collection/Returns con estado
distinto a `COLLECTED`/`ACCEPTED`/`NOT_COLLECTED`, **scoped a los 217 contratos únicos que cubren
los casos 1, 2, 4, 5 y 6 del informe ejecutivo** (casos 3 y "otros ajustes" quedaron fuera — no
hay un CSV con su lista de contratos en el repo). Metodología: SOQL en vivo contra MONEE +
cruce contra `index/collections_index.csv` e `index/returns_index.csv` completos (no solo el
delta reciente).

De 328 pagos con estado "no limpio", **214 son en realidad terminales con otro nombre** —
`REJECTED|RETURN` (114, el ACH ya fue devuelto por el banco, la LPF ya se generó sola) y
`REFUNDED|REFUNDED`/`CANCELLED|NOT_COLLECTED` (14) — no están pendientes de nada.

Los **200 `REJECTED|PENDING` restantes** sí son genuinamente ambiguos, y se dividen en:

- **A) Backlog nuestro — 50 pagos, $4,331.50. RESUELTO 2026-09-10 (49 de 50 aplicados).**
  Carlos confirmó explícitamente aplicar este backlog específico (Regla 2 satisfecha). En vez de
  `run_daily_catchup.sh` (que hubiera tocado TODO el backlog viejo del sistema, no solo estos 50),
  se armó un CSV scoped con exactamente estas 50 filas — extraídas de `collections_index.csv`,
  desplegadas como `StaticResource:CheckCollectionImport` — y se corrió
  `update_check_collection.apex` (DRY RUN primero, confirmó 50/50 match, 0 bloqueados; luego real).
  Primer intento (oleadas de varios registros por DML): 14 aplicados, 36 fallaron juntos por un bug
  nuevo (ver abajo) — verificado que los 36 quedaron sin cambios, nada corrupto.

  **Segundo intento — aislado, 1 registro por DML** (`update_check_collection_isolated.apex`,
  mismo CSV, en lotes de 12 por corrida para no chocar con el límite de 100 SOQL queries por
  ejecución — a los 36 en un solo DML sí se topó con "Too many SOQL queries: 101", rollback limpio
  confirmado, sin nada aplicado a medias): **35 de 36 aplicados con éxito, 1 aislado y
  confirmado como el disparador real del bug — `PY-01786030` (contrato 00315538)**, sigue en
  `REJECTED`/`PENDING`. Total final: 14 + 35 = 49 de 50 en su estado correcto
  (40 `ACCEPTED`/`COLLECTED` + 9 `REJECTED`/`NOT_COLLECTED`), verificado en vivo.

  `update_check_collection.apex` y `update_check_collection_isolated.apex` (este último nuevo,
  queda en el repo para la próxima vez que haga falta aislar así) quedaron de vuelta en
  `DRY_RUN = true`. `CheckCollectionImport.csv`/`ACHReturnsImport.csv` (static resources) quedaron
  con el contenido scoped de esta corrida, no con su contenido "normal" del flujo diario — replace
  antes de la próxima corrida normal del pipeline.

  **`PY-01786030` (00315538) — RESUELTO 2026-09-10.** Ver el bug de fondo y su fix abajo; una vez
  desplegado el fix, falta reprocesar este pago puntual (no se reintentó todavía después del
  deploy — es un `.apex` de una sola fila, trivial cuando se necesite).

  **BUG DESCUBIERTO Y CORREGIDO 2026-09-10 — `SM_FeePaymentToDependentContract.cls:181` y
  `SM_AcPaymentToDependentContract.cls:120`** hacían referencia a un campo
  `SM_Chargent_Orders_Transaction__c` que ya no existe en el org (parece borrado al desinstalar
  Chargent, las clases nunca se actualizaron). Cuando `SM_PaymentTrigger` procesa en bloque un
  lote que incluye al menos un pago Fee/AC/LPF yendo a `ACCEPTED` en un contrato Master con
  dependientes, esa clase truena (`System.SObjectException: Invalid field`) y tumba **todo el
  lote bulkificado**, no solo el registro que la disparó — así cayeron los 36 de la Oleada 1.

  **Fix desplegado a MONEE, confirmado por Carlos y verificado en vivo (LastModifiedDate
  2026-09-10T18:29:29):** la línea se comentó (no se borró) en ambas clases, con la nota
  `// PARTE APP DE CHARGENT. ELIMINADA JUL 2026`. Para lograr un deploy limpio con
  `RunSpecifiedTests` (ver regla nueva en `CLAUDE.md` sección 1) hizo falta además:
  - Comentar completo `SM_FeePaymentToDependentContractTest.clonePaymentsByChargentOk` — probaba
    un escenario que ya no puede ocurrir (un pago originado desde una orden de Chargent), y
    fallaba por una razón *distinta* y más sutil: `hasChargentTransactionAccess()` siempre
    devuelve `true` bajo `Test.isRunningTest()` (bypass que asumía que Chargent seguía disponible
    en tests), lo que hacía que el test SÍ intentara la consulta con la relación
    `SM_Chargent_Orders_Transaction__r` — confirmado con un script de diagnóstico aparte que esa
    consulta específica falla con "Didn't understand relationship". En producción real (fuera de
    tests) esta función ya detectaba correctamente que Chargent no está disponible y evitaba la
    consulta — por eso el bug real (`PY-01786030`) era otra cosa completamente distinta (la línea
    181, incondicional, sin protección de `hasChargentTransactionAccess()`).
  - Agregar `clonePaymentsByAcOk`, un test nuevo (reutiliza el master/dependientes de `makeData()`)
    porque `SM_AcPaymentToDependentContract` no tenía NINGÚN test que la cubriera (0% bloqueaba el
    deploy bajo `RunSpecifiedTests`, que sí exige mínimo de cobertura por clase, a diferencia del
    agregado del org completo).

  Resultado final del deploy: 4/4 tests, 0 fallos, 0 advertencias de cobertura
  (`SM_AcPaymentToDependentContract` 52/53 líneas, `SM_FeePaymentToDependentContract` 69/78).

  **Fix validado en la práctica, 2026-09-10.** De los 1,764 pagos Fee/AC/LPF sin cobrar
  ($215,034.21) en 47 contratos Master con dependientes identificados antes del fix, se revisó
  cuál parte era genuinamente accionable hoy: **1,557 (88%) resultaron ser ruido histórico**
  (`REJECTED` sin ningún reporte del banco jamás adjuntado, orden padre sin estado, 1,256 de
  2023) — no backlog activo, parece el mismo patrón que los 84 contratos legacy ya documentados
  (sección 2.3). Confirmado con Carlos: revisar `SM_Id_Salesforce_LCS__c` +
  `SM_Is_Migrated__c` antes de tratar un lote viejo como brecha operativa real — ver
  `feedback_migration_field_check.md` en memoria local (ese sample específico de 1,557 dio
  `SM_Is_Migrated__c=False`, así que NO es migración, sigue sin explicación, pero la regla de
  chequeo queda para el futuro). De los 197 restantes con un estado de reporte real, cruzando
  contra el índice local solo **2 tenían resolución lista para aplicar** — los otros 191 no
  tienen dato nuestro que los resuelva.

  **Se aplicó el más relevante de los 2: `PY-01786030` (contrato 00315538, $119) → `ACCEPTED`/
  `COLLECTED`, sin ningún error — el fix funciona.** Más importante: **el clonado al contrato
  dependiente ocurrió correctamente** (`PY-01900409`, $119, creado automáticamente en el contrato
  dependiente 00315539) — confirma que el fix no solo evita el crash, produce el resultado de
  negocio correcto de punta a punta. El otro (`PY-01842238`) resultó ya estar resuelto por otra
  vía (fecha de reporte 16-jun ya aplicada, más reciente que la de nuestro índice) — nada que
  hacer ahí.

  **Los 1,557 de ruido histórico (2023, sin reporte jamás) — OMITIR, decisión explícita de
  Carlos 2026-09-10.** No se investiga ni se procesa. Sigue pendiente, si se retoma más adelante,
  investigar los 191 restantes (con estado de reporte real pero sin dato en nuestro índice).

  **Reconciliación de pagos por contrato (los 29 contratos de estos 50 pagos)** — a pedido de
  Carlos, conteo de pagos `Subscription` `ACCEPTED` vs. meses transcurridos desde el primer cobro,
  por contrato: **ninguno de los 29 está al día ni tiene cobros de más — los 29 están debiendo**,
  entre $79 y $714. Casos que destacan más allá del backlog de hoy: `00316097` (6 de 7 meses
  fallidos confirmados), `00270432` (5 meses seguidos sin cobrar, marzo-julio 2026, en curso ahora
  mismo — verificado con su historial completo), `00275989` (5 fallos confirmados), `00315643` (3
  de 9 meses fallidos, contrato reciente). Carlos dijo dejarlo en espera por ahora, no investigar
  más todavía.
- **B) Falta trabajar realmente — 1 pago, $99. RESUELTO 2026-09-10.** `PY-01810250` (contrato
  00316842, Cancelado) — mismo patrón de bug ya documentado con `PY-01876062`/ACH-27553 en
  `update_check_collection.apex` (aplicar en bulk sobre un contrato Cancelado puede tumbar toda la
  oleada del día por una validation rule). Carlos lo aplicó manualmente y aislado — verificado en
  vivo: `ACCEPTED`/`COLLECTED`, orden ACH-26053 correctamente `Canceled` (sin cobro futuro
  esperado). **`PY-01876062`/ACH-27553 (contrato 00317537, el caso original que documentó el bug)
  también RESUELTO 2026-09-10** — verificado en vivo: `ACCEPTED`/`COLLECTED` ($139), orden en
  `Completed`. Con esto ya no queda ningún caso abierto de este patrón (contrato Cancelado +
  bulk update) dentro de lo analizado hasta ahora.
- **C) Genuinamente pendiente de respuesta del banco — 149 pagos, $14,338**, por antigüedad del
  último reporte conocido: 0-15d (20, $2,017), 16-30d (12, $1,070), 31-60d (18, $1,754),
  **60+d (99, $9,497)** — el bloque más grande, vale la pena vigilarlo igual que el caso 5.

**No se ha agregado todavía al informe ejecutivo HTML** (`reporte_ejecutivo_gerencia.html`) —
Carlos pidió dejarlo para trabajarlo más adelante. Si se retoma, candidato natural a "Caso 07".

## 8. Dos informes ejecutivos publicados (Artifacts) — 2026-09-10

- **General** (todo lo procesado, los 6 casos): `reporte_ejecutivo_gerencia.html` —
  https://claude.ai/code/artifact/0ce8ea36-8d75-4bb8-8a20-d748c1b97732 — Caso 1 corregido hoy
  (ya no dice "37 de 39 ya cobraron", verificado en vivo que ninguno tiene confirmación del banco
  todavía) y tile "Recuperado" ajustado de $16,755/137 a $13,394/100 por la misma razón.
- **"Contratos Agosto - Ventas"** (scoped estrictamente a los 94 contratos que dio Ventas — 91
  originales + 3 adicionales, lista guardada en `Contratos_Agosto_Ventas_94.csv`, nunca antes
  persistida en el repo): `reporte_agosto_ventas.html` —
  https://claude.ai/code/artifact/c32f7c97-2e66-4972-9cf4-40bfe8a917dd — 4 grupos: A (14, tenían
  suscripción normal, agosto saltado, LPF 03-sep sin confirmar), B (33, nunca llegaron a su primera
  suscripción, AC sin resolver — 29 transmitidos + 4 rechazados sin reintentar), E (43, primera
  suscripción de su vida cae en septiembre por ser nuevos — 39 transmitidos + 4 rechazados sin
  reintentar), F (1, contrato 00318139 completamente detenido, ni su AC se ha transmitido). Los 3
  adicionales: 2 ACH con su AC ya cobrado (00317534, 00317786) y 1 Tarjeta de Crédito (00318313,
  sin visibilidad — Chargent desinstalado del org). **A la fecha, $0 de los 94 tiene confirmación
  bancaria de cobro** — todo está transmitido esperando al banco (82, $8,510) o rechazado sin
  reintentar (8, $992).

## 9. Pendiente explícito para la próxima sesión (aún no iniciado)

**Script Apex consolidado de "errores y fixes"** — para correr ocasionalmente y detectar si
reaparece alguno de estos patrones (AC Completed sin Payment, LPF Stopped nunca reactivada, doble
cobro 29-jul/24-26-ago, ADJ_AC_ERR_12AGO). Carlos pidió explícitamente dejarlo para hacer junto con
el cierre del punto 5. No existe ningún borrador todavía.

## Archivos de referencia en esta carpeta (`COLLECTIONS/ACH_REPORTADOS/`)

- `LPF_Stopped_Nunca_Reactivadas_101.csv` — listado original de las 101 (antes de exclusiones).
- `LPF_Stopped_100_Reactivar_Validado.csv` — los 100 finales, validados, con banco y fecha de
  rechazo original.
- `Contratos_para_Cancelar_LOG.csv` — los 479 de la sección 6.
- `ADJ_AC_ERR_12AGO_Analisis_Pagos_61.csv` — análisis de pagos de la sección 5.
