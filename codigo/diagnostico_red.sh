#!/bin/bash
# ==========================================================
# diagnostico_red.sh - TP3 Automatización y Scripting
# Alumna: Gisella Henríquez - Legajo: 5225
# Hace ping al gateway local y guarda el resultado en
# logs/ping_report_5225.log. Lo ejecuta systemd
# (monitoreo_5225.service) mediante un timer cada 5 minutos.
# ==========================================================

LEGAJO="5225"
TOKEN="5225-1302"   # Token de Autenticidad del TP1
CANT_PINGS=4

# Rutas absolutas: systemd no ejecuta desde la carpeta del repo
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_REPO="$(dirname "$DIR_SCRIPT")"
DIR_LOGS="$DIR_REPO/logs"
LOG="$DIR_LOGS/ping_report_${LEGAJO}.log"

# Escribe en pantalla (journalctl) y en el log
registrar() {
    echo "$1" | tee -a "$LOG"
}

if ! mkdir -p "$DIR_LOGS" 2>/dev/null; then
    echo "Error: no se pudo crear la carpeta $DIR_LOGS" >&2
    exit 1
fi

# Encabezado solo la primera vez
if [[ ! -s "$LOG" ]]; then
    echo "# Legajo: $LEGAJO | Token TP1: $TOKEN" >> "$LOG"
fi

FECHA="$(date '+%Y-%m-%d %H:%M:%S')"

# Obtener el gateway desde la tabla de rutas (línea "default via X")
GATEWAY="$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')"

# Validar que se obtuvo una dirección IPv4
if [[ ! "$GATEWAY" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    registrar "$FECHA | ERROR: no se encontró un gateway por defecto"
    exit 1
fi

# Ping: -c cantidad de paquetes, -W espera máxima por respuesta (seg)
SALIDA="$(ping -c "$CANT_PINGS" -W 2 "$GATEWAY" 2>&1)"
RC=$?

# Resumen: paquetes perdidos y tiempo promedio
PERDIDA="$(echo "$SALIDA" | grep -oE '[0-9]+% packet loss' | cut -d' ' -f1)"
PROMEDIO="$(echo "$SALIDA" | awk -F'/' '/^rtt|^round-trip/ {print $5 " ms"}')"

if [[ $RC -eq 0 ]]; then
    registrar "$FECHA | gateway $GATEWAY | ESTADO: OK | pérdida: ${PERDIDA:-?} | promedio: ${PROMEDIO:-?}"
else
    # Sin respuesta no es un error del script: se registra y termina bien
    registrar "$FECHA | gateway $GATEWAY | ESTADO: SIN RESPUESTA | pérdida: ${PERDIDA:-100%}"
fi

exit 0
