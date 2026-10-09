#!/bin/bash
# ==========================================================
# monitorear_usuarios.sh - TP3 Automatización y Scripting
# Alumna: Gisella Henríquez - Legajo: 5225
# Registra la fecha/hora y la cantidad de usuarios conectados
# en un log acumulativo. Pensado para ejecutarse desde cron.
# ==========================================================

LEGAJO="5225"
TOKEN="5225-1302"   # Token de Autenticidad generado en el TP1

# Cron no ejecuta desde la carpeta del repo, por eso las rutas
# se calculan a partir de la ubicación real del script.
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_REPO="$(dirname "$DIR_SCRIPT")"
DIR_LOGS="$DIR_REPO/logs"
LOG="$DIR_LOGS/usuarios_activos_${LEGAJO}.log"

# Crear la carpeta de logs si no existe
if ! mkdir -p "$DIR_LOGS" 2>/dev/null; then
    echo "Error: no se pudo crear la carpeta $DIR_LOGS" >&2
    exit 1
fi

# Encabezado con legajo y token, solo si el log no existe o está vacío
if [[ ! -s "$LOG" ]]; then
    echo "# Legajo: $LEGAJO | Token TP1: $TOKEN" >> "$LOG"
fi

# Fecha y hora actual
FECHA="$(date '+%Y-%m-%d %H:%M:%S')"

# who muestra una línea por sesión abierta:
#  - USUARIOS: usuarios distintos conectados
#  - SESIONES: total de sesiones (un usuario puede tener varias)
USUARIOS="$(who | awk '{print $1}' | sort -u | wc -l)"
SESIONES="$(who | wc -l)"

# Anexar el registro al log acumulativo
echo "$FECHA | usuarios activos: $USUARIOS | sesiones: $SESIONES" >> "$LOG"
