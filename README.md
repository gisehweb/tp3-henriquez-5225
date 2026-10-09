# TP3 - Cron, At, Systemd Timers y Procesamiento de Texto

- **Universidad Nacional del Comahue - CURZA**
- **Carrera:** Tecnicatura Superior en Administración de Sistemas y Software Libre
- **Materia:** Automatización y Scripting
- **Alumna:** Gisella Henríquez - **Legajo:** 5225
- **Token de Autenticidad (TP1):** 5225-1302
- **Entorno:** Ubuntu Desktop 24.04 (VirtualBox), Bash 5.2

---

## Estructura del repositorio:
tp3-henriquez-5225/
-├── README.md
- ├── recursos/
- │ └── syslog_prueba.txt # Extracto de /var/log/syslog (1000 líneas)
-├── config/
- │ ├── monitoreo_5225.service
- │ └── monitoreo_5225.timer
- ├── codigo/
- │ ├── monitorear_usuarios.sh
- │ ├── descarga_programada.sh
- │ ├── diagnostico_red.sh
-│ ├── cambiar_hostname.sh
- │ └── filtrar_errores.sh
- ├── descargas/ # Destino de descarga_programada.sh (ignorado por git)
- └── logs/
- ├── usuarios_activos_5225.log
- ├── descargas_5225.log
- ├── ping_report_5225.log
 - └── reporte_errores_5225.txt

---

## Tarea 1: Planificación con Cron

`monitorear_usuarios.sh` registra la fecha y hora, la cantidad de usuarios distintos conectados y el total de sesiones (`who`) en `logs/usuarios_activos_5225.log`. El log comienza con una línea que incluye el legajo y el token del TP1.

Línea agregada con `crontab -e` (cada 10 minutos, de lunes a viernes):
*/10 * * * 1-5 /home/gisellah/tp3-henriquez-5225/codigo/monitorear_usuarios.sh

| Campo | Valor | Significado |
|---|---|---|
| minuto | `*/10` | cada 10 minutos |
| hora | `*` | todas |
| día del mes | `*` | todos |
| mes | `*` | todos |
| día de la semana | `1-5` | lunes a viernes |

Como cron ejecuta con un entorno mínimo y desde otro directorio, el script calcula sus rutas a partir de su propia ubicación (`BASH_SOURCE`).

**Crontab activo (`crontab -l`):**

<img width="761" height="499" alt="image" src="https://github.com/user-attachments/assets/dd02206e-71fb-48ae-99d2-15f2ca32abe5" />


**Log generado y ejecución registrada por cron en syslog:**

<img width="780" height="298" alt="image" src="https://github.com/user-attachments/assets/ceaed2cc-83c6-4feb-a120-6d1b062434a2" />


---

## Tarea 2: Ejecución única con At

`descarga_programada.sh` recibe la URL de un archivo comprimido y lo descarga en `descargas/` con `wget` (o `curl` si `wget` no está instalado). Valida la cantidad de parámetros, el formato de la URL (`http://` o `https://`) y la extensión del archivo (`.zip`, `.tar.gz`, `.tgz`, `.tar.xz`, etc.). Si una descarga queda incompleta, la elimina. Registra cada operación en `logs/descargas_5225.log`.

Programación con `at`:

```bash
# Próximo viernes a las 23:30
echo "/home/gisellah/tp3-henriquez-5225/codigo/descarga_programada.sh https://ftp.gnu.org/gnu/hello/hello-2.12.tar.gz" | at 23:30 2026-10-09

# Prueba en 2 minutos
echo "/home/gisellah/tp3-henriquez-5225/codigo/descarga_programada.sh https://github.com/gisehweb/tp3-henriquez-5225/archive/refs/heads/main.zip" | at now + 2 minutes
```

**Cola de tareas pendientes (`atq`):**

<img width="691" height="228" alt="image" src="https://github.com/user-attachments/assets/59be182c-ab6b-4a9d-9210-d7236cec61a3" />


**Ejecución de la tarea de prueba:**

<img width="706" height="296" alt="image" src="https://github.com/user-attachments/assets/5c561b35-45b1-474a-958a-95ddc0b99db6" />


---

## Tarea 3: Migración a Systemd Timers

- `config/monitoreo_5225.service`: servicio `Type=oneshot` que ejecuta `codigo/diagnostico_red.sh` con el usuario `gisellah`.
- `config/monitoreo_5225.timer`: `OnBootSec=1min` (primera ejecución) y `OnUnitActiveSec=5m` (cada 5 minutos desde la última activación).
- `codigo/diagnostico_red.sh`: obtiene el gateway de la tabla de rutas (`ip route`), le hace 4 pings y registra estado, pérdida y tiempo promedio en `logs/ping_report_5225.log`.

