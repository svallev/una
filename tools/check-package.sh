#!/usr/bin/env bash
# Estática MASTG del paquete de release (spec 020, CA-020-22): falla si el APK compilado es depurable,
# admite tráfico en claro, pierde las reglas de copia o de transferencia, expone un proveedor o una
# ruta de archivos de más, baja del minSdk/targetSdk esperado, lleva algo con forma de secreto o un
# archivo de firma, o pierde los ajustes de privacidad de hoy (`app/tool/check_package.dart`).
#
#   tools/check-package.sh                      (los APK de release por ABI de app/build, tras compilar
#                                                `flutter build apk --release --split-per-abi`)
#   tools/check-package.sh <apk>...             (otros paquetes; rutas absolutas o relativas a donde estés)
#   tools/check-package.sh --aapt2 <ruta> ...   (otro aapt2 que el de las build-tools más nuevas del SDK)
#
# Las excepciones de la regla de secretos están en tools/release/secret-allowlist.txt. Falla cerrada:
# sin ningún paquete (0 entradas), un paquete que no existe o un volcado de aapt2 que no se entiende
# es un fallo, nunca un verde. Necesita `dart`, `aapt2` y `unzip`; no instala nada ni usa la red.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

abs_file() {
  local dir
  dir="$(dirname "$1")"
  if [ -d "$dir" ]; then
    echo "$(cd "$dir" && pwd)/$(basename "$1")"
  else
    case "$1" in
      /*) echo "$1" ;;
      *) echo "$PWD/$1" ;;
    esac
  fi
}

args=()
packages=()
while [ $# -gt 0 ]; do
  case "$1" in
    --aapt2)
      [ $# -ge 2 ] || { echo "::error::--aapt2 necesita un valor"; exit 2; }
      args+=("--aapt2" "$(abs_file "$2")")
      shift 2
      ;;
    --allowlist)
      [ $# -ge 2 ] || { echo "::error::--allowlist necesita un valor"; exit 2; }
      args+=("--allowlist" "$(abs_file "$2")")
      shift 2
      ;;
    --*)
      echo "::error::argumento desconocido: $1" >&2
      exit 2
      ;;
    *)
      packages+=("$(abs_file "$1")")
      shift
      ;;
  esac
done

if [ "${#packages[@]}" -eq 0 ]; then
  # Los APK de release por ABI (no el universal ni los de debug o profile).
  for apk in "$ROOT"/app/build/app/outputs/flutter-apk/app-*-release.apk; do
    [ -e "$apk" ] && packages+=("$apk")
  done
  if [ "${#packages[@]}" -eq 0 ]; then
    echo "::error::No hay ningún APK de release en app/build/app/outputs/flutter-apk/. Compila antes: flutter build apk --release --split-per-abi"
    exit 1
  fi
fi

cd "$ROOT/app"
exec dart run tool/check_package.dart --allowlist "$ROOT/tools/release/secret-allowlist.txt" "${args[@]+"${args[@]}"}" "${packages[@]}"
