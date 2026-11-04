# Montajes de nube: Google Drive y OneDrive con rclone

Feature: un directorio por proveedor, montado con `rclone mount` (FUSE) y
automontado en cada inicio con `systemd --user`. Decisiones cerradas por el
usuario: **ambos proveedores**, **montar (no sincronizar)**, **client_id propio
de Google**. Este documento es la especificación que leen los workers: leer
hasta `## Log`.

## Specs

- **S1 — Ambos proveedores, a la vez.** El sistema monta Google Drive y
  OneDrive de forma simultánea, cada uno en su propio punto de montaje, con una
  sola herramienta y un solo formato de unidad. Pedido del usuario: «D1 ambos
  proveedores».
- **S2 — Montar, no sincronizar.** El mecanismo es `rclone mount` sobre FUSE,
  con `--vfs-cache-mode full`. No se usa `rclone sync`/`bisync` ni ningún cliente
  de sincronización con copia local. Pedido: «D2 montar».
- **S3 — Google Drive con client_id propio.** El remote `gdrive` usa una
  aplicación OAuth del usuario (proyecto en Google Cloud Console, credencial
  tipo *Desktop app*), no el `client_id` compartido de rclone: la documentación
  oficial de rclone dice textualmente «This shared client\_id is being retired
  and will stop working during 2026». La app se publica en estado "In
  production"; en "Testing" Google expira el refresh token cada 7 días. Pedido:
  «D3 vamos a crear un client_id».
- **S4 — Credenciales en `~/.credentials`, plantilla en el repo.** Los
  `client_id`/`client_secret` de aplicación se leen desde `~/.credentials`
  (`chmod 600`, fuera de git). El repo entrega `config/home/.credentials.example`
  con placeholders `CHANGEME-` y sin secretos reales. Pedido: «que las
  credenciales se lean desde por ejemplo algun archivo como ~/.credentials pero
  crea un archivo credentials.example».
  Reglas concretas:
  - Los nombres de variable son los que rclone ya interpreta
    (`RCLONE_DRIVE_CLIENT_ID`, `RCLONE_DRIVE_CLIENT_SECRET`,
    `RCLONE_ONEDRIVE_CLIENT_ID`, `RCLONE_ONEDRIVE_CLIENT_SECRET`), así que la
    unidad usa `EnvironmentFile=` sin script traductor y una shell puede
    cargarlas con `set -a; . ~/.credentials; set +a`.
  - El archivo es obligatorio para la unidad: si falta, la unidad falla en voz
    alta en lugar de arrancar con el `client_id` compartido retirado.
  - Los tokens de sesión (refresh token) los escribe `rclone config` en
    `~/.config/rclone/rclone.conf`, también `chmod 600` y también fuera de git.
  - El instalador rechaza habilitar las unidades mientras quede algún valor
    `CHANGEME` en `~/.credentials`.
- **S5 — Automonte en cada inicio.** Las unidades son `systemd --user` con
  `WantedBy=default.target` y `Restart=on-failure`. `loginctl show-user jorge -p
  Linger` devuelve `Linger=yes` en esta máquina, así que arrancan en el boot sin
  sesión abierta. Pedido: «que se automonte en cada inicio».
- **S6 — Dentro de `/home/jorge`, no global.** Puntos de montaje en
  `~/Cloud/<remote>`. Se descarta `/mnt` y cualquier unidad de sistema: un
  montaje FUSE global exigiría correr como root leyendo tokens de usuario,
  habilitar `user_allow_other` en `/etc/fuse.conf` (hoy comentado) y pelear con
  `network-online` a nivel sistema, sin ganar aislamiento. Pedido: «podria ser
  global pues soy el unico usuario pero quizas sea mejor que este en /home/jorge
  por seguridad».
- **S7 — Plantillas de servicio versionadas.** Las unidades viven en
  `config/home/.config/systemd/user/` y las despliega
  `scripts/04-setup-dotfiles.sh`. Una sola plantilla `rclone@.service`
  instanciada por proveedor (`rclone@gdrive.service`,
  `rclone@onedrive.service`): el nombre de la instancia (`%i`) es a la vez el
  nombre del remote y el subdirectorio de `~/Cloud`. Pedido: «quiero que se
  agreguen las plantillas de servicios».
- **S8 — Instalador idempotente y asistido.** `scripts/13-setup-cloud-mounts.sh`
  sigue la convención del repo (`#!/usr/bin/env bash`, `set -euo pipefail`,
  `usage`/`--help`, `source common.sh`, selección con `gum` y fallback sin TTY),
  ofrece `--provider gdrive|onedrive|both`, `--check` de sólo lectura y no
  duplica trabajo si el remote ya existe.
- **S9 — Paquetes declarados.** `rclone`, `rclone-bash-completion` y
  `rclone-zsh-completion` figuran en `packages/` (hoy no están instalados).
