#!/usr/bin/env bash
# Falla si algo que va dentro de un APK de release no tiene su licencia en la pantalla de
# licencias (spec 012, CA-012-03; threat-model §5). Comprueba, por cada APK:
#
#   1. Paquetes de Dart de release (`dart pub deps --no-dev`) ⊆ NOTICES de Flutter.
#   2. Cada `lib/<abi>/*.so` tiene su entrada conocida (uno desconocido falla; `libapp.so`,
#      que es el código de la app, se excluye).
#   3. Artefactos de Android (`releaseRuntimeClasspath`, sin `io.flutter:*`, cuyo aviso ya
#      va en NOTICES) ⊆ app/assets/licenses/android.txt.
#   4. Las fuentes empaquetadas van con su OFL, y los archivos de licencias propios
#      (pdfium, sqlite, android) van dentro del APK.
#   5. La línea de origen de pdfium.txt (versión y sha256 de los .tgz) coincide con tools/pdfium.lock.
#
#   tools/check-licenses.sh [apk]     (tras `flutter build apk --release --split-per-abi`)
#
# Sin argumento, revisa el APK de cada ABI de tools/pdfium.lock en app/build/app/outputs/flutter-apk/.
# Necesita python3, unzip, dart y un JDK (JAVA_HOME o `java` en el PATH) para Gradle, que se
# ejecuta con --offline (las dependencias ya están en la caché tras compilar).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
LOCK="$ROOT/tools/pdfium.lock"
ASSETS="$APP/assets/licenses"
OUT="$APP/build/app/outputs/flutter-apk"

# El argumento (si lo hay) se resuelve antes de cambiar de directorio.
APK_ARG=""
if [ "${1:-}" != "" ]; then APK_ARG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

status=0
errors=0
fail() { echo "::error::$*"; status=1; errors=$((errors + 1)); }

# --- APK a revisar --------------------------------------------------------------------------
apks=()
if [ -n "$APK_ARG" ]; then
  [ -f "$APK_ARG" ] || { echo "::error::No existe $APK_ARG"; exit 1; }
  apks+=("$APK_ARG")
else
  while read -r abi _; do
    case "$abi" in ''|'#'*) continue ;; esac
    apk="$OUT/app-$abi-release.apk"
    if [ -f "$apk" ]; then
      apks+=("$apk")
    else
      fail "No existe $apk. Compila antes: flutter build apk --release --split-per-abi"
    fi
  done < "$LOCK"
fi
[ "${#apks[@]}" -gt 0 ] || { echo "::error::No hay ningún APK que revisar"; exit 1; }

# --- 1. Paquetes de Dart de release ⊆ NOTICES ------------------------------------------------
# NOTICES.Z (comprimido) es igual en todos los APK: se lee del primero. Cada bloque empieza por
# los nombres de sus paquetes, uno por línea, y termina en una línea de 80 guiones.
unzip -p "${apks[0]}" assets/flutter_assets/NOTICES.Z > "$WORK/NOTICES.Z" \
  || { echo "::error::${apks[0]} no tiene NOTICES.Z"; exit 1; }
python3 - "$WORK/NOTICES.Z" "$WORK/notices-names.txt" <<'PY'
import gzip, re, sys, zlib
raw = open(sys.argv[1], 'rb').read()
try:
    text = gzip.decompress(raw)
except OSError:
    text = zlib.decompress(raw, -15)
names = set()
for block in re.split(r'\n-{80}\n', text.decode('utf-8', 'replace')):
    for line in block.split('\n\n', 1)[0].split('\n'):
        if line.strip():
            names.add(line.strip())
open(sys.argv[2], 'w').write('\n'.join(sorted(names)) + '\n')
PY
[ -s "$WORK/notices-names.txt" ] || fail "NOTICES.Z no tiene ninguna entrada"

(cd "$APP" && dart pub deps --no-dev --style=list) > "$WORK/deps.txt"
# Solo las líneas de primer nivel ("- nombre versión"), sin las dependencias anidadas.
dart_pkgs="$(sed -n 's/^- \([a-z0-9_]*\) .*/\1/p' "$WORK/deps.txt" | sort -u)"
[ -n "$dart_pkgs" ] || fail "dart pub deps no ha dado ningún paquete (¿falta flutter pub get?)"
# Los paquetes del SDK de Flutter (flutter_localizations, sky_engine…: `source: sdk` en
# pubspec.lock) llevan la licencia del propio framework, que NOTICES trae como 'flutter'.
sdk_pkgs="$(python3 - "$APP/pubspec.lock" <<'PY'
import re, sys
name = None
for line in open(sys.argv[1]):
    m = re.match(r'^  ([a-z0-9_]+):\s*$', line)
    if m:
        name = m.group(1)
    elif name and re.match(r'^    source: sdk\s*$', line):
        print(name)
PY
)"
grep -Fxq flutter "$WORK/notices-names.txt" || fail "NOTICES no trae la licencia del framework ('flutter')"
dart_count=0
for pkg in $dart_pkgs; do
  grep -Fxq "$pkg" <<<"$sdk_pkgs" && continue
  dart_count=$((dart_count + 1))
  grep -Fxq "$pkg" "$WORK/notices-names.txt" \
    || fail "El paquete de Dart '$pkg' (release) no está en NOTICES de Flutter"
done
echo "Paquetes de Dart de release (sin los del SDK): $dart_count, todos en NOTICES."

# --- 2. Cada .so con su entrada ---------------------------------------------------------------
# libapp.so es el código de la app. Las demás bibliotecas: a qué entrada pertenecen.
so_entry() {
  case "$1" in
    libapp.so) echo skip ;;
    libflutter.so) echo "notices:skia" ;;    # el motor de Flutter (Skia, ICU, HarfBuzz…)
    libdartjni.so) echo "notices:jni" ;;     # paquete jni
    libpdfium.so) echo "asset:pdfium.txt" ;;
    libsqlite3.so) echo "asset:sqlite.txt" ;;
    *) echo unknown ;;
  esac
}

