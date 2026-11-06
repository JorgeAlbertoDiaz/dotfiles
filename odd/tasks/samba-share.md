# Samba: compartir ~/Projects sólo al usuario del sistema

Componente opcional del instalador que publica la carpeta `Projects` por
SMB/CIFS con autenticación de Samba, restringida a un único usuario y
declarada en el repo (paquete, script, docs y spec).

## Specs

- **S1 — Toda la carpeta Projects queda compartida.** El share publica la
  carpeta completa (`~/Projects`, sin subconjuntos ni exclusiones), con
  lectura y escritura, navegable y con el nombre `projects`. Pedido: «compartir
  … toda la carpeta Projects».
- **S2 — Sólo el usuario jorge puede entrar.** El share declara
  `valid users = <usuario>` con el usuario que corre el script (en este
  servidor, `jorge`) y `map to guest = Never`: ninguna sesión anónima o de
  invitado pasa, y ningún otro usuario del sistema accede aunque exista en la
  base de Samba. Pedido: «compartir solo al usuario jorge».
- **S3 — Todo lo que se instala o configura queda en el repo.** El paquete
  declarado (`packages/samba.txt`), el script idempotente
  (`scripts/14-setup-samba.sh`), el componente en `install.sh`, la
  documentación (`docs/samba.md` + `docs/index.md` + `README.md`) y la spec
  (`scripts/tests/14-setup-samba-spec.sh`). Ningún paso manual fuera del repo
  salvo la contraseña de Samba, que es un secreto y no se versiona. Pedido:
  «si instalas o configuras algo recuerda agregarlo al repo».
- **S4 — Trabajo en rama aparte, sin tocar la rama en curso.** El trabajo vive
  en `feat/samba-share` creada desde `feat/cloud-mounts`, y al terminar la
  sesión se vuelve a `feat/cloud-mounts`. Pedido: «puedes crear una feature
  branch ahora y al finalizar volver a la rama actual».

## Tasks

- [x] T1 — `scripts/tests/14-setup-samba-spec.sh`: spec con dobles en `PATH` (RED 34 fallos → 65/0) · S1,S2 · inline · `b47e2e0`
- [x] T2 — `packages/samba.txt` + componente «Samba (share de Projects)» en `install.sh` · S3 · inline · slice de cableado
- [x] T3 — `scripts/14-setup-samba.sh`: `smb.conf` gestionado, servicio `smb`, firewalld y usuario de Samba · S1,S2 · inline · `e8e6770`
- [x] T4 — `docs/samba.md` + registro en `docs/index.md` y `README.md` · S3 · inline · slice de cableado
- [ ] T5 — aplicar en este servidor (requiere `sudo` interactivo y contraseña de Samba) · S1,S2 · manual
- [ ] T6 — commits por slice y vuelta a `feat/cloud-mounts` · S4 · inline

## Log

- **L1** (pedido original, verbatim): «tengo un cambio en proceso pero esto es
  mas urgente, quiero configurar samba en este servidor para compartir solo al
  usuario jorge toda la carpeta Projects, si instalas o configuras algo
  recuerda agregarlo al repo, puedes crear una feature branch ahora y al
  finalizar volver a la rama actual»
- **E1** (evidencia, entorno): openSUSE Tumbleweed `20261028`; `samba`,
  `samba-client` y `samba-userspace` no instalados; `/etc/samba/` vacío (sin
  `smb.conf`); `firewalld` activo; usuario `jorge` uid 1000 con grupos
  `jorge,video,ollama`; `/home/jorge/Projects` en `/dev/mapper/system-home`;
  `sudo` pide contraseña (sin sudo sin contraseña).
- **E2** (evidencia, repo): no existía ninguna mención a Samba; el patrón a
  seguir es `scripts/13-setup-cloud-mounts.sh` + `scripts/tests/13-…-spec.sh`
  (HOME temporal, copia del repo y dobles en `PATH`).
- **L2** (decisión de alcance): el share es de lectura y escritura para el
  usuario del script; la contraseña de Samba la define la persona con
  `smbpasswd -a` porque es un secreto y no se versiona.
- **E3** (evidencia, T1/T3): spec 65/0 en verde; RED inicial 34 fallos con el
  script ausente. Verificación independiente (`gentle-ai-verify`): PASS en
  S1-S4; dos observaciones aplicadas — la marca de archivo gestionado ahora
  sólo vale en la primera línea (`head -n 1`), y la spec prueba que `--user`
  y `--name` se reflejan en la configuración (caso `--user root --name
  compartido`).
- **E4** (frontera de slices): tres commits en `feat/samba-share`: spec
  (`b47e2e0`), script (`e8e6770`) y cableado + documentación + este documento.
  La rama arrastra los commits previos de `feat/cloud-mounts`; el corte de
  slices de esta feature empieza en `f272599`.
- **E5** (evidencia, regresión): `scripts/tests/install-flatpak-menu-spec.sh`
  falló con el componente nuevo (`exit 127`: la instalación completa llamaba a
  `14-setup-samba.sh`, que no tenía stub en el fixture). Se agregó el stub, la
  spec volvió a 15/0 y el caso «instalación completa» ahora ejercita el
  componente. Confirmado contra `f272599` (copia con `git archive`): ahí
  pasaba, así que el fallo era de este cambio.

