#!/bin/bash

# ESTILO DE LOS TEXTOS
export NORMAL="0;"
export NEGRITA="1;"
export ATENUADA="2;"
export CURSIVA="3;"
export SUBRAYADO="4;"
export PARPADEO="5;"
export PARPADEO_INTENSO="6;"
export INVERTIDO="7;"
export OCULTO="8;"
export TACHADO="9;"

# COLOR DEL TEXTO
export FG_NEGRO="30;"
export FG_ROJO="31;"
export FG_VERDE="32;"
export FG_AMARILLO="33;"
export FG_AZUL="34;"
export FG_MORADO="35;"
export FG_CIAN="36;"
export FG_GRIS="37;"
export FG_BLANCO="38;"
export FG_RESET="39;"

# COLOR DEL FONDO
export BG_NEGRO="40"
export BG_ROJO="41"
export BG_VERDE="42"
export BG_AMARILLO="43"
export BG_AZUL="44"
export BG_MORADO="45"
export BG_CIAN="46"
export BG_GRIS="47"
export BG_BLANCO="48"
export BG_RESET="49"

export COD_ESCAPE_INICIAL="\e["
export COD_ESCAPE_FINAL="m"

export RESET="\033[0m"

function primary_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_GRIS}${BG_AZUL}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function secondary_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${CURSIVA}${FG_NEGRO}${BG_GRIS}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function success_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_GRIS}${BG_VERDE}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function danger_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${PARPADEO_INTENSO}${FG_GRIS}${BG_ROJO}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function warning_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_GRIS}${BG_AMARILLO}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function info_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_GRIS}${BG_CIAN}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function dark_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_GRIS}${BG_NEGRO}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

function light_message() {
  echo -e "\n${COD_ESCAPE_INICIAL}${NEGRITA}${FG_NEGRO}${BG_GRIS}${COD_ESCAPE_FINAL} $1 ${RESET}"
}

# Prueba de funcionamiento...
# clear
# primary_message "Este es un mensaje tiene el estilo de PRIMARY"
# secondary_message "Este es un mensaje tiene el estilo de SECONDARY"
# success_message "Este es un mensaje tiene el estilo de SUCCESS"
# danger_message "Este es un mensaje tiene el estilo de DANGER"
# warning_message "Este es un mensaje tiene el estilo de WARNING"
# info_message "Este es un mensaje tiene el estilo de INFO"
# dark_message "Este es un mensaje tiene el estilo de DARK"
# light_message "Este es un mensaje tiene el estilo de DARK"


