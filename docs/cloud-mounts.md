# Montajes de nube: Google Drive y OneDrive con rclone

Los dos proveedores se montan **como sistemas de archivos** (FUSE), no se
sincronizan: los archivos viven en la nube, la caché local es sólo una ventana
temporal de `rclone mount`. Cada proveedor queda en `~/Cloud/<remote>` y se
automonta con una unidad de **systemd de usuario** (`rclone@gdrive.service`,
`rclone@onedrive.service`), sin root.

**Es por usuario, no por máquina.** Cada usuario de la PC corre
`./scripts/13-setup-cloud-mounts.sh` en su propia sesión y obtiene sus propios
`~/.credentials/` (un `<remote>.env` por proveedor), su `~/.config/rclone/rclone.conf` (con su refresh token
OAuth 2.0) y sus puntos de montaje. El `client_id` de la aplicación OAuth se
puede compartir entre todos, pero **cada uno autoriza con su cuenta**. Nadie
hereda tokens de otro usuario.

| Pieza | Dónde vive | Modo |
|---|---|---|
| Directorio de credenciales | `~/.credentials/` | `700` |
| `client_id` / `client_secret` de la app OAuth | `~/.credentials/gdrive.env`, `~/.credentials/onedrive.env` | `600`, fuera de git |
| JSON original que descarga Google | `~/.credentials/gdrive.json` (archivo de consulta) | `600`, fuera de git |
| Refresh token de cada cuenta | `~/.config/rclone/rclone.conf` | `600`, fuera de git |
| Plantilla de unidad | `~/.config/systemd/user/rclone@.service` (repo: `config/home/…`) | — |
| Puntos de montaje | `~/Cloud/gdrive`, `~/Cloud/onedrive` | — |

La unidad lee el archivo con `EnvironmentFile=%h/.credentials/%i.env`: el
nombre de la instancia elige el archivo (`rclone@gdrive.service` →
`gdrive.env`). Por eso el `.env` **tiene que existir** aunque sólo tenga
comentarios; si falta, systemd falla en voz alta en lugar de arrancar un remote
a medias.

## 1. Crear la app OAuth de Google Drive

El `client_id` compartido de rclone («This shared client_id is being retired and
will stop working during 2026») ya no sirve, así que hay que crear una app
propia. Es una sola vez y sirve para todos los usuarios de la PC.

En <https://console.cloud.google.com/>:

1. **Crear el proyecto.** Arriba a la izquierda, selector de proyectos →
   *New project* → nombre (p. ej. `rclone-drive`) → *Create*. Esperá a que
   quede seleccionado.
2. **Habilitar la API.** *APIs & Services* → *Library* → buscá **Google Drive
   API** → *Enable*.
3. **Pantalla de consentimiento.** *APIs & Services* → *OAuth consent screen*
   (en la consola nueva: *Google Auth Platform* → *Branding*):
   - *User type*: **External** (salvo que sea una cuenta de Google Workspace,
     donde conviene *Internal*).
   - *App name* (p. ej. `rclone`), *User support email*, *Developer contact
     email*. El resto se puede dejar vacío.
   - *Scopes*: no hace falta agregar nada a mano; rclone pide `.../auth/drive`
     en el momento de autorizar.
   - *Test users*: sólo hacen falta mientras la app esté en *Testing*.
4. **Publicar la app.** *OAuth consent screen* → *Publish app* → **In
   production**. Esto es lo que evita el problema caro de abajo: en *Testing*
   Google **expira el refresh token a los 7 días** y el montaje empieza a
   fallar con `invalid_grant` sin explicación. Publicada y sin verificar, la
   app sirve para uso personal con hasta 100 usuarios y muestra una pantalla de
   advertencia que se acepta con *Advanced → Go to &lt;app&gt; (unsafe)*.
5. **Crear la credencial.** *APIs & Services* → *Credentials* → *Create
   credentials* → **OAuth client ID** → *Application type*: **Desktop app** →
   nombre → *Create*. Google muestra el **Client ID** y el **Client secret**;
   copialos ahora (el secret también se puede volver a ver después).

> El tipo tiene que ser **Desktop app**: rclone escucha la respuesta del OAuth
> en `http://127.0.0.1:53682/` y ese flujo sólo está permitido para clientes de
> escritorio. Si se elige *Web application*, hay que registrar esa URI de
> redirección a mano.

## 2. Guardar las credenciales

El JSON que descarga Google **no es el archivo que usa rclone**:
`EnvironmentFile=` de systemd lee `KEY=VALOR` por línea, no JSON. El JSON sólo
contiene el mismo par de valores dentro de `installed`. Así que hay dos caminos,
y el script hace el trabajo:

```bash
# opción A: el script convierte el JSON (y lo archiva como gdrive.json)
./scripts/13-setup-cloud-mounts.sh --google-json ~/Descargas/client_secret_5138...apps.googleusercontent.com.json

# opción B: a mano, editando el env que el script genera
$EDITOR ~/.credentials/gdrive.env
```

El resultado es siempre el mismo archivo:

```bash
# ~/.credentials/gdrive.env  (600, directorio 700)
RCLONE_DRIVE_CLIENT_ID=1234567890-abcdefg.apps.googleusercontent.com
RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxx
```

Los nombres son los que rclone ya interpreta como variables de entorno
(`RCLONE_<BACKEND>_<OPTION>`), así que no hace falta ningún script traductor.

