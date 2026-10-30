#!/usr/bin/env bash
# workspace-inicial.sh — estado inicial de los dos monitores.
#
# Deja el workspace 1 enfocado en el monitor izquierdo y el 10 abierto en el
# derecho. Se invoca con `exec` desde features/workspaces.conf, o sea una sola
# vez por arranque: no se re-ejecuta en cada `swaymsg reload`, así que recargar
# la config no te mueve el foco.
#
# Por qué hace falta un script y no alcanza con las líneas
# `workspace <n> output <salida>`: esas líneas asignan el workspace cuando se
# crea, y al arrancar sway crea uno por monitor usando el PRIMER nombre asignado
# a cada uno. En el monitor derecho eso daría el 6. Para que arranque con el 10
# hay que cambiarse a él —sway lo crea en el monitor al que está asignado— y
# volver al 1; el 10 no se destruye porque queda como workspace enfocado del
# monitor derecho.
#
# La espera por el socket IPC es necesaria: el exec corre dentro del arranque de
# sway y no hay garantía de que `swaymsg` pueda conectarse en el instante cero.
# Sin ella, un arranque lento deja el monitor derecho sin workspace.
set -euo pipefail

readonly IZQUIERDA=1
readonly DERECHA=10
readonly ESPERA_MAXIMA=50   # intentos * 0.1 s = 5 s

esperar_ipc() {
  local intento
  for ((intento = 0; intento < ESPERA_MAXIMA; intento++)); do
    if swaymsg -t get_version >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

if ! esperar_ipc; then
  echo "workspace-inicial: el socket IPC de sway no respondió en 5 s; dejo los workspaces como están" >&2
  exit 1
fi

# 10: sway lo crea en el monitor derecho, porque así está asignado en
# features/workspaces.conf.
swaymsg "workspace number ${DERECHA}" >/dev/null

# ...y de vuelta al 1: el foco queda a la izquierda y el 10 sigue vivo a la
# derecha. Si el switch al 10 fallara, `set -e` corta acá y el foco no se mueve.
swaymsg "workspace number ${IZQUIERDA}" >/dev/null
