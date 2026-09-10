# Traspaso — Revisión 91 contratos (cobro de agosto 2026) y hallazgos derivados

**Última actualización: 2026-09-09, sesión en ANTIGUA (`C:\SALESFORCE\LCS\SCRIPTS_LCS_2025`).**
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

## 7. Pendiente explícito para la próxima sesión (aún no iniciado)

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
