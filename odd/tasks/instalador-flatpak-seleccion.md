# Entrada Flatpak en el menú principal con selección de apps

Agregar al menú principal del instalador una entrada para instalar aplicaciones Flatpak y, desde ahí, elegir cuáles instalar del catálogo (`packages/flatpak-apps.txt`). Hoy Flatpak es una pregunta global después de base/shell que instala **todo** el catálogo, y no aparece en el menú ni en la selección de componentes.

## Specs

S1. El menú principal de `install.sh` muestra una entrada `Instalar aplicaciones Flatpak`, entre las opciones de utilidades y `Salir`, y elegirla ejecuta el paso Flatpak y vuelve al menú (no aborta la instalación).

S2. El paso Flatpak permite **elegir qué apps instalar** del catálogo `packages/flatpak-apps.txt`. Sin argumentos abre una selección múltiple (gum `--no-limit`; sin gum, confirmación app por app).

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
- sin TTY/gum y sin `--all`/`--apps` → mensaje de uso, exit 2 (nunca "no hace nada" en silencio).

S6. `flatpak` no instalado → aviso `flatpak no instalado — instalalo vía packages/base.txt primero`, exit 0, sin registrar flathub.

S7. Idempotencia: las apps ya instaladas se detectan (`flatpak list --app --columns=application`), se avisan y **no** se reinstalan. El remote `flathub` se registra con `--if-not-exists --user` sólo si hay algo para instalar.

S8. `install.sh` trata Flatpak como un componente más de `COMPONENTES` (`Aplicaciones Flatpak`), así que aparece en la selección múltiple y en la instalación completa. En instalación completa instala el catálogo entero (`--all`); elegido a mano, abre la selección por app.

S9. Se elimina la pregunta global del paso 6 de `install.sh` (la reemplaza el componente): una sola forma de instalar Flatpak, sin preguntas duplicadas ni dos caminos que se desincronicen.

S10. Espacios de selección consistentes: la lista de apps muestra el appid y marca las ya instaladas (sufijo `(instalada)`), igual que hace `05-install-fonts.sh` con las fuentes.

S11. Documentación: `docs/index.md` y `README.md` describen la entrada del menú, la selección por app y las flags.

S12. Los dos scripts nuevos de test se ejecutan sin root, sin red y sin flatpak real, con stubs que registran sus invocaciones.

## Tasks

- [ ] T1 (S2, S3, S4, S5, S6, S7, S10) `scripts/02b-install-flatpak.sh`: flags `--all|--apps|--list|--help`, selección gum/confirm, detección de ya instaladas, validaciones. Spec propio (test-first).
- [ ] T2 (S1, S8, S9) `install.sh`: entrada en el menú principal, componente `Aplicaciones Flatpak` en `COMPONENTES`, rama en `run_component` (`--all` en instalación completa, selección a mano), quitar la pregunta global. Spec de integración del menú (test-first).
- [ ] T3 (S11) Docs: `docs/index.md` + `README.md`.
- [ ] T4 Verificación: specs, `bash -n`, `shellcheck`, verificador independiente (toca el instalador = riesgo item 5).

## Log

L1 (usuario, verbatim):

> No veo en el menu principal la entrada para instalar aplicaciones de flatpak, me gustaria que en el menu principal aparecieran y luego poder elegir (seleccionando) cual instalar

L2 (hallazgos de exploración):
- `install.sh` no tiene entrada Flatpak en `OPCIONES_MENU` ni en `COMPONENTES`; después de base/shell hace una única pregunta global (`gum confirm`) y llama al script sin argumentos, que instala **todo** `packages/flatpak-apps.txt`.
- `scripts/02b-install-flatpak.sh` no acepta flags; verifica flatpak, registra flathub y recorre el archivo completo.
- Patrón de selección múltiple ya usado en el repo: `gum choose --no-limit --height 12` + `mapfile` filtrando el elemento vacío (`scripts/05-install-fonts.sh`).
- `flatpak` está en `packages/base.txt`, así que cualquier componente corre después de tenerlo.