Reglas del script con estos archivos: **crea el directorio y los `.env` con la
plantilla comentada si faltan, y nunca pisa uno que ya exista** (sólo corrige el
modo a `600`). Con `--google-json` se niega a sobrescribir un `gdrive.env` que
ya tiene credenciales reales: rotar el `client_id` obliga a reautorizar, así que
esa decisión no se toma sola. El JSON original se archiva como
`~/.credentials/gdrive.json` (nombre corto) y no lo lee nadie en tiempo de
ejecución: sirve para volver a mirarlo si hay que rotar el secreto.

`--provider gdrive` sólo toca `gdrive.env`; `--provider both` crea los dos. Un
`~/.credentials` que sea un *archivo* (layout viejo) ya no se acepta: el script
falla y pide migrarlo a directorio.

## 3. Instalar y montar

```bash
sudo zypper install rclone rclone-bash-completion rclone-zsh-completion
cd ~/dotfiles && ./scripts/04-setup-dotfiles.sh   # despliega rclone@.service
./scripts/13-setup-cloud-mounts.sh                 # pregunta qué remotes preparar
```

El script, en orden: verifica `rclone`, `fusermount3` y la plantilla de unidad;
crea `~/.credentials/` (700) con un `<remote>.env` (600) por proveedor si
faltan, sin pisar los que existan, y **aborta** si queda algún `CHANGEME`; crea
el punto de montaje; si el remote no existe lanza `rclone config create` (abre el
navegador una sola vez, con el `client_id` del `.env`); y por último
`systemctl --user daemon-reload` + `enable --now`. Si el remote ya existe no
repite el OAuth.

```bash
./scripts/13-setup-cloud-mounts.sh --provider gdrive|onedrive|both
./scripts/13-setup-cloud-mounts.sh --check          # sólo lectura, informa y sale 1 si falta algo
```

Para OneDrive no hace falta registrar una app: rclone trae un `client_id`
embebido que funciona. Si se quiere una app propia de Entra ID, descomentar
`RCLONE_ONEDRIVE_CLIENT_ID`/`_SECRET` en `~/.credentials/onedrive.env`.

## 4. Varios usuarios en la misma PC

No hay estado compartido ni pasos de root. Cada usuario:

1. tiene la plantilla de unidad en su `~/.config/systemd/user/` (la despliega
   `04-setup-dotfiles.sh` en su propio HOME);
2. guarda el mismo `client_id` en su `~/.credentials/gdrive.env` (o el suyo, si
   prefiere su propia app);
3. corre `./scripts/13-setup-cloud-mounts.sh` y autoriza **con su cuenta** de
   Google en el navegador;
4. opcionalmente activa `loginctl enable-linger $USER` para que el montaje
   arranque en el boot aunque no haya iniciado sesión. Sin linger, arranca al
   iniciar sesión (el script avisa, no lo impone).

`install.sh` no corre el paso de montaje como root: si se elige el componente
*Nube (rclone)* con `sudo`, sólo instala los paquetes y avisa que hay que
correrlo con el usuario.

## 5. Verificación

```bash
./scripts/13-setup-cloud-mounts.sh --check --provider both
systemctl --user status rclone@gdrive.service
rclone about gdrive:          # cuota y tipo de cuenta
findmnt ~/Cloud/gdrive        # debe decir fuse.rclone
touch ~/Cloud/gdrive/prueba && ls ~/Cloud/gdrive && rm ~/Cloud/gdrive/prueba
```

Pruebas que valen la pena después del primer montaje: reiniciar la máquina
(el montaje debe volver solo), cortar la red y volver a conectarla
(`Restart=on-failure` + caché VFS), y suspender/despertar.

## Diagrama

[diagramas/cloud-mounts.mmd](./diagramas/cloud-mounts.mmd): cómo se conectan
`~/.credentials/<remote>.env`, `rclone.conf`, la unidad `rclone@.service` y
`~/Cloud/<remote>`.

## Trampas

- **App en *Testing* ⇒ `invalid_grant` cada 7 días.** Publicarla *In
  production* (sin verificar) es lo que evita reautorizar todas las semanas.
- **Cambiar el `client_id`/`client_secret` en `~/.credentials/gdrive.env` no
  basta**: el refresh token guardado en `rclone.conf` fue emitido por el
  client_id anterior y el montaje falla con `401`. Después de rotarlo hay que
  reautorizar con `rclone config reconnect gdrive:` (o borrar el remote y
  volver a crearlo). Por eso `--google-json` se niega a pisar un `.env` que ya
  tiene credenciales reales.
- **`--vfs-cache-mode full` es obligatorio** para este uso: sin caché, un
  programa que escribe y lee el mismo archivo (un editor, un `git`, un
  guardado parcial) recibe errores de E/S. El costo es espacio en
  `~/.cache/rclone` (10 GB y 7 días de tope en la plantilla).
- **Desmontar a mano**: `fusermount3 -uz ~/Cloud/gdrive`. El `-z` (lazy) es la
  única salida cuando quedó I/O pendiente; la unidad ya lo usa en `ExecStop=`.
- **`After=network-online.target` no sirve en unidades de usuario**: no espera
  a NetworkManager. Por eso la plantilla no lo usa; la red se resuelve con
  `Restart=on-failure` y la caché.
- **No hay `--allow-other` ni `user_allow_other`**: el montaje es de un usuario
  y sólo ese usuario lo ve. Es la razón de no montarlo global en `/mnt`.