# --- 5. La línea de origen de pdfium.txt coincide con pdfium.lock ------------------------------
tag="$(sed -n 's/^# Release: chromium\/\([0-9][0-9]*\).*/\1/p' "$LOCK" | head -n1)"
if [ -z "$tag" ]; then
  fail "tools/pdfium.lock no dice la release (línea '# Release: chromium/NNNN')"
elif [ ! -f "$ASSETS/pdfium.txt" ]; then
  fail "Falta $ASSETS/pdfium.txt"
else
  origin="$(head -n1 "$ASSETS/pdfium.txt")"
  grep -Eq "chromium/$tag([^0-9]|\$)" <<<"$origin" \
    || fail "pdfium.txt: la línea de origen no dice chromium/$tag (la de tools/pdfium.lock). Regenera pdfium.txt"
  tgz=0
  while read -r sha; do
    tgz=$((tgz + 1))
    grep -Fq "$sha" <<<"$origin" \
      || fail "pdfium.txt: la línea de origen no trae el sha256 $sha de un .tgz de tools/pdfium.lock. Regenera pdfium.txt"
  done < <(sed -n 's/^#[[:space:]]*pdfium-android-[a-z0-9-]*\.tgz[[:space:]]*\([0-9a-f]\{64\}\).*/\1/p' "$LOCK")
  [ "$tgz" -gt 0 ] || fail "tools/pdfium.lock no trae los sha256 de los .tgz"
fi

# --- 3. Artefactos de Android ⊆ android.txt ---------------------------------------------------
# Sin io.flutter:* (motor y embedding: sus POM no traen licencia y ya van en NOTICES). Se
# ignoran las restricciones "(c)" (no entran en el classpath) y los proyectos (:plugin).
(cd "$APP/android" && ./gradlew --offline -q :app:dependencies --configuration releaseRuntimeClasspath) \
  > "$WORK/gradle.txt" 2> "$WORK/gradle.err" \
  || { cat "$WORK/gradle.err" >&2; fail "Gradle no ha podido listar releaseRuntimeClasspath (¿JAVA_HOME? ¿--offline sin caché?)"; }
grep -q FAILED "$WORK/gradle.txt" && fail "Gradle no ha resuelto alguna dependencia de releaseRuntimeClasspath"
sed -n 's/^[| ]*[+\\]--- \([A-Za-z0-9_.-]*:[A-Za-z0-9_.-]*\):.*/\1 &/p' "$WORK/gradle.txt" \
  | grep -v ' (c)$' | cut -d' ' -f1 | grep -v '^io\.flutter:' | sort -u > "$WORK/artifacts.txt" || true
[ -s "$WORK/artifacts.txt" ] || fail "No se han encontrado artefactos de Android en releaseRuntimeClasspath"
art_count=0
while read -r art; do
  art_count=$((art_count + 1))
  grep -Fxq "$art" "$ASSETS/android.txt" \
    || fail "El artefacto de Android '$art' no está en assets/licenses/android.txt (comprueba la licencia de su POM contra threat-model §5 y añádelo)"
done < "$WORK/artifacts.txt"
echo "Artefactos de Android: $art_count, todos en android.txt."

# --- Por APK: .so, fuentes y archivos de licencias ---------------------------------------------
for apk in "${apks[@]}"; do
  name="$(basename "$apk")"
  errors_before=$errors
  listing="$(unzip -Z1 "$apk")"

  so_count=0
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    so_count=$((so_count + 1))
    so="$(basename "$path")"
    entry="$(so_entry "$so")"
    case "$entry" in
      skip) ;;
      unknown) fail "$name: '$path' no tiene entrada de licencia conocida (añádela a so_entry de tools/check-licenses.sh y a la pantalla de licencias)" ;;
      notices:*) grep -Fxq "${entry#notices:}" "$WORK/notices-names.txt" \
                   || fail "$name: '$so' necesita la entrada '${entry#notices:}' en NOTICES y no está" ;;
      asset:*) f="${entry#asset:}"
               grep -Fxq "assets/flutter_assets/assets/licenses/$f" <<<"$listing" \
                 || fail "$name: '$so' necesita assets/licenses/$f dentro del APK y no está" ;;
    esac
  done < <(grep -E '^lib/[^/]+/[^/]+\.so$' <<<"$listing" || true)
  [ "$so_count" -gt 0 ] || fail "$name: no lleva ninguna biblioteca nativa (¿es un APK de release?)"

  # Fuentes: cada carpeta con .ttf/.otf de assets/fonts lleva su OFL.txt.
  font_dirs="$(grep -E '^assets/flutter_assets/assets/fonts/.*\.(ttf|otf)$' <<<"$listing" | sed 's:/[^/]*$::' | sort -u || true)"
  font_count=0
  for dir in $font_dirs; do
    font_count=$((font_count + 1))
    grep -Fxq "$dir/OFL.txt" <<<"$listing" || fail "$name: las fuentes de $dir no llevan su OFL.txt"
  done

  for f in pdfium.txt sqlite.txt android.txt; do
    grep -Fxq "assets/flutter_assets/assets/licenses/$f" <<<"$listing" \
      || fail "$name: falta assets/licenses/$f dentro del APK (¿declarado en pubspec.yaml?)"
  done
  [ "$errors" -eq "$errors_before" ] && echo "OK $name: $so_count bibliotecas nativas, $font_count carpetas de fuentes con su OFL."
done

[ "$status" -eq 0 ] && echo "Licencias completas (${#apks[@]} APK)."
exit "$status"
