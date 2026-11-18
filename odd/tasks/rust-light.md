# Tema claro rust-light: paleta mdBook `rust` en todo el escritorio

Rama: `feat/rust-light`. Riesgo bajo (paleta visual, reversible con `sway-theme.sh toggle`).
Fuente única de color: las variables CSS del tema `rust` de mdBook citadas en S2.

## Specs

- **S1** — «Quiero que modifiques el theme lignt, ahora esta demasiado blanco».

- **S2** — Fuente única de la paleta. Variables CSS del tema `rust` de mdBook, verbatim:

```css
.rust {
    --bg: hsl(60, 9%, 87%);
    --fg: #262625;

    --sidebar-bg: #3b2e2a;
    --sidebar-fg: #c8c9db;
    --sidebar-non-existant: #505254;
    --sidebar-active: #e69f67;
    --sidebar-spacer: #45373a;

    --scrollbar: var(--sidebar-fg);

    --icons: #737480;
    --icons-hover: #262625;

    --links: #2b79a2;

    --inline-code-color: #6e6b5e;

    --theme-popup-bg: #e1e1db;
    --theme-popup-border: #b38f6b;
    --theme-hover: #99908a;

    --quote-bg: hsl(60, 5%, 75%);
    --quote-border: hsl(60, 5%, 70%);

    --warning-border: #ff8e00;

    --table-border-color: hsl(60, 9%, 82%);
    --table-header-bg: #b3a497;
    --table-alternate-bg: hsl(60, 9%, 84%);

    --searchbar-border-color: #aaa;
    --searchbar-bg: #fafafa;
    --searchbar-fg: #000;
    --searchbar-shadow-color: #aaa;
    --searchresults-header-fg: #666;
    --searchresults-border-color: #888;
    --searchresults-li-bg: #dec2a2;
    --search-mark-bg: #e69f67;

    /* Same as `--icons` */
    --copy-button-filter: invert(51%) sepia(10%) saturate(393%) hue-rotate(198deg) brightness(86%) contrast(87%);
    /* Same as `--sidebar-active` */
    --copy-button-filter-hover: invert(77%) sepia(16%) saturate(1798%) hue-rotate(328deg) brightness(98%) contrast(83%);

    --footnote-highlight: #d3a17a;

    --overlay-bg: rgba(150, 150, 150, 0.25);

    --blockquote-note-color: #023b95;
    --blockquote-tip-color: #007700;
    --blockquote-important-color: #8250df;
    --blockquote-warning-color: #603700;
    --blockquote-caution-color: #aa1721;

    --sidebar-header-border-color: #8c391f;
}
```

- **S3** — «herdr tiene partes que no se leen en el menu lateral derecho»: todo texto del
  sidebar de herdr tiene que superar contraste WCAG AA (≥ 4.5:1) contra el fondo que usa.

- **S4** — «Los paneles, tiene un bg mas oscuro (si puedes hacer que tambien herdr lo tenga asi al panel mejor)»:
  toda superficie de panel (chips de waybar, tarjetas de swaync, launcher, popups, panel de
  herdr) usa un fondo más oscuro que `--bg`, no el mismo blanco.

- **S5** — «el swaybar quiero que tenga ese color de sidebar-bg lo mismo el panel de notificaciones»:
  barra de waybar y centro de notificaciones de swaync con fondo `#3b2e2a`.

- **S6** — «el sidebar-fg no es blanco pero es claro, extiende este esquema de colores en otros»:
  `#c8c9db` es el color de texto de todas las superficies oscuras (barra, notificaciones,
  launcher, popups, tmux), nunca blanco puro.

- **S7** — «extiende este esquema a todo el sistema sway, waybar, lo de notificaciones, el launcher de aplicaciones, herdr, tmux».

- **S8** — «Haz una nueva rama para implementar este cambio».

- **S9** — «no termine de sincronizar las carpetas cloud»: no se ejecuta
  `scripts/13-setup-cloud-mounts.sh` ni ninguna sincronización; el cambio se aplica sólo al
  escritorio y queda en la rama.