Se agregó `OnBootSec` porque `OnUnitActiveSec` cuenta desde la última ejecución del servicio. Si el servicio todavía no se ejecutó nunca, el timer no tiene una referencia desde la cual contar.

### Comandos de instalación, habilitación y verificación

```bash
# 1. Instalar: crea enlaces simbólicos en /etc/systemd/system/
sudo systemctl link /home/gisellah/tp3-henriquez-5225/config/monitoreo_5225.service \
                    /home/gisellah/tp3-henriquez-5225/config/monitoreo_5225.timer

# 2. Recargar la configuración de systemd
sudo systemctl daemon-reload

# 3. Habilitar el timer en el arranque e iniciarlo ahora
sudo systemctl enable --now monitoreo_5225.timer

# 4. Iniciar manualmente (si no se usó --now)
sudo systemctl start monitoreo_5225.timer

# 5. Verificar estado
systemctl status monitoreo_5225.timer
systemctl status monitoreo_5225.service
systemctl list-timers monitoreo_5225.timer -l

# 6. Ver los logs en tiempo real
journalctl -u monitoreo_5225.service -f
```

**Timer activo, con la última y la próxima ejecución:**

<img width="738" height="460" alt="image" src="https://github.com/user-attachments/assets/e833694b-0050-418a-be29-abc6ea144cdd" />


**Logs en tiempo real (ejecuciones con 5 minutos de diferencia):**

<img width="784" height="423" alt="image" src="https://github.com/user-attachments/assets/4a0c713c-109a-4ff7-90ed-a0705129e370" />


---

## Tarea 4: Configuración segura de hostname

Uso: `sudo ./codigo/cambiar_hostname.sh curzas-alumno-5225`

1. Verifica que se ejecute como root (`$EUID -ne 0`). Si no, termina con un mensaje de error.
2. Valida que haya un único argumento y que respete la nomenclatura `curzas-alumno-<legajo numérico>`, con un máximo de 63 caracteres.
3. Crea copias de respaldo de `/etc/hostname` y `/etc/hosts`, con fecha y hora en el sufijo.
4. Actualiza `/etc/hosts` con `sed` reemplazando el nombre anterior como palabra completa. Se hace primero para evitar el aviso `sudo: unable to resolve host`.
5. Actualiza `/etc/hostname` con `sed`.
6. Verifica los cambios. Si algo falla, restaura los respaldos.
7. Aplica el nombre al sistema en ejecución con `hostnamectl`.

<img width="697" height="213" alt="image" src="https://github.com/user-attachments/assets/b544f422-e765-40cb-91bc-e0aa2f81c774" />
<img width="697" height="213" alt="image" src="https://github.com/user-attachments/assets/c514069b-6255-4ab3-98f5-9c2ba60e1e76" />
<img width="800" height="119" alt="image" src="https://github.com/user-attachments/assets/4fcc6eaf-a6b1-426b-9375-ddb0d3e60ac3" />
<img width="700" height="316" alt="image" src="https://github.com/user-attachments/assets/c02e96c2-1300-420c-9462-4276c2aaecd3" />



---

## Tarea 5: Parser de syslog

Uso: `./codigo/filtrar_errores.sh [archivo]`. Sin parámetro usa `/var/log/syslog`.

- Filtra con `awk` las líneas que contienen `error`, `fail` o `critical`, sin distinguir mayúsculas (`tolower($0)`).
- Genera un reporte de ancho fijo con: **Fecha** (mes y día), **Hora** (HH:MM:SS), **Proceso** (sin el PID entre corchetes) y **Mensaje** (primeros 50 caracteres).
- Guarda el resultado en `logs/reporte_errores_5225.txt`.

**Aclaración:** Ubuntu 24.04 registra el syslog en formato RFC 3339 (`2026-10-09T10:41:37.123456-03:00`), no en el formato clásico (`Oct  9 10:41:37`). El script reconoce ambos formatos y convierte el mes numérico a su abreviatura. Además, elimina con `tr` los bytes nulos que pueden quedar en el archivo después de un apagado brusco de la VM.
<img width="738" height="383" alt="image" src="https://github.com/user-attachments/assets/7c522cff-cced-46f3-8e2f-a0450992d33d" />

<img width="576" height="400" alt="image" src="https://github.com/user-attachments/assets/48a63129-a95e-4418-a11a-71cfab534462" />



---

## Consideraciones generales

- Todos los scripts validan sus parámetros y terminan con códigos de salida diferenciados (1 a 6) y mensajes en `stderr`, sin abortar de forma inesperada.
- Los scripts calculan sus rutas en forma absoluta para funcionar desde cron, at y systemd.
- No se utilizó código externo.
EOF
