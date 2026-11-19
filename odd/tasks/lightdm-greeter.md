# Greeter de login (LightDM) con la paleta rust

El login se sentía ajeno al sistema: usaba el tema Greybird-geeko + wallpaper de
openSUSE mientras la sesión usa la paleta rust. Esta feature lo integra con la
misma paleta, elige variante por hora y toma el fondo de un archivo del repo.
Riesgo: alto (pantalla de autenticación + instalador del sistema).

## Specs

S1. El greeter de login usa la paleta rust del escritorio, no el branding de
    openSUSE: superficie/fondo/acento salen de `config/sway/themes/{dark,light}.conf`
    (`#2b2b27` `#33322e` `#e69f67` en oscuro; `#E1E1DB` `#3B2E2A` `#E69F67` en claro),
    y ningún color queda fuera de la paleta del tema.

S2. La variante se elige por hora local. Texto del humano: "Podria usar uno u otro
    segun la hora? ejemplo desde las 20:00 hasta las 07:59 del dia siguiente oscuro
    y durante las 08:00 hasta las 19:57 light?" → **oscuro de 20:00 a 07:59, claro
    de 08:00 a 19:59**. Horas completas: 19:57 y 20:00 se toman como cambio a las
    20:00 en punto.

S3. El fondo del login sale del repo para que el humano lo reemplace sin tocar
    scripts. Texto: "Me gustaria que se tome una imagen de los dotfiles luego yo
    podria solo reemplazar ese archivo para que la proxima vez lo tome, es mas
    facil asi solo hay que validar que dicho archivo exista puedes usar alguno del
    sistema operativo por defecto, pero mejor utiliza el background actual y haz un
    copia de ese archivo y dime en que ruta se guardara para saberlo" →
    - origen editable: `scripts/lightdm/background.png` (semilla = copia del fondo
      actual del greeter, `/usr/share/wallpapers/openSUSEdefault/contents/images/default.png`);
    - destino en el sistema: `/etc/lightdm/background.png`;
    - si el origen no existe, el instalador falla con mensaje explícito (no instala
      un greeter sin fondo).

S4. La instalación es idempotente y reversible: respalda los conf del sistema antes
    de tocarlos, conserva `user-session=sway` y el numlock del arranque, y no deja el
    login sin arrancar si un paso falla.

S5. El componente se instala desde `install.sh` como el resto y queda documentado en
    `docs/lightdm.md` + link en `docs/index.md`.

## Tasks

| ID | Specs | Ruta | Commit |
| --- | --- | --- | --- |
| T1 | S1-S5 | Rama `feat/login-rust` + esta ficha | `docs(odd)`: ficha del greeter |
| T2 | S1 | `scripts/lightdm/greeter/{dark,light}.css` | `feat(lightdm)`: tema rust-login |
| T3 | S2, S3 | `scripts/lightdm/bin/lightdm-greeter-setup`, `scripts/lightdm/lightdm-gtk-greeter.conf`, `background.png` | `feat(lightdm)`: helper por hora + conf |
| T4 | S4 | `scripts/15-setup-lightdm.sh` | `feat(lightdm)`: instalador idempotente |
| T5 | S1-S4 | `scripts/tests/15-setup-lightdm-spec.sh`, `scripts/tests/tema-paleta-spec.sh` | `test(lightdm)`: specs del greeter |
| T6 | S5 | `install.sh`, `docs/lightdm.md`, `docs/index.md`, `README.md` | `docs(lightdm)`: componente + docs |

## Log

L1 (humano, verbatim):

> Quiero que cambiemos un poco el theme del sddm manager (el que pide las credenciales de acceso al encender la PC). Actualmente como esta se siento como algo ajeno al sistema y el cómo se ve y siente ¿Podrias corregirlo? no se si puede tomar el color de los temas light/dark que ya tiene sway

L2 (evidencia, exploración): el sistema **no tiene SDDM** ni GDM. Corre
`/usr/sbin/lightdm` con `lightdm-gtk-greeter` 2.0.9 sobre GTK3, tema
`Greybird-geeko` y `background=/usr/share/wallpapers/openSUSEdefault/contents/images/default.png`
(`/etc/lightdm/lightdm-gtk-greeter.conf:11-13`). `display-manager-legacy.service`
pertenece al paquete `xdm` y es sólo el wrapper genérico, no el DM.
Decisión: reestilizar el greeter GTK existente en lugar de instalar SDDM.

L3 (humano, decisiones): variante por hora (ver S2), fondo desde un archivo del
repo con copia del actual (ver S3), instalar sin paquetes nuevos.

L4 (interpretación de S2): los minutos del mensaje (19:57 light, 20:00 dark) se
resuelven como horas completas porque el helper compara horas enteras: claro
08:00-19:59, oscuro 20:00-07:59. Si el humano quiere el minuto exacto, se cambia
`date +%H` por `date +%H%M` y los límites en un solo lugar (T3).
