# Dictado por voz (Handy)

Handy es un transcriptor local (Tauri + Rust, sin nube) que convierte lo que
hablás en texto y lo escribe en la ventana enfocada: apretás el atajo, hablás,
el texto aparece donde tenías el cursor. No manda audio a ningún lado y no
necesita cuenta.

- Proyecto: <https://github.com/cjpais/Handy>
- Documentación de modelos: <https://handy.computer/docs/models>
- Versión instalada por el repo: **0.9.8** (pinneada en
  `scripts/12-setup-handy.sh` con SHA-256 verificado)

## Por qué este motor y este modelo

Handy no incluye un motor propio: es un frente amigable para
`transcribe.cpp` (el linaje de whisper.cpp) y acepta varios modelos. Para
español rioplatense la decisión es:

| Modelo | WER español (FLEURS) | Idioma fijable | VRAM en la GTX 1060 3 GB |
|---|---|---|---|
| **Whisper Large v3** (q5_K_M) | 2,70 % | **sí** | ~1,55 GB, entra |
| Whisper Large v3 Turbo (q8) | 3,12 % | sí | ~0,83 GB, entra |
| Parakeet TDT 0.6B v3 | 3,06 % | **no** (autodetecta) | CPU |

El idioma fijable es lo que decide: ningún modelo trae un `es-AR`, todos usan
español genérico y el modo `auto` a veces se va a portugués o italiano con
audio ruidoso. Con **Whisper Large v3** podés clavar `language=es` y, si hace
falta, cargar vocabulario propio en Ajustes → *Custom words* (nombres,
herramientas, "laburo", "che", lo que aparezca mal seguido).

Límites honestos: el acento argentino se degrada en habla espontánea y
lunfardo (yeísmo rehilado, voseo), más que en lectura. Lo que ayuda: modelo
grande, idioma fijado, VAD activo (menos silencio = menos alucinación) y
corregir con *Custom words* en vez de pelear con el modelo.

## Instalación

Por el instalador (recomendado):

```bash
./install.sh     # elegir el componente "Dictado por voz (Handy)"
```

Ese componente corre dos pasos, que también se pueden ejecutar sueltos:

```bash
./scripts/02-install-packages.sh handy.txt   # dependencias (zypper)
./scripts/12-setup-handy.sh                  # RPM de GitHub + ajustes
```

`12-setup-handy.sh` baja `Handy-0.9.8-1.x86_64.rpm` del release oficial,
compara el SHA-256 contra el pin del script y lo instala con
`zypper -n in --allow-unsigned-rpm` (el RPM no está firmado con llaves de
openSUSE). Si ya está instalado, no hace nada; `--force` reinstala.

Después del install, una sola vez, en la GUI:

1. Abrir Handy y elegir el modelo **Whisper Large v3** (se descarga a
   `~/.local/share/com.pais.handy/models/`, ~1,55 GB).
2. Ajustes → idioma **Spanish**, método de pegado **Clipboard**.

Los modelos **no** van al repo: pesan GB y son descargables.

## Atajos

| Entorno | Atajo | Dónde se define |
|---|---|---|
| sway | `Super+Shift+d` | `config/sway/keybindings/applications.conf` |
| i3 | `Super+Shift+d` | `config/i3/config.d/60-handy.conf` |

Ambos ejecutan `handy --toggle-transcription`: el primer toque arranca la
grabación, el segundo la corta y escribe el texto. En Wayland el hotkey
interno de Handy no puede capturar teclas fuera de su propia ventana, por eso
el atajo vive en el compositor y usa la CLI (que le habla a la instancia
residente en la bandeja). La instancia residente la levanta el autostart de
cada WM (`handy --start-hidden`).

i3 no tenía configuración propia en esta máquina: corre con la de
`/etc/i3/config`. `config/i3/config` la hereda con `include /etc/i3/config` y
suma sólo los archivos de `config/i3/config.d/`, así las actualizaciones del
paquete i3 siguen llegando solas. Validar sin arrancar i3:

```bash
i3 -C -c ~/.config/i3/config
```

## Ajustes versionados

`config/home/.local/share/com.pais.handy/settings_store.json` (Handy guarda
sus ajustes en el directorio de **datos**, no en `~/.config`). Lo que se
fija desde el repo:

| Clave | Valor | Por qué |
|---|---|---|
| `selected_language` | `es` | evita el autodetectarse a portugués/italiano |
| `selected_model` | `whisper-large-v3-Q5_K_M` | mejor WER en español y con idioma fijable |
| `paste_method` | `ctrl_v` | pega por portapapeles: no se comen los acentos ni las mayúsculas |
| `typing_tool` | `auto` | usa `wtype` en sway y `xdotool` en i3 según lo instalado |
| `app_language` | `es-ES` | interfaz en español |
| `vad_enabled` | `true` | recorta silencios (menos alucinaciones) |

El resto de las claves las completa la app con sus defaults; Handy mezcla lo
que encuentra en el archivo con su esquema.

## Micrófono

Handy usa el micrófono por defecto del sistema (PipeWire). Verificación:

```bash
pactl get-default-source          # debería ser tu micrófono, no un .monitor
pactl list short sources          # fuentes disponibles (descartá los *.monitor)
```

Prueba de captura real (4 s), útil para descartar que el micro esté mudo:

```bash
parecord --channels=1 --rate=16000 --format=s16le /tmp/mic.wav &
sleep 4; kill %1
pw-play /tmp/mic.wav              # escuchar lo grabado
```

En esta máquina la fuente por defecto es el headset USB *VSG Singularity*.
Si el nivel de entrada queda bajo, ajustá con `pavucontrol` (pestaña
*Entrada*) o:

```bash
pactl set-source-volume @DEFAULT_SOURCE@ 100%
```

## Verificación sin GUI

Handy tiene CLI propia, que sirve para comprobar que el binario, las
bibliotecas y la GPU funcionan:

```bash
handy --list-devices                        # debe listar Vulkan0 y CPU
handy --list-models | grep -i whisper       # IDs exactos de modelos
handy --transcribe-file /tmp/mic.wav --json # transcribir un WAV 16 kHz mono
```

`--list-devices` mostrando `Vulkan0` confirma que la GTX 1060 está disponible
para el modelo (vía Vulkan, sin necesidad de CUDA ni de `nvcc`).

## Problemas conocidos

- **El texto sale con letras cambiadas o sin mayúsculas.** Es el tipeo
  simulado en Wayland. Ya se evita con `paste_method: ctrl_v`; si pasa en una
  terminal, pegá con `Ctrl+Shift+V`.
- **El texto aparece en otra ventana.** Ajustes → *Overlay Position* →
  `None`.
- **El atajo no hace nada en sway.** Verificá que Handy esté corriendo
  (`pgrep -x handy`) o arrancalo con `handy --start-hidden`. El binding del
  compositor no funciona si no hay instancia viva.
- **No uses `dotool`/`ydotool` acá.** Requieren sumar el usuario al grupo
  `input`, y eso deja que *cualquier* aplicación lea todo lo que escribís.
  Con `wtype` (wayland) y `xdotool` (x11) alcanza y no cambia permisos.

## Desinstalar

```bash
sudo zypper rm Handy
rm -rf ~/.local/share/com.pais.handy     # ajustes, modelos e historial
```