- **S10** — Decisión del humano sobre herdr/tmux (respuesta a la consulta de alcance):
  «Versionar y aplicar ahora» — se agregan `config/herdr/` y `config/tmux/` al repo, se
  enganchan en `sway-theme.sh` y se aplican a `~/.config` en esta sesión.

- **S11** — Decisión del humano sobre superficies oscuras: «También launcher y popups» —
  wofi, popups/menús de waybar, OSD de wob y título de ventana de sway en oscuro.

### Derivados de S2 (no son requisitos nuevos)

Los `hsl()` de S2 se materializan en hex, porque sway/CSS/toml/wob/swaylock sólo aceptan hex:
`--bg` `#E1E1DB` · `--quote-bg` `#C2C2BC` · `--quote-border` `#B6B6AF` ·
`--table-border-color` `#D5D5CD` · `--table-alternate-bg` `#DADAD3`.

Roles estables (mismo hex en todos los componentes):

| Rol | Hex | Variable rust |
| --- | --- | --- |
| superficie documento | `#E1E1DB` | `--bg` / `--theme-popup-bg` |
| texto documento | `#262625` | `--fg` |
| chrome (barra, notificaciones, launcher, tmux) | `#3B2E2A` | `--sidebar-bg` |
| texto sobre chrome | `#C8C9DB` | `--sidebar-fg` |
| chrome elevado (chips, tarjetas, input) | `#45373A` | `--sidebar-spacer` |
| chrome hover | `#505254` | `--sidebar-non-existant` |
| acento / activo | `#E69F67` | `--sidebar-active` / `--search-mark-bg` |
| texto sobre acento | `#262625` | `--fg` |
| borde de popup | `#B38F6B` | `--theme-popup-border` |
| panel atenuado (documento) | `#C2C2BC` | `--quote-bg` |
| borde de documento | `#B6B6AF` | `--quote-border` |
| borde de tabla | `#D5D5CD` | `--table-border-color` |
| superficie alterna | `#DADAD3` | `--table-alternate-bg` |
| cabecera atenuada | `#B3A497` | `--table-header-bg` |
| texto secundario (documento) | `#6E6B5E` | `--inline-code-color` |
| texto secundario (chrome) | `#99908A` | `--theme-hover` |
| enlaces / info | `#2B79A2` | `--links` |
| peligro / urgente | `#AA1721` | `--blockquote-caution-color` |
| aviso | `#FF8E00` | `--warning-border` |
| marca / selección | `#DEC2A2` | `--searchresults-li-bg` |
| realce | `#D3A17A` | `--footnote-highlight` |
| título de sidebar | `#8C391F` | `--sidebar-header-border-color` |

## Tasks

- [x] **T1** — S1-S2: paleta y colores de cliente en `config/sway/themes/light.conf` · commit `feat(sway): tema claro con paleta rust-light`
- [x] **T2** — S4-S6: barra oscura y chips en `config/waybar/themes/light.css` · commit `feat(waybar): barra con sidebar-bg y chips rust-light`
- [x] **T3** — S4-S5: centro de notificaciones oscuro en `config/swaync/themes/light.css` · commit `feat(swaync): panel de notificaciones con sidebar-bg`
- [x] **T4** — S4-S7: launcher y OSD en `config/wofi/themes/light.css` y `config/wob/themes/light.ini` · commit `feat(wofi): launcher oscuro con la paleta rust-light`
- [x] **T5** — S1, S6-S7: lock, terminal y nvim en `config/swaylock/themes/light.conf`, `config/foot/foot.ini`, `config/nvim/lua/config/theme.lua` · commit `feat(foot): documento claro y lock con paleta rust-light`
- [x] **T6** — S3-S6, S10-S11: herdr versionado (`config/herdr/`) y hook en `config/sway/scripts/sway-theme.sh` · commit `feat(herdr): tema rust-light versionado y sidebar legible`
- [x] **T7** — S6-S7, S10: tmux versionado (`config/tmux/`) y hook en `sway-theme.sh` · commit `feat(tmux): barra de estado con la paleta rust-light`
- [ ] **T8** — S3-S7: spec de contraste + docs (`docs/tema-claro-oscuro.md`, `docs/organizacion-sway.md`) · commit `docs(tema): documenta la paleta rust-light y su verificación`

## Log

