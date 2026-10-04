# Entrega — Pipeline de Cobranza y Cancelación de Contratos (Legal Credit Solutions / MONEE)

> **Qué es esta carpeta:** una copia lista para instalar en otra máquina (la tuya, Juan) de todo
> el código que corre el día a día de cobranza bancaria y cancelación de contratos. **Es una copia,
> no un enlace al repo original** — si el repo original (`SCRIPTS_LCS_2025`) sigue cambiando, esta
> carpeta hay que refrescarla a mano de vez en cuando (ver "Cómo se mantiene al día" al final).

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

### Procesos — lo que corre de forma recurrente (diario/semanal/cuando se agregan contratos)

| Proceso | Qué hace | Dónde vive realmente | Comando para correrlo |
|---|---|---|---|
| **Collections** (cobranza bancaria) | Importa los reportes del banco (ACH Returns, Check Collection, ACH Reportados/transmisión), actualiza el estado de cada Payment en Salesforce, aplica timeouts automáticos, manda 8 correos de alerta a Comercial | `COLLECTIONS/` (carpeta completa: subcarpetas `COLLECTIONS/`, `RETURNS/`, `ACH_REPORTADOS/`, `UTILITARIOS/`, `index/`, más los scripts sueltos en la raíz) | `cd COLLECTIONS && ./run_daily_new_files.sh` (preview) → `./run_daily_new_files.sh apply` (aplica) |
| **ACH Transmisión** (4 pasos manuales, el ciclo de vida de un archivo transmitido al banco) | Genera el archivo a transmitir, confirma el cargue al día siguiente, revierte si hace falta, envía el correo de aviso | `scripts/apex/ACH_TRANSMISION/-A.ReporteACHFile.apex` → `-B.ConfirmarCargueACH.apex` → `-C.RevertirCargueACH.apex` (solo si hace falta) → `-D.EnviarCorreoACH.apex` | `sf apex run -o MONEE -f "scripts/apex/ACH_TRANSMISION/-A.ReporteACHFile.apex"` (y así con cada letra) |
| **Cancelar Contratos** (cancelación masiva ACH/Chargebee) | Recalcula el estado de cada contrato en la lista de cancelación, valida payments pendientes, genera el bloque para ejecutar la cancelación real | `COLLECTIONS/CANCELACIONES/` (vive DENTRO de `COLLECTIONS/` porque reutiliza módulos de Collections — ver nota abajo) + `scripts/apex/-CANCELAR_CONTRATOS_FULL.apex` | `cd COLLECTIONS/CANCELACIONES && ./run_check_estado.sh` luego `python generate_run_batch.py --limite 50` |

> **Nota técnica — por qué Cancelar Contratos está dentro de `COLLECTIONS/`:** sus scripts
> (`validate_pending_payments.py`) importan directamente `build_index.py` y `buscar_payment.py`
> de Collections para no duplicar lógica de cruce de índices. Es una dependencia real de código,
> no un descuido de organización — por eso esta entrega preserva la ubicación exacta en vez de
> separarlos en carpetas independientes (eso rompería los `import`).
>
> La clase Apex que de verdad ejecuta la cancelación (`CancelarContratosRunner.cls`) **ya está
> desplegada en la org MONEE** — no hace falta instalar nada aparte para eso, es parte del
> metadata de Salesforce. Lo que se entrega aquí son los scripts de soporte que corren desde tu
> máquina (dry-run, generación del batch).

### Utilitarios — consultas puntuales, no son parte de ningún proceso programado

| Utilitario | Qué hace | Dónde vive | Ejemplo de uso |
|---|---|---|---|
| **`buscar_payment.py`** | Dado un número de Payment (`PY-xxxxx`), busca su estado en vivo en Salesforce y lo cruza contra los 3 índices históricos (Returns, Check Collection, ACH Reportados) — para saber "¿qué pasó con este pago?" sin tener que abrir PDFs a mano | `COLLECTIONS/buscar_payment.py` | `python COLLECTIONS/buscar_payment.py PY-01868511` |
| **`estado_cobros.py`** | Reporte de estado de cobro de uno o varios contratos Chargebee (Credit Card) — **no es solo "facturas pendientes"**, combina 6 fuentes (Contract, Invoice, Dunning, Charge Request/PTP, historial ACH, órdenes ACH huérfanas tras un switch a TC) y solo se explaya cuando hay algo que decidir. **Lee el docstring completo del archivo (líneas 1-90) antes de usarlo en un caso real** — tiene, con fecha y contrato real, el porqué de cada tipo de alerta; no se repite aquí para no quedar desactualizado cuando el script cambie | `COLLECTIONS/estado_cobros.py` | `python COLLECTIONS/estado_cobros.py 00123456` |

> Estos dos **sí dependen de estar físicamente dentro de `COLLECTIONS/`** (usan `build_index.py`
> y otros módulos de esa carpeta para funcionar) — por eso no se copiaron sueltos a otro lado.
> Se documentan aparte como "Utilitarios" porque, a diferencia de los Procesos de arriba, **no
> los dispara ningún script programado** — los corres tú mismo cuando necesitas revisar algo
> puntual.

---

## 2. Por dónde empezar

1. Lee `INSTALACION.md` en esta misma carpeta — instala lo que falte (Salesforce CLI, Python,
   la dependencia `pdfplumber`) y confirma accesos (org MONEE, carpeta de OneDrive del banco).
2. Para el detalle técnico línea-por-línea de cada pipeline (estructura de archivos, reglas de
   negocio, qué significa cada código de retorno bancario, gotchas conocidos), usa los Skills de
   Claude Code ya incluidos en el repo: `.claude/skills/collections/SKILL.md` y
   `.claude/skills/cancelar-contratos/SKILL.md` — o ábrelos como texto plano si no usas Claude Code.
3. `CLAUDE.md` (raíz del repo) tiene todas las reglas de negocio confirmadas con el caso real que
   las originó — consúltalo antes de cambiar el comportamiento de cualquier script.
4. `BITACORA_HALLAZGOS_TECNICOS.md` y `TAREAS_PENDIENTES.md` (raíz del repo) — bugs ya
   diagnosticados y temas abiertos, para no repetir trabajo.

---

## 3. Cómo se mantiene al día

Esta carpeta es una **copia física**, no un symlink ni un submódulo — se decidió así a propósito
para que la entrega sea un paquete autocontenido y fácil de instalar. Consecuencia: cuando el
trabajo diario en `COLLECTIONS/` o `scripts/apex/ACH_TRANSMISION/` (la ubicación original, fuera de
esta carpeta) cambie, **hay que volver a copiar los archivos que cambiaron a `ENTREGA_JUAN/`** para
que esta entrega no quede desactualizada. No hay ningún proceso automático que lo haga — es un
paso manual, igual que cualquier otro commit.

**Decisión confirmada (2026-10-05): la entrega oficial a Juan es acceso al repo completo vía
Git** (no un ZIP aislado de esta carpeta). Con esto, Juan recibe automáticamente todo lo que esta
carpeta NO duplica a propósito: `MANUAL_TRASPASO.md`, `CLAUDE.md`, `BITACORA_HALLAZGOS_TECNICOS.md`,
`TAREAS_PENDIENTES.md`, `TAREAS_OCASIONALES.md`, los Skills (`.claude/skills/`), el metadata de
Salesforce (`force-app/`) y los scripts de `scripts/apex/` de Tareas Ocasionales — `ENTREGA_JUAN/`
sigue siendo útil como capa organizada de inicio rápido para el día a día (Procesos/Utilitarios),
no como el único contenedor del handoff.
