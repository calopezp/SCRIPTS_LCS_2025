"""
daily_summary.py
------------------
Arma un resumen corto (totales trabajados + lo que falla/necesita revision)
a partir de los logs que run_daily_new_files.sh va guardando por paso, para
no tener que releer el log completo cada vez.

No re-ejecuta nada ni toca Salesforce -- solo lee texto y cuenta con regex.
Si algun patron no aparece en un log (paso saltado, formato distinto), lo
marca como "N/A" en vez de fallar.

Uso (llamado automaticamente al final de run_daily_new_files.sh):
    python3 daily_summary.py <carpeta_de_logs> <modo: dryrun|apply>
"""

import re
import sys
from pathlib import Path

# Los debug de Apex en este proyecto alternan '->'/'→ ' como prefijo, y
# el separador Exitos/Errores sale como '|', '&#124;' (entidad HTML) o '｜'
# (barra vertical ancha) segun el script -- todo variantes, mismo dato.
PIPE = r"(?:\||&#124;|｜)"


def _last_int(pattern, text, flags=re.IGNORECASE):
    matches = re.findall(pattern, text, flags)
    if not matches:
        return None
    return int(matches[-1])


def _last_pair(pattern, text, flags=re.IGNORECASE):
    matches = re.findall(pattern, text, flags)
    if not matches:
        return None
    a, b = matches[-1]
    return int(a), int(b)


def parse_apex_update_log(text):
    """Metricas comunes a los .apex que aplican un CSV (Returns/Collection/
    Transmission-dates/Timeout-accept): cuantas filas, cuantas se aplicaron,
    cuantas quedaron bloqueadas para revision manual, y el resultado real
    del DML (exitos/errores)."""
    return {
        "total_filas": _last_int(r"Total filas le[ií]das? del CSV:\s*(\d+)", text),
        # Nota: "dia(s)" trae un parentesis anidado dentro del texto que se
        # quiere capturar -- no cortar en el primer ')' que aparezca.
        "candidatos": _last_int(r"Candidatos \(ACH TRANSMITTED.*?sin reporte\):\s*(\d+)", text),
        "pendientes": _last_int(r"Pendientes de aplicar en esta corrida:\s*(\d+)", text),
        "ya_aplicados": _last_int(r"Ya aplicados anteriormente[^:]*:\s*(\d+)", text),
        "fuera_de_orden": _last_int(r"Descartados por ser mas viejos[^:]*:\s*(\d+)", text),
        "bloqueados_regresion": _last_int(r"ALERTA:\s*(\d+)\s*pago\(s\)", text),
        "bloqueados_cancelado": _last_int(r"Bloqueados por contrato Cancelado[^:]*:\s*(\d+)", text),
        "bloqueados_test_vip": _last_int(r"Bloqueados por contrato de Prueba/VIP:\s*(\d+)", text),
        "sin_match": _last_int(r"(?:Registros )?SIN match[^:]*:\s*(\d+)", text),
        "exitos_errores": _last_pair(
            r"(?:Exitos|Éxitos):\s*(\d+)\s*" + PIPE + r"\s*Errores:\s*(\d+)", text
        ),
    }


def fmt_apex_line(label, metrics):
    if metrics is None:
        return f"  {label}: (no corrio este paso)"
    total = metrics["total_filas"] if metrics["total_filas"] is not None else metrics["candidatos"]
    total_txt = str(total) if total is not None else "?"
    parts = [f"{total_txt} leidas"]
    if metrics["pendientes"] is not None:
        parts.append(f"{metrics['pendientes']} pendientes")
    ok, err = metrics["exitos_errores"] if metrics["exitos_errores"] else (0, 0)
    parts.append(f"{ok} aplicadas")
    parts.append(f"{err} errores")
    line = f"  {label}: " + " | ".join(parts)

    flags = []
    for key, tag in (
        ("bloqueados_regresion", "regresion"),
        ("bloqueados_cancelado", "contrato Cancelado"),
        ("bloqueados_test_vip", "Test/VIP"),
        ("sin_match", "sin match en Salesforce"),
    ):
        n = metrics.get(key)
        if n:
            flags.append(f"{n} bloqueados ({tag})")
    if flags:
        line += "  [!] " + ", ".join(flags)
    return line, err or 0, sum(metrics.get(k) or 0 for k in (
        "bloqueados_regresion", "bloqueados_cancelado", "bloqueados_test_vip", "sin_match"
    ))


def parse_notify_log(text):
    """Reportes de SM_ReturnCodeNotifier: cuentan lineas '- Contrato ' / '- PY-'
    en el cuerpo del correo si encontraron algo, o detectan el mensaje 'Sin
    contratos'/'Sin pagos' si no encontraron nada."""
    if re.search(r"Sin (contratos|pagos)", text):
        return 0
    hits = len(re.findall(r"^\s*-\s+(Contrato|PY-)", text, re.MULTILINE))
    return hits if hits else None


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return None


def main():
    if len(sys.argv) < 3:
        print("Uso: daily_summary.py <carpeta_de_logs> <modo>")
        sys.exit(1)

    log_dir = Path(sys.argv[1])
    mode = sys.argv[2]

    total_applied = 0
    total_errors = 0
    total_review = 0
    lines = []

    for label, filename in (
        ("Returns       ", "returns.log"),
        ("Check Collection", "collections.log"),
        ("ACH Reportados (fechas)", "transmission.log"),
        ("Timeout accept (15d sin reporte)", "timeout.log"),
    ):
        text = read(log_dir / filename)
        if text is None:
            lines.append(f"  {label}: (sin archivos nuevos / no aplico)")
            continue
        metrics = parse_apex_update_log(text)
        result = fmt_apex_line(label, metrics)
        if isinstance(result, tuple):
            line, err, review = result
            lines.append(line)
            total_errors += err
            total_review += review
            ok = metrics["exitos_errores"][0] if metrics["exitos_errores"] else 0
            total_applied += ok
        else:
            lines.append(result)

    notify_lines = []
    notify_failures = []
    for label, filename in (
        ("R02 (cuenta cerrada)", "r02.log"),
        ("R10 (cliente no autoriza)", "r10.log"),
        ("R04/R13 (cuenta/routing invalido)", "invalid_account.log"),
        ("R07 (autorizacion revocada)", "r07.log"),
        ("R16 (cuenta congelada)", "r16.log"),
        ("Reversiones por timeout", "timeout_reversal.log"),
    ):
        text = read(log_dir / filename)
        if text is None:
            continue
        count = parse_notify_log(text)
        count_txt = str(count) if count is not None else "?"
        notify_lines.append(f"  {label}: {count_txt} hallazgo(s)")

    print("=" * 60)
    print(f" RESUMEN DE LA CORRIDA (modo: {mode})")
    print("=" * 60)
    print("Pipelines:")
    for l in lines:
        print(l)

    if notify_lines:
        print("")
        print("Correos enviados (contratos/pagos sin resolver por codigo):")
        for l in notify_lines:
            print(l)

    print("")
    print(f"TOTAL APLICADO: {total_applied} pago(s) actualizado(s)")
    if total_errors:
        print(f"TOTAL ERRORES:  {total_errors}  <-- REVISAR ARRIBA EN EL LOG COMPLETO")
    else:
        print("TOTAL ERRORES:  0")

    if total_review:
        print(f"")
        print(f"[!] {total_review} registro(s) necesitan revision manual (regresion / contrato Cancelado / Test-VIP / sin match)")
        print(f"    -> buscar 'ALERTA' o 'Bloqueados' en el log completo, o usar buscar_payment.py")

    print("=" * 60)


if __name__ == "__main__":
    main()
