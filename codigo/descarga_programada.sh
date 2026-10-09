#!/bin/bash
# ==========================================================
# descarga_programada.sh - TP3 Automatización y Scripting
# Alumna: Gisella Henríquez - Legajo: 5225
# Descarga un archivo comprimido desde una URL (parámetro)
# a la carpeta descargas/ del repositorio.
# Uso: ./descarga_programada.sh <URL_archivo_comprimido>
# ==========================================================

LEGAJO="5225"

# Rutas absolutas: at/cron pueden ejecutar desde otro directorio
DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIR_REPO="$(dirname "$DIR_SCRIPT")"
DIR_DESC="$DIR_REPO/descargas"
DIR_LOGS="$DIR_REPO/logs"
LOG="$DIR_LOGS/descargas_${LEGAJO}.log"

# Extensiones de archivos comprimidos aceptadas
EXT_RE='\.(zip|tar|tar\.gz|tgz|tar\.bz2|tbz2|tar\.xz|txz|gz|bz2|xz|7z|rar)$'

# Escribe un mensaje con fecha en pantalla y en el log
registrar() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG"
}

# Crear carpetas necesarias
if ! mkdir -p "$DIR_DESC" "$DIR_LOGS" 2>/dev/null; then
    echo "Error: no se pudieron crear las carpetas de trabajo" >&2
    exit 1
fi

# Validación 1: exactamente un argumento
if [[ $# -ne 1 ]]; then
    echo "Error: se requiere exactamente una URL como parámetro." >&2
    echo "Uso: $0 <URL_archivo_comprimido>" >&2
    exit 2
fi

URL="$1"

# Validación 2: la URL debe empezar con http:// o https://
if [[ ! "$URL" =~ ^https?://[^[:space:]]+$ ]]; then
    registrar "ERROR: URL inválida: $URL" >&2
    exit 3
fi

# Nombre del archivo a partir de la URL (sin parámetros ?...)
ARCHIVO="$(basename "${URL%%\?*}")"

# Validación 3: debe ser un archivo comprimido
if [[ ! "$ARCHIVO" =~ $EXT_RE ]]; then
    registrar "ERROR: '$ARCHIVO' no parece un archivo comprimido" >&2
    exit 4
fi

DESTINO="$DIR_DESC/$ARCHIVO"
registrar "Iniciando descarga de $URL"

# Descargar con wget; si no está instalado, con curl
if command -v wget >/dev/null 2>&1; then
    wget -q -O "$DESTINO" "$URL"
    RC=$?
elif command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$DESTINO" "$URL"
    RC=$?
else
    registrar "ERROR: no se encontró wget ni curl" >&2
    exit 5
fi

# Verificar el resultado
if [[ $RC -eq 0 && -s "$DESTINO" ]]; then
    TAMANIO="$(du -h "$DESTINO" | cut -f1)"
    registrar "OK: descargado $ARCHIVO ($TAMANIO) en descargas/"
else
    rm -f "$DESTINO"   # eliminar descarga incompleta
    registrar "ERROR: falló la descarga (código $RC)" >&2
    exit 6
fi
