#!/usr/bin/env bash
# Falla si el libpdfium.so de algún paquete de release no es el fijado en tools/pdfium.lock
# (threat-model §5: pdfium_dart lo descarga al compilar sin verificarlo).
#
#   tools/check-pdfium.sh               (desde app/, tras `flutter build apk --release --split-per-abi`:
#                                        los tres APK por ABI de build/app/outputs/flutter-apk/)
#   tools/check-pdfium.sh <apk|aab>...  (los paquetes dados; spec 020, CA-020-02)
#   tools/check-pdfium.sh --ios [--package-config <archivo>] [--artifacts <carpeta>] [--require-built]
#                                       (iOS, spec 028, T-028-08; ver más abajo)
#
# Con paquetes dados:
#   - un AAB: `base/lib/<abi>/libpdfium.so` de **todos** los ABI del lock;
#   - un APK por ABI (`app-<abi>-release.apk`): el `lib/<abi>/libpdfium.so` de su ABI;
#   - cualquier otro APK (el universal): el de todos los ABI.
# Falla cerrada: sin ningún paquete que comprobar, un paquete que no existe o no se lee, o un ABI sin
# su biblioteca es un fallo, nunca un verde.
set -euo pipefail

sha256() { if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

# ─────────────────────────────────── iOS (spec 028, T-028-08, CA-028-17) ───────────────────────────────────
# En iOS no entra el .so de Android: PDFium es un XCFramework binario de `pdfium_flutter` (Swift Package
# Manager lo descarga y verifica contra la suma de su Package.swift; el podspec hace lo mismo para
# CocoaPods) y SQLite es una descarga del hook de `sqlite3`, verificada contra `asset_hashes.dart`.
# Este modo fija esas huellas en tools/ios-binaries.lock para que cambiarlas sea una decisión visible:
#   1. el PAQUETE (siempre): url y checksum del Package.swift y del podspec de pdfium_flutter, y
#      releaseTag y las sumas de iOS de sqlite3, leídos de la carpeta de cada paquete (se localiza con
#      el package_config.json de `flutter pub get`);
#   2. lo COMPILADO (si está): los binarios de iOS del XCFramework que deja SwiftPM en
#      build/ios/SourcePackages/artifacts/ y las descargas de SQLite del hook. Con --require-built,
#      que falten es un fallo (la CI lo pasa tras `flutter build ios`).
# Falla cerrada: un lock, paquete, archivo o línea que falta o no se entiende es un fallo, nunca un verde.
# Desde app/. Necesita python3 (solo para leer package_config.json).
check_ios() {
  local lock config artifacts require=0 status=0
  lock="$(dirname "$0")/ios-binaries.lock"
  config=".dart_tool/package_config.json"
  artifacts="build/ios/SourcePackages/artifacts"
  while [ $# -gt 0 ]; do
    case "$1" in
      --package-config)
        [ $# -ge 2 ] || { echo "::error::--package-config necesita un valor" >&2; return 2; }
        config="$2"; shift 2 ;;
      --artifacts)
        [ $# -ge 2 ] || { echo "::error::--artifacts necesita un valor" >&2; return 2; }
        artifacts="$2"; shift 2 ;;
      --require-built) require=1; shift ;;
      *) echo "::error::Opción desconocida de --ios: $1" >&2; return 2 ;;
    esac
  done

  # La suma es de 64 caracteres hexadecimales en minúscula (LC_ALL=C: sin que el idioma amplíe la clase).
  is_sum() { [ "${#1}" -eq 64 ] && [ -z "$(printf '%s' "$1" | LC_ALL=C tr -d '0123456789abcdef')" ]; }

  # ── el lock ──
  [ -f "$lock" ] || { echo "::error::No existe $lock"; return 1; }
  local url="" zip="" release=""
  local slices=() slice_sums=() sqlite_files=() sqlite_sums=()
  local kind a b
  while read -r kind a b _; do
    case "$kind" in
      ''|'#'*) continue ;;
      xcframework-url) url="$a" ;;
      xcframework-zip) zip="$a" ;;
      sqlite3-release) release="$a" ;;
      slice) slices+=("$a"); slice_sums+=("$b") ;;
      sqlite3) sqlite_files+=("$a"); sqlite_sums+=("$b") ;;
      *) echo "::error::tools/ios-binaries.lock: línea desconocida «${kind}»"; status=1 ;;
    esac
  done < "$lock"
  [ -n "$url" ] || { echo "::error::tools/ios-binaries.lock no tiene xcframework-url"; status=1; }
  if ! is_sum "$zip"; then echo "::error::tools/ios-binaries.lock: xcframework-zip falta o no es un sha256"; status=1; fi
  [ -n "$release" ] || { echo "::error::tools/ios-binaries.lock no tiene sqlite3-release"; status=1; }
  local want
  for want in ios-arm64 ios-arm64_x86_64-simulator; do
    local found=0 i
    for i in "${!slices[@]}"; do
      if [ "${slices[$i]}" = "$want" ]; then
        found=1
        is_sum "${slice_sums[$i]}" || { echo "::error::tools/ios-binaries.lock: la suma de slice $want no es un sha256"; status=1; }
      fi
    done
    [ "$found" -eq 1 ] || { echo "::error::tools/ios-binaries.lock no tiene slice $want"; status=1; }
  done
  for want in libsqlite3.arm64.ios.dylib libsqlite3.arm64.ios_sim.dylib libsqlite3.x64.ios_sim.dylib; do
    local found=0 i
    for i in "${!sqlite_files[@]}"; do
      if [ "${sqlite_files[$i]}" = "$want" ]; then
        found=1
        is_sum "${sqlite_sums[$i]}" || { echo "::error::tools/ios-binaries.lock: la suma de sqlite3 $want no es un sha256"; status=1; }
      fi
    done
    [ "$found" -eq 1 ] || { echo "::error::tools/ios-binaries.lock no tiene sqlite3 $want"; status=1; }
  done
  [ "$status" -eq 0 ] || return 1

  # ── los paquetes ──
  if [ ! -f "$config" ]; then
    echo "::error::No existe $config. Ejecuta antes: flutter pub get"
    return 1
  fi
  package_dir() {
    python3 -I - "$config" "$1" <<'PY'
import json, os, sys
from urllib.parse import unquote, urlparse
config, name = sys.argv[1], sys.argv[2]
with open(config, encoding="utf-8") as f:
    data = json.load(f)
for pkg in data.get("packages", []):
    if pkg.get("name") == name:
        root = pkg["rootUri"]
        if root.startswith("file:"):
            print(unquote(urlparse(root).path))
        else:
            print(os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(config)), unquote(root))))
        sys.exit(0)
