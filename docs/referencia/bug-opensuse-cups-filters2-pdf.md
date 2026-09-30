# openSUSE: `cups-filters2` no instala las reglas MIME de conversión de PDF

Nota de referencia del workaround que aplica
`scripts/drivers/driver-impresora-hp-smart-tank-580.sh` (sección 2b).

- **Producto / componente:** openSUSE Tumbleweed → Printing
- **Paquete:** `cups-filters2`
- **Versión observada:** `cups-filters2-2.0.1-2.1` (con `cups-2.4.19-3.1`)
- **Efecto:** no se puede imprimir ningún PDF ni PostScript de usuario (nada
  desde Firefox, LibreOffice, GTK, `lp archivo.pdf`).

## Síntoma

La impresora se lista, responde al ping, su servidor web interno imprime su
propia página de prueba, pero los trabajos enviados desde el sistema no salen y
desaparecen de la cola. `/var/log/cups/error_log`:

```
E [..] Returning IPP client-error-document-format-not-supported for Print-Job
       (ipp://localhost:631/printers/HP_Smart_Tank_580) from localhost.
```

La cola sólo acepta estos formatos:

```console
$ ipptool -tv ipp://localhost:631/printers/HP_Smart_Tank_580 get-printer-attributes.test \
    | grep document-format-supported
        document-format-supported (1setOf mimeMediaType) = application/octet-stream,
        application/vnd.cups-raster, application/vnd.cups-raw, image/jpeg, image/urf
```

No hay `application/pdf` ni `application/postscript`.

## Causa

CUPS no envía el archivo a la impresora: el scheduler construye una **cadena de
filtros** a partir de su base MIME (`*.types` / `*.convs`). Para una impresora
sin PDF nativo (la del caso soporta PCL3GUI, JPEG, PCLm, urf y PWG-raster) la
cadena es:

```
application/pdf --pdftopdf--> application/vnd.cups-pdf --pdftoraster--> image/urf
```

Las reglas de esa cadena viven en los fragmentos
`cupsfilters-individual.convs`, `cupsfilters-poppler.convs` y
`cupsfilters-ghostscript.convs`, que upstream instala en
`$(CUPS_DATADIR)/mime` cuando está habilitado `--enable-individual-cups-filters`
(`Makefile.am`, bloque `if ENABLE_INDIVIDUAL_CUPS_FILTERS`).

El spec de openSUSE pasa `--disable-universal-cups-filter` pero **no** pasa
`--enable-individual-cups-filters`, y `configure.ac` deja ese flag en `no` por
defecto:

```m4
AC_ARG_ENABLE([individual-cups-filters],
        [AS_HELP_STRING([--enable-individual-cups-filters], [...])],
        [enable_individual_cups_filters="$enableval"],
        [enable_individual_cups_filters=no]
)
```

Resultado: no se instala ni el juego *universal* ni el *individual*. Sólo llega
`cupsfilters.convs` (reglas de texto), aunque el propio `%files` del paquete
espera `%{_datadir}/cups/mime/*`. Los **filtros** sí se instalan
(`pdftopdf`, `pdftoraster`, `gstoraster`, `bannertopdf`…) y quedan inutilizados
porque ninguna regla los encadena.

Verificación (mismo resultado en el filesystem y en el RPM publicado):

```console
$ rpm -qpl cups-filters2-2.0.1-2.1.x86_64.rpm | grep mime
/usr/share/cups/mime
/usr/share/cups/mime/cupsfilters.convs
/usr/share/cups/mime/cupsfilters.types

$ find / -xdev -name '*.convs' -path '*cups*'
/usr/share/cups/mime/mime.convs          # cups, sin reglas PDF
/usr/share/cups/mime/cupsfilters.convs   # sólo reglas de texto
```

## Reproducción sin impresora

`cupsfilter` usa la misma base MIME y acepta `CUPS_DATADIR`, así que el bug se
comprueba en el lugar:

```console
$ gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=/tmp/p.pdf <cualquier .ps>
$ cupsfilter -m image/urf -p /usr/share/cups/ppd/<cola>.ppd /tmp/p.pdf; echo $?
1                      # sin cadena: no genera nada

$ cp -r /usr/share/cups/mime /tmp/m && cp <tarball>/mime/cupsfilters-*.convs /tmp/m/
$ CUPS_DATADIR=/tmp/m cupsfilter -m image/urf -p /usr/share/cups/ppd/<cola>.ppd /tmp/p.pdf; echo $?
0                      # pdftopdf -> gstoraster -> JCL
```

## Arreglo sugerido

Agregar `--enable-individual-cups-filters` al `%configure` de
`cups-filters2.spec`, junto a `--disable-universal-cups-filter`. Los archivos ya
vienen en el tarball y el `%files` ya los declara.

Síntoma secundario del mismo bug: `system-config-printer` habilita "imprimir
página de prueba" sólo si la cola anuncia `application/postscript`
(`printerproperties.py`), así que el botón aparece deshabilitado.

## Workaround aplicado

Instalar los tres fragmentos del tarball upstream
(`cups-filters-2.0.1.tar.xz`, verificados por `sha256`) en
`/usr/share/cups/mime/` y reiniciar `cups.service`.

Son archivos **no administrados por RPM**: cuando `cups-filters2` publique el
arreglo hay que borrarlos para evitar conflicto de archivos. El script detecta
la capacidad (busca `pdftoraster` en los `*.convs`) y no hace nada si el paquete
ya trae las reglas.

Documentación de soporte:

- `man 5 mime.convs` — formato y ubicación de los archivos de conversión.
- Upstream `Makefile.am`, bloque `if ENABLE_INDIVIDUAL_CUPS_FILTERS`.