- **S10 — Documentación.** `docs/cloud-mounts.md` con el procedimiento de OAuth,
  el ciclo de verificación y las trampas; un `.mmd` en `docs/diagramas/`;
  entrada en `docs/index.md` y en la estructura de `README.md`.
- **S11 — Nada de secretos en git.** `.gitignore` ignora `.credentials`; ningún
  commit contiene tokens ni `client_secret`.
- **S12 — Aislamiento de pruebas.** Toda prueba del instalador y de las
  unidades corre con `HOME` en un directorio temporal y una copia del repo:
  nunca sobre `/home/jorge` real ni habilitando servicios del sistema.
- **S13 — Cada usuario monta su propia cuenta.** El montaje es por usuario, no
  por máquina: cualquier usuario de la PC corre el instalador en su propia
  sesión y obtiene sus propios `~/.credentials`, su propio
  `~/.config/rclone/rclone.conf` (con su refresh token OAuth 2.0) y sus propias
  unidades `--user`, sin root, sin estado compartido y sin tocar el HOME de
  otro. El `client_id` de la aplicación OAuth (`Desktop app`) es el mismo para
  todos y puede ser compartido, pero cada usuario autoriza con su propia cuenta
  de Google en el navegador. Un usuario nuevo no hereda tokens: vuelve a hacer
  el OAuth. Pedido: «Quiero en todo caso tener la posibilidad que cada usuario
  pueda montar su propio drive (supongo que sera con OAuth 2)».

## Tasks

- [x] T1 — Documento de feature con specs y TODO · S1-S12 · inline · este commit
- [x] T2 — Plantilla `config/home/.config/systemd/user/rclone@.service` (Type=notify, VFS full, `EnvironmentFile=%h/.credentials`, `ExecStop=fusermount3 -uz`, `Restart`) · S2,S4,S5,S6,S7 · inline · `e41aafb`
- [x] T3 — `config/home/.credentials.example` con placeholders `CHANGEME-` + `.gitignore` para `.credentials` · S4,S11 · inline · `e41aafb`
- [x] T4 — `scripts/13-setup-cloud-mounts.sh`: verificación de dependencias, `rclone config` asistido por proveedor, `mkdir` de `~/Cloud/<remote>`, copia de `.credentials.example` a `~/.credentials` con `chmod 600`, rechazo de `CHANGEME` pendientes, `systemctl --user daemon-reload`, `enable --now`, salida `--check` de sólo lectura, y todo bajo `$HOME` para que cada usuario corra su propia copia (S13) · S3,S4,S5,S8,S13 · inline con RED primero
- [x] T5 — `packages/cloud.txt` con `rclone` y sus completions · S9 · inline · `7d83b57`
- [x] T6 — Componente "Nube (rclone)" en `install.sh`: ítem de menú, rama interactiva y rama no interactiva, sin romper el menú actual · S8 · inline
- [x] T7 — `docs/cloud-mounts.md` + `docs/diagramas/cloud-mounts.mmd` + `docs/index.md` + `README.md` (estructura y componentes), con la sección «varios usuarios en la misma PC» (S13) · S10,S13 · inline
- [x] T8 — `scripts/tests/13-setup-cloud-mounts-spec.sh` con `HOME` temporal: `--help` sale 0, `--check` no muta nada, `CHANGEME` aborta con exit ≠ 0 y sin escribir unidades, `mkdir` idempotente, permisos `600` del archivo copiado, dos HOMEs independientes (S13) · S4,S8,S12,S13 · inline · `d1b7773`
- [ ] T9 — Verificación end-to-end en la máquina real: `rclone about` de ambos remotes, `mount | grep fuse.rclone`, escritura y lectura, reboot, corte de red y despertar de suspensión · S1,S2,S5 · manual, requiere navegador para el OAuth
- [ ] T10 — Cierre: `shellcheck` del script nuevo, estado del menú de `install.sh`, registro de evidencia en este documento · S8-S10 · inline

## Log

- **L1** (pedido original, verbatim): «Necesito que me digas qué sería lo que
  tengo que hacer para poder montar un directorio en el que se monte google
  drive o onedrive (microsoft) y que se automonte en cada inicio, podria ser
  global pues soy el unico usuario pero quizas sea mejor que este en /home/jorge
  por seguridad, no implementes nada aun solo dame un reporte»
- **L2** (decisiones, verbatim): «D1 ambos proveedores, D2 montar, D3 vamos a
  crear un client_id. Con estas dudas resueltas quiero que docuementes esta lista
  de TODO, quiero que se agreguen las plantillas de servicios y que las
  credenciales se lean desde por ejemplo algun archivo como ~/.credentials pero
  crea un archivo credentials.example»
- **E1** (evidencia, entorno): Tumbleweed, kernel 7.3, systemd 261, sway.
  `fuse3` y `fusermount3` instalados. `rclone` 1.75.2 disponible en
  `openSUSE-Tumbleweed-Oss` (no instalado). `google-drive-ocamlfuse` y
  `onedriver` no existen en los repos. `Linger=yes` ya activo para el usuario.
  `/etc/fuse.conf` con `user_allow_other` comentado. `/home` con 697 GB libres.
