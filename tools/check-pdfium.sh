#!/usr/bin/env bash
# Falla si el libpdfium.so de algún paquete de release no es el fijado en tools/pdfium.lock
# (threat-model §5: pdfium_dart lo descarga al compilar sin verificarlo).
#
#   tools/check-pdfium.sh               (desde app/, tras `flutter build apk --release --split-per-abi`:
#                                        los tres APK por ABI de build/app/outputs/flutter-apk/)
#   tools/check-pdfium.sh <apk|aab>...  (los paquetes dados; spec 020, CA-020-02)
#
# Con paquetes dados:
#   - un AAB: `base/lib/<abi>/libpdfium.so` de **todos** los ABI del lock;
#   - un APK por ABI (`app-<abi>-release.apk`): el `lib/<abi>/libpdfium.so` de su ABI;
#   - cualquier otro APK (el universal): el de todos los ABI.
# Falla cerrada: sin ningún paquete que comprobar, un paquete que no existe o no se lee, o un ABI sin
# su biblioteca es un fallo, nunca un verde.
set -euo pipefail

LOCK="$(dirname "$0")/pdfium.lock"
sha256() { if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

# Los ABI y huellas del lock.
abis=()
sums=()
while read -r abi expected; do
  case "$abi" in ''|'#'*) continue ;; esac
  abis+=("$abi")
  sums+=("$expected")
done < "$LOCK"
[ "${#abis[@]}" -gt 0 ] || { echo "::error::tools/pdfium.lock no tiene ninguna huella"; exit 1; }

status=0

# check_entry <paquete> <entrada> <abi> <huella esperada>
check_entry() {
  local package="$1" entry="$2" abi="$3" expected="$4" actual
  if ! unzip -Z1 "$package" 2>/dev/null | grep -qxF "$entry"; then
    echo "::error::$package no tiene $entry (libpdfium.so de $abi)"
    status=1
    return
  fi
  actual="$(unzip -p "$package" "$entry" | sha256)"
  if [ "$actual" != "$expected" ]; then
    echo "::error::libpdfium.so de $abi en $package no coincide con tools/pdfium.lock ($actual)"
    status=1
  else
    echo "OK $abi libpdfium.so $actual"
  fi
  }

if [ "$#" -eq 0 ]; then
  for i in "${!abis[@]}"; do
    apk="build/app/outputs/flutter-apk/app-${abis[$i]}-release.apk"
    if [ ! -f "$apk" ]; then
      echo "::error::No existe $apk. Compila antes: flutter build apk --release --split-per-abi"
      status=1
      continue
    fi
    check_entry "$apk" "lib/${abis[$i]}/libpdfium.so" "${abis[$i]}" "${sums[$i]}"
  done
else
  for package in "$@"; do
    if [ ! -f "$package" ]; then
      echo "::error::No existe el paquete: $package"
      status=1
      continue
    fi
    if ! unzip -Z1 "$package" >/dev/null 2>&1; then
      echo "::error::$package no es un zip legible"
      status=1
      continue
    fi
    prefix="lib"
    only=""
    case "$package" in
      *.aab) prefix="base/lib" ;;
      *)
        # Un APK por ABI lleva su ABI en el nombre (app-<abi>-release.apk): solo esa biblioteca.
        name="$(basename "$package")"
        for abi in "${abis[@]}"; do
          case "$name" in *"-$abi-"*) only="$abi" ;; esac
        done
        ;;
    esac
    for i in "${!abis[@]}"; do
      abi="${abis[$i]}"
      [ -n "$only" ] && [ "$only" != "$abi" ] && continue
      check_entry "$package" "$prefix/$abi/libpdfium.so" "$abi" "${sums[$i]}"
    done
  done
fi

exit "$status"
