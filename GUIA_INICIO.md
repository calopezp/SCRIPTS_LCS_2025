# Guía de inicio — responsable nuevo del proceso de Collections

Para quien recibe el proceso de cobranza (Collections / transmisión ACH / cancelaciones) en su
propia máquina. Asume que eres administrador de Salesforce y tienes OneDrive de la empresa.
Nada de lo que sigue depende de la máquina ni de la cuenta de la persona anterior.

## 1. Instalar (una sola vez)

| Herramienta | Para qué | Comprobar |
|---|---|---|
| **Git for Windows** (incluye Git Bash) | Bajar/subir el repo y correr los `.sh` | `git --version` |
| **Python 3.12+** (python.org, marcar "Add to PATH") | Indexadores y reportes de `COLLECTIONS/` | `python3 --version` (en Git Bash) |
| Librería `pdfplumber` | Leer los PDF del banco | `python3 -m pip install pdfplumber` |
| **Salesforce CLI** (`sf`) | Todo acceso a Salesforce desde scripts | `sf --version` |
| **VS Code** + extensión **Claude Code** | Editar y trabajar con Claude sobre este repo | — |

> Si `python3` abre la Microsoft Store en vez de Python, desactiva los "alias de ejecución de
> aplicaciones" de Python en Configuración de Windows, o reinstala Python con "Add to PATH".

## 2. Conectar (una sola vez)

```bash
# 1) Clonar el repo (URL de la cuenta de GitHub de la empresa)
git clone <URL del repo> SCRIPTS_LCS_2025
cd SCRIPTS_LCS_2025
git remote -v            # anota el nombre del remoto (normalmente "origin")

# 2) Autenticar Salesforce producción con el alias EXACTO "MONEE" (los scripts lo usan fijo)
sf org login web -a MONEE -r https://monee.my.salesforce.com
sf org display -o MONEE  # debe mostrar tu usuario

# (opcional) sandbox
sf org login web -a PREPROD -r https://test.salesforce.com
```

**OneDrive:** sincroniza la carpeta compartida **`COMPILADO COLLECTIONS`** para que quede en la
**raíz** de tu OneDrive de empresa, con ese nombre exacto (si es una carpeta compartida contigo:
"Agregar acceso directo a Mis archivos" y luego dejar que se sincronice). Los scripts la
encuentran solos (`COLLECTIONS/lcs_paths.py`, vía `%OneDriveCommercial%`). Si la tienes en otro
lugar, define la variable de entorno `LCS_COLLECTIONS_DIR` con la ruta completa a la carpeta.

Comprobar que todo quedó bien (en Git Bash, desde la raíz del repo):

```bash
python3 -c "import sys; sys.path.insert(0,'COLLECTIONS'); import lcs_paths; r=lcs_paths.collections_root(); print(r, r.exists())"
```

Debe imprimir la ruta a `COMPILADO COLLECTIONS` y `True`.

## 3. Rutina diaria

Siempre empezar con `git pull` y terminar con commit + push, para que el índice y los reportes
queden en el repo y no solo en tu máquina.

| Cuándo | Qué | Cómo |
|---|---|---|
| Al empezar | Traer lo último | `git pull origin main` |
| Cada día hábil | Procesar reportes del banco (Returns, Check Collection, transmisiones ACH) + confirmar el cargue ACH del día anterior + correos de alerta | `cd COLLECTIONS` → `./run_daily_new_files.sh` (revisar el DRY RUN) → `./run_daily_new_files.sh apply` |
| Cada día hábil, ~antes de las 2:50 pm PR | Generar el/los archivos ACH para el banco y avisar por correo | `sf apex run -o MONEE --file "scripts/apex/ACH_TRANSMISION/A. Generar File Reporte ACH.apex"` y luego `... B. Enviar Correo Reporte ACH.apex` |
| Solo si un cargue confirmado nunca llegó al banco | Revertir ese cargue | `D. Revertir Cargue Reporte ACH.apex` (excepción, leer su encabezado) |
| Al terminar | Guardar el histórico en el repo | `git add <archivos>` (nunca `git add -A`) → `git commit` → `git push` |

El paso C (confirmar el cargue de ayer) ya corre solo dentro de `run_daily_new_files.sh`.

## 4. Dónde está el conocimiento

| Archivo | Qué tiene |
|---|---|
| `CLAUDE.md` | Reglas del negocio y del proceso (Rules 1-3 de Collections, R10/R11, regla de 6 meses, anotaciones obligatorias, deploys). **Leer antes de cambiar nada.** |
| `TAREAS_PENDIENTES.md` | Lo que quedó abierto |
| `TAREAS_OCASIONALES.md` | Scripts para requerimientos puntuales (activar contratos, LPF, contracargos, notas masivas...) |
| `BITACORA_HALLAZGOS_TECNICOS.md` | Bugs encontrados y cómo se resolvieron |
| `TRASPASO_PROCESO.md` | Checklist del traspaso (correos, jobs, permisos) |
| `.claude/skills/collections`, `.claude/skills/cancelar-contratos` | Detalle técnico que Claude Code carga solo al hablar de esos temas |

Con Claude Code abierto en esta carpeta puedes preguntar en lenguaje natural ("¿qué tenemos
pendiente?", "revisa el pago PY-…", "corre el proceso diario"); ya lee estos archivos.

## 5. ¿Dónde consulto si un pago fue transmitido al banco?

Desde el 1-oct-2026 los archivos de transmisión ya **no** se dejan en OneDrive a mano: los genera
el paso A directamente en Salesforce. Tres formas de consultarlo, de más simple a más completa:

1. **En el registro del pago en Salesforce:** campos `SM_Transmission_Date_ACH_File__c` /
   `SM_Date_ACH_Transmitted__c` y la lista relacionada de Transaction Logs (un registro por
   cada transmisión, con su fecha real).
2. **En OneDrive:** `COMPILADO COLLECTIONS\ACH Reportados\` (archivos hasta 1-oct-2026) y su
   subcarpeta `Desde Salesforce\` (los nuevos, copiados automáticamente cada vez que alguien corre
   el proceso diario).
3. **Desde el repo:** el índice combinado de ambas fuentes está en
   `COLLECTIONS/ACH_REPORTADOS/index/transmission_raw_log.csv` (una fila por pago y archivo).
   Para el estado según los reportes del banco: `python3 COLLECTIONS/buscar_payment.py PY-xxxxxxxx`;
   para el resumen de cobros de un contrato: `python3 COLLECTIONS/estado_cobros.py <ContractNumber>`.

## 6. Reglas que no hay que romper

- Todo script que escribe en Salesforce tiene modo **DRY RUN** por defecto: revisar la salida
  antes de aplicar.
- No reprocesar reportes de más de 2 meses sin una decisión explícita (Rule 2 en `CLAUDE.md`).
- Deploys de Apex a producción siempre con `--test-level RunSpecifiedTests --tests <clases>`.
- No tocar las clases de la migración de Chargent (`CLAUDE.md` sección 3).
