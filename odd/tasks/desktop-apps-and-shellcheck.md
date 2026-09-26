# Apps de escritorio Wayland + shellcheck

## Objetivo
1. AGREGAR a `packages/` el listado curado de apps nativas Wayland que reclamó el
   usuario, incluyendo TODAS las alternativas de cada categoría.
2. AGREGAR `shellcheck` como herramienta de lint para que `install.sh` lo resuelva siempre.
3. INTEGRAR todo en `main` y eliminar las ramas feature locales.

## Problema
- El escritorio Sway tenía infraestructura pero faltaban las apps de uso diario:
  sin visor de PDF, sin reproductor de video, sin gestor de archivos CLI, sin navegador.
  `foot` estaba como única terminal y no había alternativa.
- `shellcheck` se invocó manualmente en sesiones anteriores pero no estaba
  declarado en ningún `packages/*.txt`, así que `install.sh` no lo garantizaba.
- `firefox` NO existe con ese nombre en openSUSE Tumbleweed. El paquete real es
  `MozillaFirefox`. Pedir `firefox` en un `zypper in` aborta la instalación.
- Los plugins de Thunar (`thunar-plugin-preview`, `thunar-plugin-archive`,
  `thunar-plugin-archive`, `thunar-gtk-toolbox`, `thunar-plugin-enum-thunar`) NO existen
  en los repos habilitados. Thunar queda como gestor de archivos pelado.

## Por qué
El objetivo declarado: "un entorno de escritorio completo y funcional para el día a día
en Sway y openSUSE Tumbleweed", eligiendo apps nativas de Wayland (evitando XWayland)
y coherentes con un tiling window manager. El usuario decidió explícitamente instalar
TODAS las alternativas en vez de solo la principal, para poder cambiar de opinión
sin volver a abrir zypper.

## Alcance autorizado (y ejecutado)
- `packages/desktop-sway.txt` — agregar 14 paquetes
- `packages/dev-core.txt` — agregar `shellcheck`
- `main` — integrar y pushear
- Ramas feature locales — eliminar tras integrar

## Paquetes agregados a `desktop-sway.txt` (13 nuevos, 25 → 38)
| Categoría | Paquetes |
|---|---|
| Navegador | `MozillaFirefox` |
| Thunar automount | `thunar-volman` |
| Visor de imagen | `imv`, `swayimg` |
| Video | `mpv` |
| PDF | `zathura`, `zathura-plugin-pdf-poppler`, `evince` |
| Terminal | `alacritty`, `wezterm` |
| Gestor de archivos CLI | `yazi`, `ranger` |
| Tematización GTK | `nwg-look` |

## Paquetes YA presentes — NO duplicados
`foot`, `wl-clipboard`, `grim`, `slurp`, `pavucontrol`, `NetworkManager-applet`,
`thunar`, `swappy`, `cliphist`, `xwayland`, `waybar`, `wofi`, `swaybg`, `swaylock`,
`swayidle`, `SwayNotificationCenter`, `brightnessctl`, `playerctl`, `wob`, `kanshi`,
`feh`, `swaync`, `libnotify-tools`, `wf-recorder`.

## Verificación de disponibilidad
Cada paquete fue validado contra los repos REALES habilitados de la máquina antes de
escribir nada, con `zypper search -t package --match-exact`. Los 14 candidatos existen.
`firefox` NO existe; `MozillaFirefox` sí.

## Tareas
- [x] T1 Verificar disponibilidad real de cada candidato con zypper
- [x] T2 Detectar y corregir el nombre de paquete de Firefox (MozillaFirefox)
- [x] T3 Agregar 13 paquetes a `packages/desktop-sway.txt` (25 → 38)
- [x] T4 Agregar `shellcheck` a `packages/dev-core.txt`
- [x] T5 Verificar que los comentarios en los .txt son manejados por el instalador
- [x] T6 Verificar que no se duplicó ningún paquete ya presente
- [ ] T7 Instalar `shellcheck` en la máquina (BLOQUEADO: sudo requiere password)
- [ ] T8 Merge a `main` + push
- [ ] T9 Eliminar ramas feature locales

## Criterios de aceptación
- [x] Cada paquete en `desktop-sway.txt` y `dev-core.txt` existe en un repo habilitado
- [x] Ningún nombre de paquete duplicado dentro de un mismo archivo
- [x] Ningún paquete agregado que ya estuviera presente
- [x] Los comentarios no rompen el parser de `02-install-packages.sh` (línea 35 los strip)
- [ ] `shellcheck` instalado y ejecutable

## Riesgos y deuda conocida
- **`02-install-packages.sh` instala TODO el archivo en un solo `zypper in` (línea 48)
  con `set -euo pipefail` (línea 10).** Un solo paquete inválido aborta los ~40.
  `desktop-sway.txt` pasó de 26 a 40 líneas sin ningún aislamiento de fallos.
  La protección "warn y seguir" que se agregó a `03-nvidia-setup.sh` NO existe acá.
  Recomendado: instalar en lotes o tolerar fallos por paquete. FUERA DE ALCANCE.
- Thunar sin plugins: no hay preview, ni archive, ni enumerated-files disponibles.
- `MozillaFirefox` no se synchronize con el snap de Firefox; el nombre está
  verificado contra el repo pero conviene confirmarlo tras la primera instalación.
- Las alternativas duplican funcionalidad a propósito (decisión del usuario).
  `alacritty` y `wezterm` conviven con `foot` ya instalado.

## Checks aplicables
- `bash -n` sobre los scripts de shell tocados (ninguno en este cambio: solo data files)
- Verificación de disponibilidad: `zypper search -t package --match-exact <pkg>`
- Verificación de duplicados: recuento de nombres en cada `packages/*.txt`
- Revisión del parser: `scripts/02-install-packages.sh:33-39`
