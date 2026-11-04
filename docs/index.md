# Documentación

Índice de documentación del proyecto de dotfiles.

## Contenido

- [Arquitectura del proyecto](#arquitectura-del-proyecto)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Diagramas](#diagramas)
- [Referencia](#referencia)
- [Ruta de desarrollo](#ruta-de-desarrollo)

## Arquitectura del proyecto

Este repositorio no solo guarda dotfiles: incluye un instalador que prepara un sistema **openSUSE Tumbleweed** desde una instalación limpia, gestionando repositorios, paquetes (zypper), controladores NVIDIA y las configuraciones del usuario.

| Ruta | Propósito |
|---|---|
| `install.sh` | Orquestador principal con interfaz TUI (gum) |
| `scripts/` | Scripts individuales, ejecutables de forma independiente |
| `packages/` | Archivos `.txt` planos con paquetes (1 por línea): zypper o appids Flatpak |
| `config/` | Configuraciones de copia directa (cada app a `~/.config/<app>`) |
| `docs/` | Documentación y diagramas (Mermaid en `.mmd`) |

### `packages/`

Cada archivo de texto agrupa paquetes por componente, bajo un convenio doble:

- `*.txt` planos con paquetes zypper (1 por línea); el script
  `scripts/02-install-packages.sh` los recorre línea por línea y se ignoran
  las líneas que empiezan por `#`.
- `flatpak-apps.txt` con appids de Flathub (1 por línea) que NO pasa por
  zypper: lo instala `scripts/02b-install-flatpak.sh`, que comprueba la
  presencia de flatpak antes de tocar flathub y registra el remote `flathub`
  con `--if-not-exists`.

### Aplicaciones Flatpak: elegir cuáles

Flatpak está en el menú principal del instalador (`Instalar aplicaciones
Flatpak`, sin instalar nada más) y como componente `Aplicaciones Flatpak` en la
selección múltiple. En los dos casos se eligen las apps del catálogo de a una
(gum `--no-limit`, `Espacio` para marcar, `Enter` para confirmar); las que ya
están instaladas aparecen como `(instalada)` y no se reinstalan. En
"Instalación completa (todo)" se instala el catálogo entero.

El script también sirve solo:

```bash
./scripts/02b-install-flatpak.sh            # selección interactiva
./scripts/02b-install-flatpak.sh --list     # qué hay en el catálogo
./scripts/02b-install-flatpak.sh --apps org.mozilla.Thunderbird,com.getpostman.Postman
./scripts/02b-install-flatpak.sh --all
```

Sin TTY o sin `gum` no adivina: pide `--all` o `--apps` y sale con error de uso.
Todo se instala a nivel de usuario (`--user`), sin `sudo`, y agregar una app al
catálogo es agregar una línea a `packages/flatpak-apps.txt`.

| Archivo | Componente |
|---|---|
| `base.txt` | Herramientas base del sistema |
| `desktop-sway.txt` | Escritorio Sway + utilidades Wayland |
| `shell.txt` | Shell, terminal y editor |
| `dev-core.txt` | Herramientas de desarrollo comunes |
| `dev-php.txt` | Desarrollo PHP (nombres versionados `php8-*`) |
| `dev-db.txt` | Bases de datos y contenedores (mariadb, sqlite3, podman) |
| `dev-rust.txt` | Desarrollo Rust |
| `dev-python.txt` | Desarrollo Python |
| `dev-angular.txt` | Desarrollo Angular/Node |
| `flatpak-apps.txt` | Aplicaciones Flatpak (appids de Flathub, 1 por línea) |
| `cloud.txt` | `rclone` y sus completions (montajes de Drive y OneDrive) |

Los controladores de hardware **no** viven en `packages/`. Cada dispositivo
tiene su propio entry-point autocontenido en `scripts/drivers/`, con nombre
`driver-<vendor>-<modelo>.sh`, porque los paquetes que hacen falta dependen de
LA PLACA y no del sistema. `scripts/drivers/drivers-menu.sh` descubre todos los
`driver-*.sh` por glob y lanza el que elijas, así que agregar un dispositivo
nuevo (otra GPU, una impresora) es agregar un archivo: no hay que tocar
`install.sh` ni el submenú.

### `config/` (copia directa)

`config/` no usa GNU Stow. Cada subdirectorio de `config/` (excepto
`home/`) se copia tal cual a `~/.config/<app>/`; `home/` se copia a
`$HOME`. La fuente de verdad es el repo y `04-setup-dotfiles.sh` la
aplica al sistema. Los `customize.sh` que conviven con cada app no se
copian: se ejecutan desde `05-install-fonts.sh` para personalizar la
fuente (familia y tamaño) sobre los archivos del repo.

```text
config/
├── home/                      # .bashrc, .zshrc, .gitconfig, .inputrc, .profile → $HOME
│                              # (.local/share/com.pais.handy/ → ajustes de Handy)
├── sway/                      # config + config.d/ (+ customize.sh) → ~/.config/sway
├── i3/                        # config + config.d/ (hereda /etc/i3/config) → ~/.config/i3
├── foot/                      # foot.ini (+ customize.sh) → ~/.config/foot
├── waybar/                    # config, style.css (+ customize.sh) → ~/.config/waybar
└── environment.d/             # chromium.conf, nvidia.conf, path.conf → ~/.config/environment.d
```

## Requisitos

- openSUSE Tumbleweed (instalación limpia o reciente)
- Conexión a internet
- GPU NVIDIA GeForce GTX 1060 3 GB (soportada por los controladores G06)

## Instalación

```bash
git clone https://github.com/JorgeAlbertoDiaz/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh scripts/*.sh
./install.sh
```

El instalador:

1. Verifica que el sistema es openSUSE Tumbleweed.
2. Verifica y crea los directorios base XDG y la carpeta de descargas.
3. Instala `gum` desde el repositorio `repo-oss` (con fallback al binario de
   GitHub Releases) si no está presente.
4. Muestra un menú interactivo multi-selección de componentes (incluye
   `fonts`, para Nerd Fonts).
5. Instala paquetes, configura NVIDIA, instala/configura Nerd Fonts y aplica
   los dotfiles (copia directa a `~/.config/<app>`).

### Componente `fonts`

`scripts/05-install-fonts.sh` verifica las Nerd Fonts instaladas (`fc-list`),
deja elegir qué familias instalar desde un catálogo curado (JetBrainsMono,
FiraCode, SourceCodePro, Hack, UbuntuMono, Ubuntu, RobotoMono, Monofur, más
entrada personalizada), las descarga por familia desde `ryanoasis/nerd-fonts`
a `~/.local/share/fonts` (sin sudo) y refresca `fc-cache`.

Después permite elegir, para cada aplicación con `customize.sh` (foot, sway,
waybar), qué fuente y tamaño aplicar; los cambios quedan en el repo y
`04-setup-dotfiles.sh` los copia al aplicarlos. Si una fuente configurada
falta, fontconfig usará un fallback (p. ej. DejaVu Sans Mono).

> ⚠️ Waybar declara `JetBrainsMono Nerd Font` en `config/waybar/style.css`. Si
> esa familia no está instalada, los glifos de íconos (`󰕿`, `󰂚`, `󰃰`, …) caen
> en cualquier fuente que los tenga o directamente no se dibujan: se ven
> cuadraditos, íconos cambiados o letras en lugar de símbolos. Verificar con
> `fc-match "JetBrainsMono Nerd Font"` (debe devolver la Nerd Font, no Adwaita)
> y con `fc-list :charset=f057f family` (glifo de volumen, sin cobertura ⇒
> falta la fuente).

### Componente `Dictado por voz (Handy)`

Dictado offline con atajos en sway e i3: se aprieta `Super+Shift+d`, se habla
y el texto aparece en la ventana enfocada. `scripts/12-setup-handy.sh`
instala el RPM oficial de [Handy](https://github.com/cjpais/Handy) (pinneado
por versión y SHA-256, porque no está en los repos de openSUSE) y despliega
los ajustes por defecto: español fijado, modelo Whisper Large v3 y pegado por
portapapeles.

| Entorno | Atajo | Archivo |
|---|---|---|
| sway | `Super+Shift+d` | `config/sway/keybindings/applications.conf` |
| i3 | `Super+Shift+d` | `config/i3/config.d/60-handy.conf` |
| sway/i3 | arranque oculto en bandeja | `config/sway/features/autostart.conf`, `config/i3/config.d/60-handy.conf` |

`config/i3/config` es un punto de entrada nuevo que hereda `/etc/i3/config`
con `include` y suma sólo `config.d/`: así el repo no duplica lo que trae el
paquete i3. Detalle completo, ajustes versionados y verificación sin GUI en
[handy.md](./handy.md).

> 💡 Si `gum` no pudiera instalarse (p. ej. sin red), `install.sh` usa un
> flujo de confirmación simple con bash.

### Componente `Nube (rclone)`

Monta Google Drive y OneDrive como sistemas de archivos FUSE en
`~/Cloud/<remote>`, con unidades de **systemd de usuario** que los automontan
en cada inicio. No sincroniza: los archivos viven en la nube y la caché local
es sólo una ventana temporal.

Es **por usuario**: cada uno corre `scripts/13-setup-cloud-mounts.sh` en su
sesión y autoriza con su propia cuenta (OAuth 2.0), con su `~/.credentials/`
(un `.env` por proveedor, directorio 700) y su `~/.config/rclone/rclone.conf`. El `client_id` de la app OAuth de Google se
puede compartir; los tokens no. `--check` informa el estado sin mutar nada.

Requisito de una sola vez: crear la app *Desktop* en Google Cloud Console y
publicarla **In production** (en *Testing* Google expira el refresh token cada
7 días). Procedimiento completo, verificación y trampas en
[cloud-mounts.md](./cloud-mounts.md).

### Tema claro/oscuro

El escritorio tiene dos temas completos (oscuro y claro) que se cambian desde el
botón del centro de notificaciones, con `Super+Shift+t` o con
`~/.config/sway/scripts/sway-theme.sh toggle`. Cada app tiene un archivo nativo
por tema en su directorio `themes/`, y el archivo que la app lee es un enlace
simbólico al tema activo; el estado es un archivo de texto en
`~/.local/state/dotfiles/tema`. Cubre sway, waybar, swaync, wofi, foot,
swaylock, wob, apps GTK y nvim. Paleta, mecanismo y límites en
[tema-claro-oscuro.md](./tema-claro-oscuro.md).

## Diagramas

Los diagramas se definen con **Mermaid** en archivos `/docs/assets/*.mmd`
(referenciados desde el markdown, nunca incrustados):

| Diagrama | Descripción |
|---|---|
| [Flujo de instalación](./assets/flow.mmd) | Secuencia completa de `install.sh` |
| [Montajes de nube](./diagramas/cloud-mounts.mmd) | Credenciales, unidad `rclone@.service` y `~/Cloud/<remote>` por usuario |

Para visualizarlos localmente: abrir el `.mmd` en Obsidian, VS Code (con la
extensión habitual de Mermaid) o Typora.

## Referencia

Notas de hallazgos de openSUSE: bugs o límites de hardware documentados para
no volver a investigarlos.

| Nota | Tema |
|---|---|
| [bug-opensuse-cups-filters2-pdf.md](./referencia/bug-opensuse-cups-filters2-pdf.md) | `cups-filters2` no instala las reglas MIME de conversión de PDF |
| [hibernacion-opensuse-lvm.md](./referencia/hibernacion-opensuse-lvm.md) | Hibernación con swap sobre LVM: qué falta y cómo verificarlo |
| [miracast-ath9k-no-viable.md](./referencia/miracast-ath9k-no-viable.md) | Miracast no es viable con el adaptador `ath9k` AR9287 |

## Ruta de desarrollo

- [ ] Probar `install.sh` en una instalación limpia
- [ ] Añadir configs de subida (Hyprland, nvim/LazyVim, wofi, etc.)
- [ ] Instaladores por fuente (npm global, AppImages, etc.)
- [ ] Soporte de otros SIDs (Arch, Fedora) manteniendo `common.sh`
- [ ] Tema de fondos de pantalla gestionado desde el repo