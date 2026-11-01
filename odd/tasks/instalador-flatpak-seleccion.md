# Entrada Flatpak en el menú principal con selección de apps

Agregar al menú principal del instalador una entrada para instalar aplicaciones Flatpak y, desde ahí, elegir cuáles instalar del catálogo (`packages/flatpak-apps.txt`). Hoy Flatpak es una pregunta global después de base/shell que instala **todo** el catálogo, y no aparece en el menú ni en la selección de componentes.

## Specs

S1. El menú principal de `install.sh` muestra una entrada `Instalar aplicaciones Flatpak`, entre las opciones de utilidades y `Salir`, y elegirla ejecuta el paso Flatpak y vuelve al menú (no aborta la instalación).

S2. El paso Flatpak permite **elegir qué apps instalar** del catálogo `packages/flatpak-apps.txt`. Sin argumentos abre una selección múltiple con gum (`--no-limit`); si gum no está pero hay TTY, pregunta app por app con `confirm` (las ya instaladas no se preguntan), igual que el resto del instalador. Es obligatorio que sin gum **no** aborte: la selección de componentes sin gum llama al paso con confirmaciones y un `exit 2` ahí terminaría la instalación entera.

S3. Interfaz no interactiva del paso Flatpak:

```
02b-install-flatpak.sh [opciones]
  (sin opciones)   selección interactiva del catálogo
  --all            instala todas las apps del catálogo
  --apps A,B,C     instala exactamente esos appids (tienen que estar en el catálogo)
  --list           imprime los appids del catálogo (uno por línea) y sale 0
  -h, --help       ayuda
```

S4. `--list` es de sólo lectura: no requiere que flatpak esté instalado ni toca flathub.

S5. Errores explícitos, sin instalar nada:
- appid pedido con `--apps` que no está en el catálogo → mensaje que lo nombra, exit 1;
- catálogo ausente o vacío → mensaje, exit 1 (vacío: exit 0 con aviso, igual que hoy);
- sin TTY y sin `--all`/`--apps` → mensaje de uso, exit 2 (nunca "no hace nada" en silencio);
- catálogo vacío: `--list` imprime nada y sale 0 (es una lectura, no un error); los demás modos avisan y salen 0.

S6. `flatpak` no instalado → aviso `flatpak no instalado — instalalo vía packages/base.txt primero`, exit 0, sin registrar flathub.

S7. Idempotencia: las apps ya instaladas se detectan (`flatpak list --app --columns=application`), se avisan y **no** se reinstalan. El remote `flathub` se registra con `--if-not-exists --user` sólo si hay algo para instalar.

S8. `install.sh` trata Flatpak como un componente más de `COMPONENTES` (`Aplicaciones Flatpak`), así que aparece en la selección múltiple y en la instalación completa. En instalación completa instala el catálogo entero (`--all`); elegido a mano, abre la selección por app.

S9. Se elimina la pregunta global del paso 6 de `install.sh` (la reemplaza el componente): una sola forma de instalar Flatpak, sin preguntas duplicadas ni dos caminos que se desincronicen.

S10. Espacios de selección consistentes: la lista de apps muestra el appid y marca las ya instaladas (sufijo `(instalada)`), igual que hace `05-install-fonts.sh` con las fuentes.

S11. Documentación: `docs/index.md` y `README.md` describen la entrada del menú, la selección por app y las flags.

S12. Los dos scripts nuevos de test se ejecutan sin root, sin red y sin flatpak real, con stubs que registran sus invocaciones.

## Tasks

- [x] T1 (S2, S3, S4, S5, S6, S7, S10) `scripts/02b-install-flatpak.sh`: flags `--all|--apps|--list|--help`, selección gum/confirm, detección de ya instaladas, validaciones. Spec propio (test-first). → `3e8cbde` (33 pasos, 0 fallos)
- [x] T2 (S1, S8, S9) `install.sh`: entrada en el menú principal, componente `Aplicaciones Flatpak` en `COMPONENTES`, rama en `run_component` (`--all` en instalación completa, selección a mano), quitar la pregunta global. Spec de integración del menú (test-first). → `d10fbdf` (15 pasos, 0 fallos)
- [x] T3 (S11) Docs: `docs/index.md` + `README.md`. → `87bac73`
- [x] T4 Verificación: specs, `bash -n`, `shellcheck`, verificador independiente (toca el instalador = riesgo item 5). → `c22e0fe`: 37 + 15 + 40 pasos en verde, shellcheck limpio en lo nuevo, probes reales sin instalar, verificador con S1-S12 cumpliendo y su bloqueante corregido.

