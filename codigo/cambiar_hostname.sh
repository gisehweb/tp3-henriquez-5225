#!/bin/bash
# ==========================================================
# cambiar_hostname.sh - TP3 Automatización y Scripting
# Alumna: Gisella Henríquez - Legajo: 5225
# Cambia el hostname del sistema de forma segura modificando
# /etc/hostname y /etc/hosts con sed.
# Uso: sudo ./cambiar_hostname.sh curzas-alumno-<LEGAJO>
# ==========================================================

ARCH_HOSTNAME="/etc/hostname"
ARCH_HOSTS="/etc/hosts"
SUFIJO_BAK=".bak-$(date '+%Y%m%d-%H%M%S')"

# ---------- 1. Verificar privilegios de administrador ----------
if [[ $EUID -ne 0 ]]; then
    echo "Error: este script modifica archivos del sistema y requiere privilegios de root." >&2
    echo "Ejecútelo con: sudo $0 curzas-alumno-<LEGAJO>" >&2
    exit 1
fi

# ---------- 2. Validar argumento ----------
if [[ $# -ne 1 ]]; then
    echo "Error: se requiere exactamente un argumento (el nuevo hostname)." >&2
    echo "Uso: sudo $0 curzas-alumno-<LEGAJO>" >&2
    exit 2
fi

NUEVO="$1"

# Nomenclatura obligatoria: curzas-alumno-<legajo numérico>
if [[ ! "$NUEVO" =~ ^curzas-alumno-[0-9]+$ ]]; then
    echo "Error: '$NUEVO' no respeta la nomenclatura curzas-alumno-<LEGAJO> (legajo numérico)." >&2
    exit 3
fi

# Un hostname (etiqueta) puede tener como máximo 63 caracteres
if [[ ${#NUEVO} -gt 63 ]]; then
    echo "Error: el hostname no puede superar los 63 caracteres." >&2
    exit 3
fi

# ---------- 3. Obtener el nombre actual ----------
if [[ ! -f "$ARCH_HOSTNAME" || ! -f "$ARCH_HOSTS" ]]; then
    echo "Error: no se encontró $ARCH_HOSTNAME o $ARCH_HOSTS." >&2
    exit 4
fi

ANTERIOR="$(head -n 1 "$ARCH_HOSTNAME" | tr -d '[:space:]')"

if [[ -z "$ANTERIOR" ]]; then
    echo "Error: no se pudo leer el hostname actual desde $ARCH_HOSTNAME." >&2
    exit 4
fi

if [[ "$ANTERIOR" == "$NUEVO" ]]; then
    echo "El hostname ya es '$NUEVO'. No se realizaron cambios."
    exit 0
fi

echo "Hostname actual: $ANTERIOR"
echo "Hostname nuevo : $NUEVO"

# ---------- 4. Respaldo de los archivos ----------
if ! cp -p "$ARCH_HOSTNAME" "${ARCH_HOSTNAME}${SUFIJO_BAK}" || \
   ! cp -p "$ARCH_HOSTS" "${ARCH_HOSTS}${SUFIJO_BAK}"; then
    echo "Error: no se pudieron crear las copias de respaldo. No se modificó nada." >&2
    exit 5
fi
echo "Respaldos creados con sufijo $SUFIJO_BAK"

# Restaura los respaldos si algo falla
restaurar() {
    cp -p "${ARCH_HOSTNAME}${SUFIJO_BAK}" "$ARCH_HOSTNAME"
    cp -p "${ARCH_HOSTS}${SUFIJO_BAK}" "$ARCH_HOSTS"
    echo "Se restauraron los archivos originales." >&2
}

# Escapar caracteres especiales de regex en el nombre anterior (ej. puntos)
ANT_ESC="$(printf '%s' "$ANTERIOR" | sed 's/[.[\*^$/]/\\&/g')"

# ---------- 5. Actualizar /etc/hosts con sed ----------
# Reemplaza el nombre anterior solo como palabra completa (\b)
if grep -qw "$ANTERIOR" "$ARCH_HOSTS"; then
    sed -i "s/\b${ANT_ESC}\b/${NUEVO}/g" "$ARCH_HOSTS"
else
    # Si no había referencia, se agrega la línea estándar de Debian/Ubuntu
    echo -e "127.0.1.1\t${NUEVO}" >> "$ARCH_HOSTS"
fi

# ---------- 6. Actualizar /etc/hostname con sed ----------
sed -i "s/^${ANT_ESC}$/${NUEVO}/" "$ARCH_HOSTNAME"

# ---------- 7. Verificar ----------
if [[ "$(head -n 1 "$ARCH_HOSTNAME")" != "$NUEVO" ]] || ! grep -qw "$NUEVO" "$ARCH_HOSTS"; then
    echo "Error: la verificación de los archivos falló." >&2
    restaurar
    exit 6
fi

# ---------- 8. Aplicar al sistema en ejecución ----------
if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl set-hostname "$NUEVO"
else
    hostname "$NUEVO"
fi

echo "Hostname cambiado correctamente: $ANTERIOR -> $NUEVO"
echo "Referencia en $ARCH_HOSTS:"
grep -w "$NUEVO" "$ARCH_HOSTS"
echo "Se recomienda cerrar sesión o reiniciar para que todos los programas tomen el nuevo nombre."
exit 0
