#!/usr/bin/env bash
# Falla si el libpdfium.so de algún APK de release no es el fijado en tools/pdfium.lock
# (threat-model §5: pdfium_dart lo descarga al compilar sin verificarlo).
#
#   tools/check-pdfium.sh      (desde app/, tras `flutter build apk --release --split-per-abi`)
set -euo pipefail

LOCK="$(dirname "$0")/pdfium.lock"
sha256() { if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

status=0
checked=0
while read -r abi expected; do
  case "$abi" in ''|'#'*) continue ;; esac
  apk="build/app/outputs/flutter-apk/app-$abi-release.apk"
  if [ ! -f "$apk" ]; then
    echo "::error::No existe $apk. Compila antes: flutter build apk --release --split-per-abi"
    status=1
    continue
  fi
  actual="$(unzip -p "$apk" "lib/$abi/libpdfium.so" | sha256)"
  if [ "$actual" != "$expected" ]; then
    echo "::error::libpdfium.so de $abi no coincide con tools/pdfium.lock ($actual)"
    status=1
  else
    echo "OK $abi libpdfium.so $actual"
  fi
  checked=$((checked + 1))
done < "$LOCK"

[ "$checked" -gt 0 ] || { echo "::error::tools/pdfium.lock no tiene ninguna huella"; exit 1; }
exit "$status"
