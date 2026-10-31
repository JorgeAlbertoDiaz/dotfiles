# Aplicar dotfiles con limpieza acotada a lo que el repo despliega

Rama: `fix/aplicar-dotfiles-limpieza-acotada`. Alto riesgo: toca borrado de datos del usuario.

Risk: item 1 (data or irreversible effects: el diff reescribe la lógica que borra archivos bajo `$HOME`).

## Specs

- **S1** — «la limpieza solo toque (borre y ponga nuevamente) solo las cosas que este proyecto reconstruye».
- **S2** — «mejor si es de alguna manera dinámica».
- **S3** — «al aplicar los dotfiles perdi datos por ejemplo herdr ya no se reconoce como comando».
- **S4** — «el instalador trataba de borrar directorios como los contenedores de podman y otras configuraciones que despues no se pueden recuperar».
- **S5** — «cada vez que actualizo algo, por ejemplo dotfiles tengo que recomponer comandos, variables de entorno, reconstruir contenedores».

## Causa raíz

`scripts/04-setup-dotfiles.sh` con «Reset de fábrica» hacía `rm -rf` de:

- `~/.config/<app>` completo (incluye archivos que el repo no declara), y
- cada entrada de primer nivel de `config/home/`, con `rm -rf $HOME/<nombre>`.

Al entrar `config/home/.local/`, el reset borraba `~/.local` entero: binarios
de usuario (`~/.local/bin/herdr`), datos de apps (`~/.local/share/containers`),
estado y cualquier otra cosa debajo. Nada de eso lo reconstruye el repo.

## Diseño

Inventario dinámico: al aplicar, el script recorre `config/` y calcula la lista
exacta de archivos que despliega. La guarda en
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/desplegado.tsv` (relativa a `$HOME`).
La limpieza borra solo entradas del inventario anterior que el repo ya no
declara; nunca hace `rm -rf` de un directorio del usuario (solo `rmdir` de
directorios que quedaron vacíos, con topes en las bases XDG).

Regla de datos: los destinos bajo `~/.local/share/` y `~/.local/state/` son
datos de aplicación (mutables por la app). Se siembran si faltan y nunca se
pisan ni se podan; así los ajustes de Handy no se resetean en cada aplicación.

## Tasks

- [x] T1 — `scripts/tests/04-setup-dotfiles-spec.sh`: spec ejecutable que fija S1-S4. Commit `3c6d2ec` (`test(dotfiles): fija la limpieza acotada con un spec ejecutable`). RED previo: 4 pasos fallaban.
- [x] ~~T2 — `scripts/common.sh`: EOF como «no»~~. Descartada: `confirm()` ya devuelve «no» con EOF (`case` incluye la cadena vacía); `confirm_yes` queda fuera de alcance.
- [x] T3 — `scripts/04-setup-dotfiles.sh`: despliegue por archivo + inventario + poda acotada + semillas; se elimina el reset destructivo. Commit propio (riesgo alto) `999238a` (`fix(dotfiles): limita la limpieza a lo que el repo despliega`). Incluye comentarios de `09-setup-nvim.sh` que citaban `reset=1`.
- [x] T4 — `docs/aplicar-dotfiles.md` + enlace en `README.md` + este documento. Commit: docs.
- [x] T5 — Verificación (ver abajo).

## Slice boundary

Riesgo alto: el commit `999238a` es la unidad que native review debe poder tomar sola; el spec va en `3c6d2ec` para que ninguna slice pase de ~400 líneas autoradas. El commit de docs cierra la feature.

## Evidencia de verificación

- Spec: 32 pasos, 0 fallos (`bash scripts/tests/04-setup-dotfiles-spec.sh`). RED anterior: 4 fallos (poda de archivo, poda de binario, `rmdir` del directorio vacío y pisado de datos de app).
- Incidente reproducido contra el código anterior: respondiendo «sí» al reset desaparecían `~/.local/bin`, `~/.local/share/containers/storage` y `~/.local/state`; los mismos datos sobreviven con el código nuevo.
- Simulación con el repo real en un HOME temporal (sin tocar el home real): 73/73 archivos de `config/` desplegados, modos conservados (`755` scripts, `644` configs), `herdr` y datos de podman intactos, Handy sembrado, dos corridas idempotentes, 0 podas espurias.
- `bash -n` OK en `install.sh`, `04`, `09` y el spec. `shellcheck -x -e SC1091` sin hallazgos nuevos (SC1091 y SC2034 son baseline del repo).
- Sin cambios en `scripts/common.sh`: no aplica diferencial de helpers compartidos.

## Log

- L1 (pedido original, verbatim): «Paso nuevamente, al aplicar los dotfiles perdi datos por ejemplo herdr ya no se reconoce como comando, ademas vi que el instalador trataba de borrar directorios como los contenedores de podman y otras configuraciones que despues no se pueden recuperar, habra que rediseñar los scripts para que la limpieza solo toque (borre y ponga nuevamente) solo las cosas que este proyecto reconstruye, mejor si es de alguna manera dinámica sino cada vez que actualizo algo, por ejemplo dotfiles tengo que recomponer comandos, variables de entorno, reconstruir contenedores, etc»
- L2 (evidencia del orquestador): `~/.local/bin` no existe; `~/.config`, `~/.config/sway`, `~/.config/foot`, `~/.config/i3` con mtime del último apply; `podman ps -a` sin contenedores (imágenes sí). Compatible con el `rm -rf ~/.local` del reset.
