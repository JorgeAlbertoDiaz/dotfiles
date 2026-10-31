# Aplicar dotfiles: despliegue y limpieza acotada

`scripts/04-setup-dotfiles.sh` es el único script que escribe en `$HOME` a
partir de `config/`. Este documento explica **qué despliega, qué limpia y qué
nunca toca**, porque la versión anterior borraba directorios completos
(`~/.config/<app>` y cada entrada de `config/home/`) cuando se respondía «sí»
al reset de fábrica.

## Qué despliega

En cada corrida el script recorre `config/` y calcula, sin listas escritas a
mano, el conjunto exacto de archivos y enlaces que corresponden a cada app:

| Origen en el repo | Destino |
|---|---|
| `config/<app>/**` | `~/.config/<app>/**` |
| `config/home/**` | `$HOME/**` |

Agregar o quitar un archivo en `config/` alcanza para que la próxima
aplicación lo despliegue (o lo pode); no hay que tocar el script.

Los archivos se copian uno por uno con `cp -a`, así que se conservan modo y
timestamps. Antes de copiar se borra **solo ese destino**, para reemplazar un
enlace simbólico en lugar de escribir a través de él.

## Inventario

El conjunto calculado se guarda en:

```text
${XDG_STATE_HOME:-~/.local/state}/dotfiles/desplegado.tsv
```

Formato: `origen<TAB>ruta relativa al home`, una línea por archivo. Es
descartable: se reescribe en cada aplicación y sirve para saber qué dejó el
repo la última vez. Para leerlo:

```bash
grep -v '^#' ~/.local/state/dotfiles/desplegado.tsv
```

La primera corrida con esta versión solo escribe el inventario: no hay
inventario anterior, así que no borra nada.

## Qué limpia (y qué no)

La poda borra únicamente entradas del inventario anterior que cumplen las tres
condiciones:

1. su origen (`app` o `home`) está en la selección actual, y
2. el repo ya no declara ese archivo, y
3. no es un dato mutable de una aplicación (ver abajo).

Con `todos`, además se limpian los orígenes de apps que ya no existen en
`config/`. Si aplicás una sola app, el inventario de las demás se conserva.

Nunca se ejecuta `rm -rf` sobre un directorio del usuario. Después de borrar
un archivo gestionado se intenta `rmdir` de los directorios que quedaron
**vacíos**, y la subida se detiene en `~/.config`, `~/.local`,
`~/.local/share`, `~/.local/state` y `~/.local/bin`. Un directorio con
contenido ajeno nunca se borra, aunque el repo lo haya creado.

Las rutas del inventario se validan antes de borrar: si una entrada es
absoluta o contiene `..`, se ignora con un aviso. El inventario no puede
sacar el borrado fuera de `$HOME`.

### Datos de aplicaciones

Los destinos bajo `~/.local/share/` y `~/.local/state/` son **datos** que
escribe la aplicación, no configuración del repo. El script los siembra si
faltan, pero:

- no los pisa si ya existen, y
- no los poda nunca, aunque el repo deje de sembrarlos.

Ejemplo: un archivo en `config/home/.local/share/<app>/` es la plantilla de
ajustes por defecto de esa app. Si ya tenés ajustes propios, aplicar dotfiles
no los resetea.

## Ejemplo

```text
~/.local/bin/herdr                      # binario del usuario: nunca se toca
~/.local/share/containers/storage/...   # datos de podman: nunca se tocan
~/.config/environment.d/99-local.conf   # variable propia: nunca se toca
~/.config/sway/mi-extra.conf            # archivo propio: nunca se toca

config/sway → ~/.config/sway            # archivos del repo: se despliegan
archivo quitado de config/sway          # estaba en el inventario: se poda
```

## Qué pasó con la versión anterior

El reset de fábrica hacía `rm -rf` de `~/.config/<app>` y de cada entrada de
primer nivel de `config/home/`. Como `config/home/.local/` existe para sembrar
los ajustes de Handy, el reset borraba `~/.local` entero: `~/.local/bin`
(por ejemplo `herdr`), `~/.local/share/containers` (podman) y
`~/.local/state`. Nada de eso lo reconstruye el repo.

Esa versión ya no existe: no hay pregunta de reset y el borrado es el descrito
arriba. Para recuperar lo que se perdió:

- **herdr**: se reinstala con su instalador oficial
  (`curl -fsSL https://herdr.dev/install.sh | sh`).
- **contenedores de podman**: las imágenes y el storage pueden haber
  sobrevivido, pero los contenedores no; se recrean con el `compose.yaml` o
  los comandos de cada proyecto.
- **variables de entorno**: las del repo las vuelve a desplegar
  `04-setup-dotfiles.sh`; las propias (por ejemplo
  `~/.config/environment.d/99-local.conf`) hay que rehacerlas, porque nunca
  estuvieron en el repo.