- **L5** — Corte de rebanada: los commits de T1-T4 (sway, waybar, swaync, wofi+wob) suman
  ~460 líneas autoradas. La feature entera es un solo cambio de paleta sobre la misma rama
  `feat/rust-light`; la rebanada siguiente (foot/nvim, herdr, tmux, docs+spec) sigue en la
  misma rama porque comparte la tabla de roles y se revisa mejor con el contexto completo.

- **L1** — «Quiero que modifiques el theme lignt, ahora esta demasiado blanco, herdr tiene partes que no se leen en el menu lateral derecho, me gustaria que usaras la configuracion de css de rust para las variables

```css
.rust {
    --bg: hsl(60, 9%, 87%);
    --fg: #262625;

    --sidebar-bg: #3b2e2a;
    --sidebar-fg: #c8c9db;
    --sidebar-non-existant: #505254;
    --sidebar-active: #e69f67;
    --sidebar-spacer: #45373a;

    --scrollbar: var(--sidebar-fg);

    --icons: #737480;
    --icons-hover: #262625;

    --links: #2b79a2;

    --inline-code-color: #6e6b5e;

    --theme-popup-bg: #e1e1db;
    --theme-popup-border: #b38f6b;
    --theme-hover: #99908a;

    --quote-bg: hsl(60, 5%, 75%);
    --quote-border: hsl(60, 5%, 70%);

    --warning-border: #ff8e00;

    --table-border-color: hsl(60, 9%, 82%);
    --table-header-bg: #b3a497;
    --table-alternate-bg: hsl(60, 9%, 84%);

    --searchbar-border-color: #aaa;
    --searchbar-bg: #fafafa;
    --searchbar-fg: #000;
    --searchbar-shadow-color: #aaa;
    --searchresults-header-fg: #666;
    --searchresults-border-color: #888;
    --searchresults-li-bg: #dec2a2;
    --search-mark-bg: #e69f67;

    /* Same as `--icons` */
    --copy-button-filter: invert(51%) sepia(10%) saturate(393%) hue-rotate(198deg) brightness(86%) contrast(87%);
    /* Same as `--sidebar-active` */
    --copy-button-filter-hover: invert(77%) sepia(16%) saturate(1798%) hue-rotate(328deg) brightness(98%) contrast(83%);

    --footnote-highlight: #d3a17a;

    --overlay-bg: rgba(150, 150, 150, 0.25);

    --blockquote-note-color: #023b95;
    --blockquote-tip-color: #007700;
    --blockquote-important-color: #8250df;
    --blockquote-warning-color: #603700;
    --blockquote-caution-color: #aa1721;

    --sidebar-header-border-color: #8c391f;
}
```

Los paneles, tiene un bg mas oscuro (si puedes hacer que tambien herdr lo tenga asi al panel mejor), el swaybar quiero que tenga ese color de sidebar-bg lo mismo el panel de notificaciones, el sidebar-fg no es blanco pero es claro, extiende este esquema de colores en otros, extiende este esquema a todo el sistema sway, waybar, lo de notificaciones, el launcher de aplicaicones, herdr, tmux. Haz una nueva rama para implementar este cambio, no termine de sincronizar las carpetas cloud».

- **L2** — Alcance herdr/tmux: «Versionar y aplicar ahora» (config/herdr + config/tmux en el repo,
  hook en `sway-theme.sh`, aplicado a `~/.config` en esta sesión).

- **L3** — Superficies oscuras: «También launcher y popups» (wofi, popups de waybar, OSD de wob,
  título de ventana de sway en oscuro).

- **L4** — Evidencia de exploración: herdr acepta `[theme] name/auto_switch` y
  `[theme.custom]` con tokens `accent panel_bg sidebar_bg active_row_bg selection_bg
  surface0 surface1 surface_dim overlay0 overlay1 text subtext0 mauve green yellow red blue
  teal peach`; base clara disponible `catppuccin-latte`. tmux 3.8 lee `~/.config/tmux/tmux.conf`.
  `scripts/04-setup-dotfiles.sh` descubre apps por directorio de `config/`: agregar
  `config/herdr/` y `config/tmux/` los versiona sin tocar el instalador.
