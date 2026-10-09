#!/bin/bash
# ==========================================================
# filtrar_errores.sh - TP3 Automatización y Scripting
# Alumna: Gisella Henríquez - Legajo: 5225
# Procesa un archivo syslog con awk, filtra las líneas con
# "error", "fail" o "critical" (sin distinguir mayúsculas)
# y genera un reporte de ancho fijo en
# logs/reporte_errores_5225.txt
# Uso: ./filtrar_errores.sh [archivo_syslog]
#      Sin parámetro usa /var/log/syslog, o el extracto de
#      recursos/ si syslog no se puede leer.
# Soporta los formatos de syslog clásico (Oct  9 10:00:00)
# y RFC 3339 de Ubuntu 24.04 (2026-10-09T10:00:00...).
# ==========================================================

LEGAJO="5225"
TOKEN="5225-1302"   # Token de Autenticidad del TP1

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_REPO="$(dirname "$DIR_SCRIPT")"
DIR_LOGS="$DIR_REPO/logs"
REPORTE="$DIR_LOGS/reporte_errores_${LEGAJO}.txt"
PRUEBA="$DIR_REPO/recursos/syslog_prueba.txt"

# ---------- Validar parámetros y elegir archivo de entrada ----------
if [[ $# -gt 1 ]]; then
    echo "Error: se acepta como máximo un parámetro." >&2
    echo "Uso: $0 [archivo_syslog]" >&2
    exit 2
fi

if [[ $# -eq 1 ]]; then
    ARCHIVO="$1"
elif [[ -r /var/log/syslog ]]; then
    ARCHIVO="/var/log/syslog"
else
    ARCHIVO="$PRUEBA"
fi

if [[ ! -f "$ARCHIVO" || ! -r "$ARCHIVO" ]]; then
    echo "Error: el archivo '$ARCHIVO' no existe o no se puede leer." >&2
    exit 3
fi

if [[ ! -s "$ARCHIVO" ]]; then
    echo "Error: el archivo '$ARCHIVO' está vacío." >&2
    exit 4
fi

if ! mkdir -p "$DIR_LOGS" 2>/dev/null; then
    echo "Error: no se pudo crear la carpeta $DIR_LOGS" >&2
    exit 1
fi

# ---------- Procesamiento con awk ----------
# tr elimina bytes nulos que a veces quedan en syslog tras apagados bruscos
tr -d '\000' < "$ARCHIVO" | awk \
    -v legajo="$LEGAJO" -v token="$TOKEN" \
    -v fuente="$ARCHIVO" -v generado="$(date '+%Y-%m-%d %H:%M:%S')" '
BEGIN {
    # Nombres de mes para convertir el formato numérico (RFC 3339)
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", MES, " ")
    linea = "--------------------------------------------------------------------------------------------"
    print "# Reporte de errores de syslog - Legajo: " legajo " | Token TP1: " token
    print "# Fuente: " fuente " | Generado: " generado
    print linea
    printf "%-6s  %-8s  %-20s  %s\n", "FECHA", "HORA", "PROCESO", "MENSAJE (50 car.)"
    print linea
    total = 0; descartadas = 0
}

# Filtro insensible a mayúsculas: se compara la línea en minúsculas
tolower($0) ~ /(error|fail|critical)/ {

    if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) {
        # Formato RFC 3339: 2026-10-09T09:50:01.588834-03:00 host proceso[pid]: mensaje
        fecha = MES[substr($1, 6, 2) + 0] " " substr($1, 9, 2)
        hora  = substr($1, 12, 8)
        iproc = 3
    } else if ($1 ~ /^[A-Z][a-z][a-z]$/ && $3 ~ /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) {
        # Formato clásico: Oct  9 09:50:01 host proceso[pid]: mensaje
        fecha = $1 " " sprintf("%02d", $2)
        hora  = $3
        iproc = 5
    } else {
        descartadas++   # línea con formato no reconocido
        next
    }

    # Proceso sin el PID entre corchetes ni los dos puntos finales
    proceso = $iproc
    sub(/\[[0-9]+\]/, "", proceso)
    sub(/:$/, "", proceso)

    # Mensaje: todos los campos posteriores al proceso
    mensaje = ""
    for (i = iproc + 1; i <= NF; i++)
        mensaje = mensaje (mensaje == "" ? "" : " ") $i

    printf "%-6s  %-8s  %-20s  %s\n", fecha, hora, substr(proceso, 1, 20), substr(mensaje, 1, 50)
    total++
}

END {
    print linea
    printf "Total de registros con error/fail/critical: %d\n", total
    if (descartadas > 0)
        printf "Líneas con formato no reconocido (omitidas): %d\n", descartadas
}' > "$REPORTE"

# Verificar que tr y awk terminaron bien
if [[ ${PIPESTATUS[0]} -ne 0 || ${PIPESTATUS[1]} -ne 0 ]]; then
    echo "Error: falló el procesamiento del archivo." >&2
    exit 5
fi

echo "Reporte generado en: $REPORTE"
echo
cat "$REPORTE"
exit 0