## Log

L1 (usuario, verbatim):

> No veo en el menu principal la entrada para instalar aplicaciones de flatpak, me gustaria que en el menu principal aparecieran y luego poder elegir (seleccionando) cual instalar

L2 (hallazgos de exploración):
- `install.sh` no tiene entrada Flatpak en `OPCIONES_MENU` ni en `COMPONENTES`; después de base/shell hace una única pregunta global (`gum confirm`) y llama al script sin argumentos, que instala **todo** `packages/flatpak-apps.txt`.
- `scripts/02b-install-flatpak.sh` no acepta flags; verifica flatpak, registra flathub y recorre el archivo completo.
- Patrón de selección múltiple ya usado en el repo: `gum choose --no-limit --height 12` + `mapfile` filtrando el elemento vacío (`scripts/05-install-fonts.sh`).
- `flatpak` está en `packages/base.txt`, así que cualquier componente corre después de tenerlo.

L3 (slices entregados, para que cada commit se revise solo):
- `03ea798` — documento de feature (S1-S12) y hallazgos de exploración.
- `d10fbdf` — `install.sh`: menú, componente, rama de `run_component` y baja de la pregunta global.
- `3e8cbde` — `02b-install-flatpak.sh` con flags + su spec.
- `87bac73` — docs (`docs/index.md`, `README.md`).
- El orden de commits deja dos estados intermedios funcionales a propósito: el menú usa `02b` sin argumentos (que instala el catálogo completo) hasta que llega el commit con las flags.

L4 (verificación propia):
- Specs: `02b-install-flatpak-spec.sh` 33 pasos, `install-flatpak-menu-spec.sh` 15 pasos, `04-setup-dotfiles-spec.sh` 40 pasos; los tres en 0 fallos.
- `bash -n` limpio en `install.sh` y los dos specs. `shellcheck -S warning` limpio en lo nuevo de este feature y en `02b`; en `install.sh` queda el `SC2034` de `REPO_DIR`, preexistente en `main` (verificado: dos coincidencias idénticas en `git show main:install.sh`), no tocado por este cambio.
- Probes reales que no instalan nada: `--list` imprime los cuatro appids (exit 0); `--apps com.getpostman.Postman` (ya instalada) omite y sale 0 sin registrar flathub; `--apps org.ejemplo.NoExiste` sale 1 nombrando el appid; sin TTY sale 2 con el uso.
- Nota de entorno: el caso interactivo del spec usa `script` (util-linux) para simular TTY y se saltea con exit 2 si falta.

L5 (verificador independiente, hallazgos atendidos):
- **Bloqueante (conflicto en mi propio spec):** S2 pedía "sin gum, confirmación app por app" y S5 pedía "sin TTY/gum → exit 2". El script siguió S5, y eso rompía el instalador: su selección de componentes sin gum llama al paso sin argumentos, así que un `exit 2` bajo `set -e` abortaba la instalación completa. Resuelto implementando el fallback de `confirm` (S2 manda sobre gum; S5 queda sólo para "sin TTY") con dos casos nuevos en el spec (37 pasos, 0 fallos). Al escribirlos apareció un fixture frágil: el stub usaba `basename`, ausente en el PATH mínimo del caso; ahora usa `${0##*/}`.
- Advisory: `--list` con catálogo vacío imprime nada y sale 0 sin aviso → se documenta en S5 (una lectura no es un error).
- Advisory: `README.md` tenía el bullet de Flatpak pegado al anterior por falta de salto de línea → corregido.
- Advisory preexistente (no tocado, fuera de alcance): la instalación completa ejecuta `Escritorio Sway` dos veces (`install.sh:383-386`, idéntico en `main`).
