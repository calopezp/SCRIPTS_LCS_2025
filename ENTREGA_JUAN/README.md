# Entrega — Pipeline de Cobranza / Collections (Legal Credit Solutions / MONEE)

> **Qué es esta carpeta:** una copia lista para instalar en otra máquina (la tuya, Juan) del
> código que corre el día a día de cobranza bancaria (Collections: ACH Returns, Check Collection,
> ACH Reportados/transmisión). **Es una copia, no un enlace al repo original** — si el repo
> original (`SCRIPTS_LCS_2025`) sigue cambiando, esta carpeta hay que refrescarla a mano de vez en
> cuando (ver "Cómo se mantiene al día" al final).
>
> **Alcance de esta entrega: solo Collections.** No incluye ACH Transmisión (los 4 pasos
> manuales `scripts/apex/ACH_TRANSMISION/A-D.apex`) ni Cancelar Contratos
> (`COLLECTIONS/CANCELACIONES/`) — ambos viven en el repo original y, si hacen falta, se acceden
> ahí directamente (ver `CLAUDE.md` secciones 2 y 6, y el skill `/cancelar-contratos`).

**Primero lo primero:** si tu objetivo es entender el puesto completo (qué hace cada cosa, qué
automatizaciones corren solas en Salesforce, qué NO tocar, a quién preguntar), empieza por
`MANUAL_TRASPASO.md` en la raíz del repo — este README es solo el mapa de **esta carpeta de
entrega** (el código ejecutable), no repite ese contexto.

---

## 1. Cómo está organizado (Procesos vs. Utilitarios)

Esta carpeta agrupa todo en dos categorías. **Es una división conceptual para que sepas qué es
cada cosa — las rutas de archivo reales NO se movieron ni se renombraron** (se copiaron tal cual
están en el repo original, a propósito: varios scripts se llaman unos a otros con rutas relativas,
así que si movemos un archivo de carpeta algo se rompe. La tabla de abajo te dice "qué es" y
"dónde vive de verdad").

### Proceso — lo que corre de forma recurrente (diario)

| Proceso | Qué hace | Dónde vive realmente | Comando para correrlo |
|---|---|---|---|
| **Collections** (cobranza bancaria) | Importa los reportes del banco (ACH Returns, Check Collection, ACH Reportados/transmisión), actualiza el estado de cada Payment en Salesforce, aplica timeouts automáticos, manda 8 correos de alerta a Comercial | `COLLECTIONS/` (carpeta completa: subcarpetas `COLLECTIONS/`, `RETURNS/`, `ACH_REPORTADOS/`, `UTILITARIOS/`, `index/`, más los scripts sueltos en la raíz) | `cd COLLECTIONS && ./run_daily_new_files.sh` (preview) → `./run_daily_new_files.sh apply` (aplica) |

> **Dependencia opcional con ACH Transmisión (fuera de esta entrega):** el paso 5/6 de
> `run_daily_new_files.sh` intenta confirmar el cargue ACH de ayer llamando a
> `../scripts/apex/ACH_TRANSMISION/C. Confirmar Cargue Reporte ACH.apex`. Como esa carpeta no está
> en esta entrega, el script simplemente imprime un aviso ("no se encontro ... -- paso saltado")
> y sigue — no rompe nada, solo significa que ese respaldo puntual no corre. Si en algún momento
> manejas también la transmisión ACH, copia esa carpeta desde el repo original.

### Utilitarios — consultas puntuales, no son parte de ningún proceso programado

| Utilitario | Qué hace | Dónde vive | Ejemplo de uso |
|---|---|---|---|
| **`buscar_payment.py`** | Dado un número de Payment (`PY-xxxxx`), busca su estado en vivo en Salesforce y lo cruza contra los 3 índices históricos (Returns, Check Collection, ACH Reportados) — para saber "¿qué pasó con este pago?" sin tener que abrir PDFs a mano | `COLLECTIONS/buscar_payment.py` | `python COLLECTIONS/buscar_payment.py PY-01868511` |
| **`estado_cobros.py`** | Reporte de estado de cobro de uno o varios contratos Chargebee (Credit Card) — **no es solo "facturas pendientes"**, combina 6 fuentes (Contract, Invoice, Dunning, Charge Request/PTP, historial ACH, órdenes ACH huérfanas tras un switch a TC) y solo se explaya cuando hay algo que decidir. **Lee el docstring completo del archivo (líneas 1-90) antes de usarlo en un caso real** — tiene, con fecha y contrato real, el porqué de cada tipo de alerta; no se repite aquí para no quedar desactualizado cuando el script cambie | `COLLECTIONS/estado_cobros.py` | `python COLLECTIONS/estado_cobros.py 00123456` |
| **`barrido_latefee_not_collected.py`** | Solo lectura: barre contratos cuyo pago ACH tipo Fee quedó `NOT_COLLECTED` (ventana real de la Rule 3, ver `CLAUDE.md` sección 2.2) y valida si ya existe una `SM_ACH_Order__c` de Late Payment Fee cubriendo esa deuda o si falta generarla | `COLLECTIONS/barrido_latefee_not_collected.py` | `python COLLECTIONS/barrido_latefee_not_collected.py` |