sys.exit(1)
PY
  }
  local pdfium_dir sqlite_dir
  pdfium_dir="$(package_dir pdfium_flutter)" || { echo "::error::pdfium_flutter no está en $config"; return 1; }
  sqlite_dir="$(package_dir sqlite3)" || { echo "::error::sqlite3 no está en $config"; return 1; }

  # one_value <archivo> <etiqueta> <sed>: el único valor que saca el sed (cero o varios, fallo).
  one_value() {
    local file="$1" label="$2" expr="$3" values count
    [ -f "$file" ] || { echo "::error::$label: no existe $file" >&2; return 1; }
    values="$(sed -n "$expr" "$file")"
    count="$(printf '%s\n' "$values" | grep -c . || true)"
    [ "$count" -eq 1 ] || { echo "::error::$label: se esperaba un solo valor y hay $count en $file" >&2; return 1; }
    printf '%s' "$values"
  }
  # expect <etiqueta> <valor> <esperado> <qué>
  expect() {
    if [ "$2" != "$3" ]; then
      echo "::error::$1: $4 es «${2}» y tools/ios-binaries.lock fija «${3}»"
      status=1
    fi
  }

  local swift="$pdfium_dir/darwin/pdfium_flutter/Package.swift" pod="$pdfium_dir/darwin/pdfium_flutter.podspec" v
  if v="$(one_value "$swift" "pdfium_flutter Package.swift (url)" 's/.*url:[[:space:]]*"\([^"]*\)".*/\1/p')"; then
    expect "pdfium_flutter Package.swift" "$v" "$url" "la url"
  else status=1; fi
  if v="$(one_value "$swift" "pdfium_flutter Package.swift (checksum)" 's/.*checksum:[[:space:]]*"\([^"]*\)".*/\1/p')"; then
    expect "pdfium_flutter Package.swift" "$v" "$zip" "el checksum"
  else status=1; fi
  if v="$(one_value "$pod" "pdfium_flutter podspec (PDFIUM_URL)" 's/^PDFIUM_URL[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p')"; then
    expect "pdfium_flutter podspec" "$v" "$url" "PDFIUM_URL"
  else status=1; fi
  if v="$(one_value "$pod" "pdfium_flutter podspec (PDFIUM_HASH)" 's/^PDFIUM_HASH[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p')"; then
    expect "pdfium_flutter podspec" "$v" "$zip" "PDFIUM_HASH"
  else status=1; fi
  [ "$status" -ne 0 ] || echo "OK pdfium_flutter Package.swift y podspec: $zip"

  local hashes="$sqlite_dir/lib/src/hook/asset_hashes.dart"
  if v="$(one_value "$hashes" "sqlite3 asset_hashes.dart (releaseTag)" "s/^const String? releaseTag = '\\([^']*\\)';.*/\\1/p")"; then
    expect "sqlite3 asset_hashes.dart" "$v" "$release" "releaseTag"
    [ "$v" != "$release" ] || echo "OK sqlite3 releaseTag $release"
  else status=1; fi
  local f got
  for i in "${!sqlite_files[@]}"; do
    f="${sqlite_files[$i]}"
    got=""
    if [ -f "$hashes" ]; then
      got="$(awk -v k="'$f':" '$1 == k { print $2 }' "$hashes" | tr -d "',")"
    fi
    if [ -z "$got" ]; then
      echo "::error::sqlite3 asset_hashes.dart no tiene $f (o no se pudo leer $hashes)"
      status=1
    elif [ "$got" != "${sqlite_sums[$i]}" ]; then
      echo "::error::sqlite3 asset_hashes.dart: la suma de $f es $got y tools/ios-binaries.lock fija ${sqlite_sums[$i]}"
      status=1
    else
      echo "OK sqlite3 $f $got"
    fi
  done

  # ── lo compilado ──
  local xcframeworks=() xc
  if [ -d "$artifacts" ]; then
    while IFS= read -r xc; do
      [ -n "$xc" ] && xcframeworks+=("$xc")
    done < <(find "$artifacts" -type d -name PDFium.xcframework 2>/dev/null | sort || true)
  fi
  if [ "${#xcframeworks[@]}" -eq 0 ]; then
    if [ "$require" -eq 1 ]; then
      echo "::error::No hay ningún XCFramework de PDFium (PDFium.xcframework) compilado en $artifacts. Compila antes: flutter build ios"
      status=1
    else
      echo "aviso: sin XCFramework compilado en $artifacts: solo se comprobó el paquete (compila con flutter build ios para comprobar el binario)"
    fi
  fi
  local binary actual
  for xc in "${xcframeworks[@]+"${xcframeworks[@]}"}"; do
    for i in "${!slices[@]}"; do
      binary="$xc/${slices[$i]}/PDFium.framework/PDFium"
      if [ ! -f "$binary" ]; then
        echo "::error::$xc no tiene ${slices[$i]}/PDFium.framework/PDFium"
        status=1
        continue
      fi
      actual="$(sha256 < "$binary")"
      if [ "$actual" != "${slice_sums[$i]}" ]; then
        echo "::error::PDFium ${slices[$i]} en $xc no coincide con tools/ios-binaries.lock ($actual)"
        status=1
      else
        echo "OK PDFium ${slices[$i]} $actual"
      fi
    done
  done

  local cache downloads=0 dl
  cache="$(dirname "$config")/hooks_runner/shared/sqlite3/build"
  for i in "${!sqlite_files[@]}"; do
    dl="$cache/download-${sqlite_sums[$i]:0:8}/libsqlite3.dylib"
    [ -f "$dl" ] || continue
    downloads=$((downloads + 1))
    actual="$(sha256 < "$dl")"
    if [ "$actual" != "${sqlite_sums[$i]}" ]; then
      echo "::error::La descarga de SQLite ${sqlite_files[$i]} ($dl) no coincide con tools/ios-binaries.lock ($actual)"
      status=1
    else
      echo "OK sqlite3 descargado ${sqlite_files[$i]} $actual"
    fi
  done
  if [ "$require" -eq 1 ] && [ "$downloads" -eq 0 ]; then
    echo "::error::No hay ninguna descarga de sqlite3 en $cache. Compila antes: flutter build ios"
    status=1
  fi
  return "$status"
}

if [ "${1:-}" = "--ios" ]; then
  shift
  check_ios "$@"
  exit $?
fi

LOCK="$(dirname "$0")/pdfium.lock"

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
  # Sin `grep -q` en la tubería: con `pipefail`, un grep que encuentra pronto y sale corta a `unzip`
  # (SIGPIPE) y daba por ausente una biblioteca que sí estaba (intermitente, visto en T-020-07).
  if ! unzip -Z1 "$package" 2>/dev/null | grep -xF "$entry" >/dev/null; then
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
