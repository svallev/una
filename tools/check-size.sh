#!/usr/bin/env bash
# Tamaño de descarga (spec 020, CA-020-02 punto 7; antes un bucle de ci.yml): falla si algún APK de
# release por ABI pesa 25 MB o más **comprimido**.
#
#   tools/check-size.sh                         (los app-*-release.apk de app/build/app/outputs/flutter-apk/,
#                                                tras `flutter build apk --release --split-per-abi`)
#   tools/check-size.sh <apk>...                (los APK dados)
#   tools/check-size.sh --dir <carpeta> ...     (otra carpeta para el caso sin argumentos: pruebas)
#   tools/check-size.sh --limit-mb <N> ...      (otro umbral, en MB enteros: pruebas)
#
# Las librerías nativas van sin comprimir dentro del APK (extractNativeLibs=false); la tienda
# descarga comprimido. Se mide el APK comprimido (gzip -9), que se parece a la descarga real
# (spec 008: con PDFium, ~12,7 MB en arm64 frente a 27 MB del archivo). Falla cerrada: ningún APK
# que medir, o uno que no existe, es un fallo. Códigos: 0 bien, 1 fallo, 2 uso incorrecto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dir="$ROOT/app/build/app/outputs/flutter-apk"
limit_mb=25
apks=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { echo "::error::--dir necesita un valor" >&2; exit 2; }
      dir="$2"
      shift 2
      ;;
    --limit-mb)
      [ $# -ge 2 ] || { echo "::error::--limit-mb necesita un valor" >&2; exit 2; }
      case "$2" in
        '' | *[!0-9]*) echo "::error::--limit-mb necesita un número entero" >&2; exit 2 ;;
      esac
      [ "$2" -ge 1 ] || { echo "::error::--limit-mb tiene que ser al menos 1" >&2; exit 2; }
      limit_mb="$2"
      shift 2
      ;;
    --*)
      echo "::error::argumento desconocido: $1" >&2
      exit 2
      ;;
    *)
      apks+=("$1")
      shift
      ;;
  esac
done

if [ "${#apks[@]}" -eq 0 ]; then
  for apk in "$dir"/app-*-release.apk; do
    [ -e "$apk" ] && apks+=("$apk")
  done
fi
if [ "${#apks[@]}" -eq 0 ]; then
  echo "::error::No hay ningún APK de release que medir en $dir. Compila antes: flutter build apk --release --split-per-abi"
  exit 1
fi

status=0
for apk in "${apks[@]}"; do
  if [ ! -f "$apk" ]; then
    echo "::error::No existe el paquete: $apk"
    status=1
    continue
  fi
  raw=$(wc -c < "$apk" | tr -d ' ')
  size=$(gzip -9 -c "$apk" | wc -c | tr -d ' ')
  echo "$apk: $((raw / 1024 / 1024)) MB en disco, $((size / 1024 / 1024)) MB comprimido"
  if [ "$size" -ge $((limit_mb * 1024 * 1024)) ]; then
    echo "::error::$apk supera $limit_mb MB comprimido"
    status=1
  fi
done
exit "$status"