- **E2** (evidencia, rclone): `rclone mount` soporta `Type=notify` y avisa a
  systemd cuando el punto de montaje está operativo; los flags de backend
  también se leen por entorno (`RCLONE_<BACKEND>_<OPTION>`), que es lo que hace
  viable inyectar el `client_id` con `EnvironmentFile=` y sin envoltorio.
- **E3** (decisión): se descartan `google-drive-ocamlfuse` (fuera de repos, sólo
  Drive), `onedriver` (fuera de repos, y es sincronización, no montaje), gvfs +
  GNOME Online Accounts (sin demonio de cuentas en sway, rutas ilegibles en
  `/run/user/1000/gvfs`) e Insync (pago, propietario).
- **E4** (decisión): tokens en `rclone.conf` y `client_id`/`client_secret` de
  aplicación en `~/.credentials`. Se descartó meter el token JSON en
  `EnvironmentFile` (frágil por quoting) y se descartó un script envoltorio
  (agrega un proceso y una capa que systemd ya resuelve).
- **E5** (riesgo abierto para T9): el `client_id` debe ser el mismo que emitió
  el refresh token guardado en `rclone.conf`; si se rota el secreto en
  `~/.credentials` sin reautorizar, el montaje falla con 401 al refrescar. El
  instalador tiene que advertirlo y `--check` debe distinguirlo.
- **L3** (pausa, verbatim): «no, lo haremos en otra sesion el dia de mañana.
  Dejalos anotados como pendientes para retomarlo».
  Estado al pausar: T1-T3 hechas y commiteadas (`e41aafb`, `3ce4ac7`); T4-T10
  pendientes y sin empezar; rama `feat/cloud-mounts` sin push ni merge.
  **Retome: empezar por T4** (`scripts/13-setup-cloud-mounts.sh`) con RED
  primero, y después T5-T6 para que el instalador sea usable de punta a punta.
  No hay nada a medias ni roto: el repo queda con el despliegue de dotfiles
  verificado en 48/0 y la plantilla validada por `systemd-analyze verify`.
- **L4** (requisito nuevo, verbatim): «Quiero en todo caso tener la posibilidad
  que cada usuario pueda montar su propio drive (supongo que sera con OAuth 2)».
  Efecto: se agrega S13. El diseño ya era por usuario (unidades `--user`,
  `%h/.credentials`, `%h/.config/rclone/rclone.conf`, `~/Cloud/<remote>`), así
  que no cambia la arquitectura: se refuerza con (a) verificación de
  `Linger` por usuario en el instalador, (b) una prueba que corre dos HOMEs
  independientes, y (c) la sección de varios usuarios en la documentación. El
  `client_id` de la app OAuth es compartible; el refresh token no.
- **E6** (evidencia, T4/T8): `scripts/tests/13-setup-cloud-mounts-spec.sh` en
  RED primero (20 fallos, script ausente) y después 40/0 con HOME temporal,
  dobles de `rclone`/`systemctl` y copia del repo. Cubre `--help`, `--check`
  sin mutaciones ni llamadas a systemd, `CHANGEME` abortando sin habilitar
  unidades, copia de credenciales con modo 600, idempotencia, orden
  `daemon-reload` → `enable --now`, `--provider` inválido y dos HOMEs
  independientes (S13).
- **E7** (evidencia, T5/T6): `packages/cloud.txt` con los tres paquetes;
  `install.sh` suma el componente `Nube (rclone)` (interactivo corre el
  instalador, instalación completa corre `--check`, y con `EUID 0` sólo avisa
  para no crear `/root/.credentials`). `install-flatpak-menu-spec.sh` sigue en
  15/0 y `04-setup-dotfiles-spec.sh` en 48/0.
- **E8** (evidencia, T7): `docs/cloud-mounts.md` (OAuth paso a paso, credenciales,
  multi-usuario, verificación, trampas), `docs/diagramas/cloud-mounts.mmd`,
  entrada en `docs/index.md` y en la estructura de `README.md`.
- **E9** (shellcheck): `shellcheck -S warning` sin hallazgos en
  `scripts/13-setup-cloud-mounts.sh` ni en su spec.
- **E10** (delivery, slices): la rama `feat/cloud-mounts` ya pasa las ~400
  líneas autoradas, así que la entrega va por slices con frontera explícita:
  - slice 1 — `7d83b57` paquetes (`packages/cloud.txt`), T5;
  - slice 2 — `d1b7773` instalador + spec (`scripts/13-*`, `scripts/tests/13-*`), T4 y T8;
  - slice 3 — componente del menú + documentación (`install.sh`, `docs/`, `README.md`), T6 y T7;
  - slice 4 — verificación end-to-end y cierre (T9, T10), con la evidencia en este Log.
  Push, PR y merge quedan para el usuario; la rama no se publica sola.
