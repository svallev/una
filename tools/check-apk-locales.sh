#!/usr/bin/env bash
# Falla si un APK de release no trae recursos propios en catalán, español e inglés (spec 024,
# CA-024-04, H-022-10).
#
# Por qué: al crear los recursos de la actividad, Android pone delante de la lista de idiomas del
# sistema el primero que la app tiene como recurso (el inglés cuenta siempre). Si la app no tiene
# `values-ca/`, con `ca-ES, en-US` el sistema entrega `en-US, ca-ES` y la app sale en inglés. El
# APK de debug no sirve para comprobarlo: trae recursos `ca` de librerías y el reordenamiento no se
# da; el de release los recorta y solo deja los que la app usa de verdad.
#
#   tools/check-apk-locales.sh [--aapt2 <ruta>] [<apk>...]
#       (sin APK: los de release de app/build/app/outputs/flutter-apk/ —`app-release.apk` o los
#        `app-<abi>-release.apk`—, tras compilar con `flutter build apk --release [--split-per-abi]`)
#
# Mira `aapt2 dump configurations`: `ca` y `es` tienen que salir como idioma propio (`ca`, `es` o con
# región, `ca-rES`) y el inglés es la configuración por defecto (`values/`, línea vacía). Falla
# cerrada: sin APK, un APK que no existe o un volcado que no se lee es un fallo, nunca un verde.
# Necesita `aapt2` (build-tools del SDK de Android); no instala nada ni usa la red.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AAPT2=""
packages=()
while [ $# -gt 0 ]; do
  case "$1" in
    --aapt2)
      [ $# -ge 2 ] || { echo "::error::--aapt2 necesita un valor" >&2; exit 2; }
      AAPT2="$2"
      shift 2
      ;;
    --*)
      echo "::error::argumento desconocido: $1" >&2
      exit 2
      ;;
    *)
      packages+=("$1")
      shift
      ;;
  esac
done

# El aapt2 de las build-tools más nuevas de $ANDROID_HOME (o las carpetas habituales del SDK).
find_aapt2() {
  local root dir best=""
  for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "${HOME:-}/Library/Android/sdk" "${HOME:-}/Android/Sdk"; do
    [ -n "$root" ] && [ -d "$root/build-tools" ] || continue
    while IFS= read -r dir; do
      [ -x "$dir/aapt2" ] && best="$dir/aapt2"
    done < <(ls -1 "$root/build-tools" | sort -V | sed "s#^#$root/build-tools/#")
    [ -n "$best" ] && { echo "$best"; return; }
  done
}

if [ -z "$AAPT2" ]; then
  AAPT2="$(find_aapt2)"
fi
if [ -z "$AAPT2" ] || [ ! -x "$AAPT2" ]; then
  echo "::error::No se encuentra aapt2: instala las build-tools del SDK de Android o pásalo con --aapt2" >&2
  exit 1
fi

if [ "${#packages[@]}" -eq 0 ]; then
  for apk in "$ROOT"/app/build/app/outputs/flutter-apk/app-release.apk "$ROOT"/app/build/app/outputs/flutter-apk/app-*-release.apk; do
    [ -e "$apk" ] && packages+=("$apk")
  done
  if [ "${#packages[@]}" -eq 0 ]; then
    echo "::error::No hay ningún APK de release en app/build/app/outputs/flutter-apk/. Compila antes: flutter build apk --release" >&2
    exit 1
  fi
fi

status=0
for apk in "${packages[@]}"; do
  if [ ! -f "$apk" ]; then
    echo "::error::No existe el paquete: $apk" >&2
    status=1
    continue
  fi
  # Sin tubería (SIGPIPE con `pipefail`, T-020-07): primero se lee el volcado.
  # El centinela `x` evita que `$(...)` se coma la línea vacía final (la configuración por defecto).
  if ! dump="$("$AAPT2" dump configurations "$apk" 2>/dev/null && echo x)"; then
    echo "::error::$apk: aapt2 no puede leer las configuraciones" >&2
    status=1
    continue
  fi
  dump="${dump%x}"
  if [ -z "${dump//[$'\n']/}" ]; then
    echo "::error::$apk: aapt2 no devolvió ninguna configuración (recursos recortados del todo o volcado ilegible)" >&2
    status=1
    continue
  fi
  apk_status=0
  # Configuraciones de idioma propio: `ca`, `es` o con región (`ca-rES`), sin otros calificadores
  # delante (v27, hdpi… son otras líneas).
  for lang in ca es; do
    if ! printf '%s' "$dump" | grep -E "^${lang}(-r[A-Z]{2})?\$" >/dev/null; then
      echo "::error::$apk no trae recursos en '$lang' (values-$lang): con el catalán primero en el sistema, el idioma de la app no es el que pide la 010 (CA-024-04)" >&2
      apk_status=1
    fi
  done
  # El inglés es la configuración por defecto (values/): una línea vacía en el volcado (`printf '%s'`
  # no añade la línea final que sí añadiría un here-string).
  if ! printf '%s' "$dump" | grep -E '^$' >/dev/null; then
    echo "::error::$apk no trae la configuración por defecto (values/, el inglés)" >&2
    apk_status=1
  fi
  if [ "$apk_status" -eq 0 ]; then
    echo "OK: $apk con recursos en ca, es y en (por defecto)"
  else
    status=1
  fi
done
exit "$status"
