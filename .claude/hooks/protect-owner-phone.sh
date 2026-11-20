#!/usr/bin/env bash
# PreToolUse (Bash): protege la instalación de Una del móvil del propietario (Xiaomi).
# `flutter drive/run/install` borró dos veces la app base (invalid.pending.app) con sus datos
# (2026-09-25 y 2026-11-20: al fallar la instalación, flutter desinstala el id base).
# Bloquea:
#   1. flutter drive|run|install, o flutter test con integration_test, contra el Xiaomi
#      o sin -d/--device-id (flutter elegiría el móvil si es el único conectado).
#   2. Desinstalar o vaciar la app base: uninstall / pm clear de invalid.pending.app sin sufijo.
# En el móvil se instala a mano con `adb install` y avisando antes (docs/testing.md).
# Exit 2 = bloquear (stderr llega a Claude).
set -uo pipefail

PHONE_SERIAL='6DRO9TE6WG59CM8T'
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$CMD" ] && exit 0

block() {
  echo "Bloqueado para proteger la app del propietario en su Xiaomi: $1 Ver docs/testing.md (móvil del propietario): usa el emulador o el simulador, o instala el APK a mano con adb install avisando antes." >&2
  exit 2
}

# 2. Desinstalar o vaciar la app base (sin .debug/.profile).
if printf '%s' "$CMD" | grep -Eq '(uninstall|pm[[:space:]]+clear)[^;&|]*invalid\.pending\.app([^.A-Za-z0-9_]|$)'; then
  block "no se desinstala ni se vacía invalid.pending.app (la app base, con los datos del propietario)."
fi

# 1. flutter que instala en un dispositivo.
if printf '%s' "$CMD" | grep -Eq 'flutter[[:space:]]+(drive|run|install)([[:space:]]|$)' \
  || printf '%s' "$CMD" | grep -Eq 'flutter[[:space:]]+test[^;&|]*integration_test'; then
  if printf '%s' "$CMD" | grep -q "$PHONE_SERIAL"; then
    block "flutter no instala en el Xiaomi del propietario ($PHONE_SERIAL)."
  fi
  if ! printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])(-d|--device-id|--device)([[:space:]=])'; then
    block "flutter drive/run/install o los tests de integración necesitan -d con el emulador o el simulador (sin -d elegiría el móvil si está conectado)."
  fi
  if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])(-d|--device-id)[[:space:]=]+all([[:space:]]|$)'; then
    block "-d all incluiría el móvil del propietario."
  fi
fi

exit 0
