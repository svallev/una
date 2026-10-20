#!/usr/bin/env bash
# Tamaño de descarga (spec 020, CA-020-02 punto 7, enmendado por la 023, CA-023-20; antes un bucle de
# ci.yml): falla si algún APK de release por ABI pesa 20 MB o más **comprimido** (antes 25).
#
#   tools/check-size.sh                         (los app-*-release.apk de app/build/app/outputs/flutter-apk/,
#                                                tras `flutter build apk --release --split-per-abi`)
#   tools/check-size.sh <apk>...                (los APK dados)
#   tools/check-size.sh --dir <carpeta> ...     (otra carpeta para el caso sin argumentos: pruebas)
#   tools/check-size.sh --limit-mb <N> ...      (otro umbral, en MB enteros: pruebas)
#
# El tamaño se enseña con un decimal (`13,9 MB`: coma, y **truncado**, para que un paquete que pasa nunca
# salga como «20,0 MB»); es solo para mostrarlo: la comparación sigue en bytes enteros. Con
# `GITHUB_STEP_SUMMARY` definido, añade además una línea por APK al resumen del trabajo (CA-023-20:
# «su resumen enseña el tamaño de cada uno»; solo el nombre del archivo, nunca la ruta).
#
# Las librerías nativas van sin comprimir dentro del APK (extractNativeLibs=false); la tienda
# descarga comprimido. Se mide el APK comprimido (gzip -9), que se parece a la descarga real
# (spec 008: con PDFium, ~12,7 MB en arm64 frente a 27 MB del archivo). Falla cerrada: ningún APK
# que medir, o uno que no existe, es un fallo. Códigos: 0 bien, 1 fallo, 2 uso incorrecto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dir="$ROOT/app/build/app/outputs/flutter-apk"
limit_mb=20
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

# Bytes → «13,9» (MiB con un decimal, truncado, con coma; sin depender del idioma del sistema).
mb_text() {
  local tenths=$(($1 * 10 / 1048576))
  echo "$((tenths / 10)),$((tenths % 10))"
}

status=0
summary="${GITHUB_STEP_SUMMARY:-}"
for apk in "${apks[@]}"; do
  if [ ! -f "$apk" ]; then
    echo "::error::No existe el paquete: $apk"
    status=1
    continue
  fi
  raw=$(wc -c < "$apk" | tr -d ' ')
  size=$(gzip -9 -c "$apk" | wc -c | tr -d ' ')
  shown="$(mb_text "$size") MB"
  echo "$apk: $(mb_text "$raw") MB en disco, $shown comprimido"
  verdict=""
  if [ "$size" -ge $((limit_mb * 1024 * 1024)) ]; then
    echo "::error::$apk: $shown comprimido, supera el límite (menos de $limit_mb MB)"
    verdict=" — **supera el límite**"
    status=1
  fi
  if [ -n "$summary" ]; then
    # Solo informa: que el resumen no se pueda escribir no cambia el resultado de la comprobación.
    echo "- \`$(basename "$apk")\`: $shown comprimido (límite: menos de $limit_mb MB)$verdict" >> "$summary" || true
  fi
done
exit "$status"
