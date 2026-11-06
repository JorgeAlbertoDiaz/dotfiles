# Samba: compartir `Projects` con un solo usuario

Publica una carpeta del home (por defecto `~/Projects`) por SMB/CIFS para que
otra máquina la vea como una unidad de red, con autenticación de Samba y un
único usuario autorizado. El script es `scripts/14-setup-samba.sh`; los
paquetes vienen de `packages/samba.txt` y el componente «Samba (share de
Projects)» del instalador hace las dos cosas.

La idea central: **no** se comparte el home, ni un subconjunto de `Projects`,
ni se abre un share de invitados. Se comparte la carpeta completa, con lectura
y escritura, y sólo el usuario que corre el script.

## 1. Requisito: la contraseña de Samba

Samba no usa la contraseña del sistema: tiene su propia base
(`passdb backend = tdbsam`). El script crea el usuario de Samba si falta y hay
terminal, y te pide la contraseña con `smbpasswd`. Si no hay terminal (o lo
corrés desde `install.sh` en modo desatendido), deja el comando a mano:

```bash
sudo smbpasswd -a jorge
```

Esa contraseña **no se versiona** y no la escribe el script: es un secreto.
Repetir `smbpasswd -a` sobre un usuario ya creado cambia su contraseña, así que
sólo hace falta cuando querés cambiarla.

## 2. Uso

```bash
./scripts/14-setup-samba.sh                    # ~/Projects de tu usuario, share "projects"
./scripts/14-setup-samba.sh --check            # sólo lectura: informa y sale 1 si falta algo
./scripts/14-setup-samba.sh --share ~/Projects --user jorge --name projects
./scripts/14-setup-samba.sh --force            # sobrescribe un smb.conf ajeno (con respaldo)
./scripts/14-setup-samba.sh --no-firewall      # no abre el servicio samba en firewalld
```

| Opción | Para qué |
| --- | --- |
| `--share RUTA` | carpeta a compartir (por defecto `~/Projects` del usuario) |
| `--name NOMBRE` | nombre del share en la red (por defecto `projects`) |
| `--user USUARIO` | único usuario autorizado (por defecto, el que corre el script) |
| `--check` | no muta nada; sale 1 si falta configuración, servicio, firewall o usuario |
| `--force` | acepta pisar un `/etc/samba/smb.conf` que no gestiona el repo |
| `--no-firewall` | no agrega el servicio `samba` a firewalld |
| `--quiet` | suprime `info`/`ok` (los avisos y errores siempre salen) |

Orden de lo que hace: verifica que samba esté instalado, valida usuario y
carpeta, escribe el `smb.conf`, lo valida con `testparm` **antes** de
instalarlo, habilita/reinicia el servicio `smb`, abre el servicio `samba` en
firewalld y crea el usuario de Samba.

## 3. Qué escribe

Un solo archivo, `/etc/samba/smb.conf`, completo y con marca de origen: si el
archivo no empieza con esa marca, el script se niega a tocarlo salvo `--force`
(y entonces deja un `smb.conf.bak.<fecha>` al lado). Es idempotente: con el
contenido ya al día no reescribe nada ni reinicia el servicio.

```ini
# gestionado por dotfiles (scripts/14-setup-samba.sh)
[global]
   security = user
   passdb backend = tdbsam
   map to guest = Never
   usershare allow guests = no
   load printers = no
   printing = bsd
   disable spoolss = yes
   server min protocol = SMB2_10

[projects]
   path = /home/jorge/Projects
   browseable = yes
   read only = no
   guest ok = no
   valid users = jorge
   create mask = 0664
   directory mask = 0775
```

Lo que sostiene «sólo este usuario»: `security = user` (nadie entra sin
autenticarse), `valid users = jorge` (aunque otro usuario exista en la base de
Samba, no pasa) y `map to guest = Never` + `guest ok = no` (ninguna sesión
anónima o de invitado, ni siquiera por error de credenciales). Los permisos
Unix de la carpeta no se tocan: la sesión corre como el usuario autenticado.

## 4. Servicio y firewall

- `systemctl enable --now smb` la primera vez; `systemctl restart smb` cuando
  cambió la configuración. `nmb` (NetBIOS) no se habilita: el descubrimiento
  por nombre es legado y la conexión va por 445.
- firewalld recibe `firewall-cmd --permanent --add-service=samba` +
  `--reload`, que abre 139/445 sólo para el servicio `samba`. Si firewalld no
  está corriendo, el script lo dice y no toca nada.

## 5. Cómo se conecta un cliente

| Sistema | Camino |
| --- | --- |
| Linux (GNOME/KDE) | *Otras ubicaciones* → `smb://<host>/projects` |
| Linux (CLI) | `smbclient //<host>/projects -U jorge` |
| Windows | `\\<host>\projects` (Explorer pide usuario y contraseña) |
| macOS | Finder → `Cmd+K` → `smb://<host>/projects` |

`<host>` es el nombre del equipo (`hostname`) o su IP. El nombre del share sale
de `--name`, no del nombre de la carpeta.

## 6. Verificación

```bash
./scripts/14-setup-samba.sh --check     # 0 = todo listo, 1 = falta algo
sudo testparm -s                        # valida el smb.conf instalado
systemctl is-enabled smb && systemctl is-active smb
sudo firewall-cmd --query-service=samba
sudo pdbedit -L | grep '^jorge:'
smbclient -L //localhost -U jorge       # pide contraseña y lista el share
```

Desde otra máquina, `smb://<host>/projects` tiene que pedir credenciales y
mostrar el contenido **completo** de `Projects`; `/home` y el resto del sistema
no deben verse por SMB.

## 7. Límites y trampas

- **No instala paquetes**: los declara `packages/samba.txt` y verifica que
  `smbd`, `testparm`, `pdbedit` y `smbpasswd` estén en `PATH`. Si faltan, dice
  el comando exacto (`sudo zypper in samba`).
- **No versiona la contraseña** de Samba ni la escribe en ningún archivo.
- **Sólo un usuario por share**: si querés otro share para otra persona, corré
  el script con otro `--name`, `--share` y `--user`; el archivo es uno solo y
  `--force` lo reemplaza, así que eso queda fuera de este componente.
- **AppArmor**: openSUSE confina `smbd` con un perfil. Si el share se conecta
  pero no se puede listar el contenido, mirá `sudo aa-status` y
  `journalctl -u smb -n 50` antes de tocar permisos: el problema suele ser
  el perfil, no la carpeta.
- **SMB1 no se habilita**: `server min protocol = SMB2_10`. Un cliente
  antiguo que sólo hable SMB1 no va a conectar, y no hay opción para bajarlo.
- **El home no se comparte**: sólo la carpeta pedida. `follow symlinks = yes`
  con `wide links = no` deja seguir enlaces que queden dentro de la carpeta
  compartida, pero no salir del árbol.