> Estos utilitarios **dependen de estar físicamente dentro de `COLLECTIONS/`** (usan
> `build_index.py` y otros módulos de esa carpeta para funcionar) — por eso no se copiaron sueltos
> a otro lado. Se documentan aparte porque, a diferencia del Proceso de arriba, **no los dispara
> ningún script programado** — los corres tú mismo cuando necesitas revisar o corregir algo
> puntual.

### Automatizaciones en Salesforce que afectan el día a día (no requieren correr nada)

No son código de esta carpeta (viven en `force-app/` y ya están activas en MONEE), pero cambian
lo que vas a ver en los registros:

| Automatización | Qué hace | Detalle |
|---|---|---|
| **Flow `ACH_ORDER_Subscription_Stopped_Monitoring`** (activo desde 2026-10-05) | Cuando cualquier usuario pasa una orden ACH `Subscription` a `Stopped`, marca el contrato en **Contract Monitoring** con ese usuario como responsable (si ya tenía responsable, lo respeta) y crea una Task `Open` "Collections-Subscription Stopped" como nota histórica. Desmarcar el monitoreo es manual. Si tú detienes Subscriptions desde scripts, también se dispara (a propósito, por trazabilidad) | `MANUAL_TRASPASO.md` sección 5.3 |

---

## 2. Por dónde empezar

1. Lee `INSTALACION.md` en esta misma carpeta — instala lo que falte (Salesforce CLI, Python,
   la dependencia `pdfplumber`) y confirma accesos (org MONEE, carpeta de OneDrive del banco).
2. Para el detalle técnico línea-por-línea del pipeline (estructura de archivos, reglas de
   negocio, qué significa cada código de retorno bancario, gotchas conocidos), usa el Skill de
   Claude Code ya incluido en el repo: `.claude/skills/collections/SKILL.md` — o ábrelo como
   texto plano si no usas Claude Code.
3. `CLAUDE.md` (raíz del repo) tiene todas las reglas de negocio confirmadas con el caso real que
   las originó — consúltalo antes de cambiar el comportamiento de cualquier script.
4. `BITACORA_HALLAZGOS_TECNICOS.md` y `TAREAS_PENDIENTES.md` (raíz del repo) — bugs ya
   diagnosticados y temas abiertos, para no repetir trabajo.

---

## 3. Cómo se mantiene al día

Esta carpeta es una **copia física**, no un symlink ni un submódulo — se decidió así a propósito
para que la entrega sea un paquete autocontenido y fácil de instalar. Consecuencia: cuando el
trabajo diario en `COLLECTIONS/` (la ubicación original, fuera de esta carpeta) cambie, **hay que
volver a copiar los archivos que cambiaron a `ENTREGA_JUAN/`** para que esta entrega no quede
desactualizada. No hay ningún proceso automático que lo haga — es un paso manual, igual que
cualquier otro commit.

**Decisión confirmada (2026-10-05): la entrega oficial a Juan es acceso al repo completo vía
Git** (no un ZIP aislado de esta carpeta). Con esto, Juan recibe automáticamente todo lo que esta
carpeta NO duplica a propósito: `MANUAL_TRASPASO.md`, `CLAUDE.md`, `BITACORA_HALLAZGOS_TECNICOS.md`,
`TAREAS_PENDIENTES.md`, `TAREAS_OCASIONALES.md`, los Skills (`.claude/skills/`), el metadata de
Salesforce (`force-app/`), ACH Transmisión y Cancelar Contratos (ver nota de alcance arriba) —
`ENTREGA_JUAN/` sigue siendo útil como capa organizada de inicio rápido para el día a día de
Collections, no como el único contenedor del handoff.

**Esta carpeta solo incluye lo que el pipeline diario de Collections realmente lee o escribe**
(código + índices persistidos en `index/` + la copia local de Files de Salesforce en
`ACH_REPORTADOS/sf_files/`, que `build_index.py` usa como fuente real, no solo como caché). Se
excluyen a propósito: salidas transitorias que se regeneran solas en la siguiente corrida
(`*Import.csv`, `reportes_comercial_R10/` histórico), análisis puntuales ya cerrados de un caso
fechado específico, y un backfill de una sola vez ya aplicado en MONEE (2026-10-03). Si necesitas
ese histórico para referencia, está en el repo original, no en esta copia.
