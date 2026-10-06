#!/usr/bin/env bash
# Falla si algo que va dentro de un APK de release no tiene su aviso de licencia entre los textos
# que se redistribuyen (spec 012, CA-012-03; spec 015, CA-015-14a/14b y ADR-0026; threat-model §5).
# La app ya no muestra ninguna pantalla de licencias: los textos siguen dentro del paquete y el
# archivo de avisos que se publica en la web se emite de aquí. Comprueba, por cada APK:
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
# Si pasan, EMITE app/build/third-party-notices.txt (versión, fecha UTC, nombre y sha256 de cada APK,
# sha256 de NOTICES.Z y de cada texto; el NOTICES descomprimido, los tres .txt y cada OFL; y la lista
# de entradas) y lo VERIFICA sobre el archivo emitido, no sobre las variables de este script:
# vuelve a extraer los nombres del cuerpo, compara los textos con los del APK y exige cada paquete,
# .so, artefacto y fuente. Los NOTICES.Z de todos los ABI tienen que ser idénticos.
#
#   tools/check-licenses.sh [apk]                  (tras `flutter build apk --release --split-per-abi`)
#   tools/check-licenses.sh --notices-file <ruta>  verifica un archivo ya emitido, sin regenerarlo
#   tools/check-licenses.sh --negative             además, comprueba que el archivo emitido FALLA
#                                                  al quitarle una entrada o el cuerpo de un texto
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

# Argumentos: un APK, --notices-file <ruta> y --negative (ver arriba). Las rutas se resuelven
# antes de cambiar de directorio.
abspath() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
APK_ARG=""
NOTICES_ARG=""
NEGATIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --notices-file)
      [ $# -ge 2 ] || { echo "::error::--notices-file necesita una ruta"; exit 1; }
      [ -f "$2" ] || { echo "::error::No existe $2"; exit 1; }
      NOTICES_ARG="$(abspath "$2")"; shift 2 ;;
    --negative) NEGATIVE=1; shift ;;
    -*) echo "::error::Opción desconocida: $1"; exit 1 ;;
    *) APK_ARG="$(abspath "$1")"; shift ;;
  esac
done
NOTICES_OUT="$APP/build/third-party-notices.txt"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Emisor y verificador del archivo de avisos (el mismo extractor de nombres para NOTICES y para
# el cuerpo emitido).
cat > "$WORK/notices.py" <<'PY'
# Emite y verifica el archivo de avisos de terceros (tools/check-licenses.sh, spec 015 CA-015-14b).
#   notices.py names <NOTICES.Z> <salida>
#   notices.py emit|verify|negative <archivo> <versión> <carpeta de trabajo> <raíz> <apk>...
import gzip
import hashlib
import os
import re
import sys
import zipfile
import zlib
from datetime import datetime, timezone

PREFIX = 'assets/flutter_assets/'
TXT = ['assets/licenses/pdfium.txt', 'assets/licenses/sqlite.txt', 'assets/licenses/android.txt']
BEGIN = re.compile(rb'^===== BEGIN (.+) =====\n$')
END = re.compile(rb'^===== END (.+) =====\n$')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def inflate(raw):
    try:
        return gzip.decompress(raw)
    except OSError:
        return zlib.decompress(raw, -15)


def extract_names(text):
    """Nombres de los bloques de NOTICES: las líneas hasta la primera en blanco de cada bloque."""
    names = set()
    for block in re.split(r'\n-{80}\n', text.decode('utf-8', 'replace')):
        for line in block.split('\n\n', 1)[0].split('\n'):
            if line.strip():
                names.add(line.strip())
    return names


def embed(body):
    return body if body.endswith(b'\n') else body + b'\n'


def read_list(path):
    if not os.path.exists(path):
        return []
    return [l.strip() for l in open(path, encoding='utf-8') if l.strip()]


def sources(apks):
    """Lo que se redistribuye, leído de cada APK; los de todos los ABI tienen que coincidir."""
    errors = []
    data = None
    for apk in apks:
        with zipfile.ZipFile(apk) as z:
            names = set(z.namelist())
            keys = ['NOTICES.Z'] + TXT
            for n in names:
                m = re.match(re.escape(PREFIX) + r'(assets/fonts/.*)/[^/]*\.(ttf|otf)$', n)
                if m:
                    keys.append(m.group(1) + '/OFL.txt')
            keys = sorted(set(keys))
            found = {}
            for k in keys:
                if PREFIX + k in names:
                    found[k] = z.read(PREFIX + k)
                else:
                    errors.append("%s: falta '%s' dentro del APK" % (os.path.basename(apk), k))
        if data is None:
            data = found
        else:
            for k in sorted(set(data) | set(found)):
                if k in data and k in found and data[k] != found[k]:
                    errors.append("'%s' no es igual en %s y en el primer APK" % (k, os.path.basename(apk)))
                elif (k in data) != (k in found):
                    errors.append("'%s' no está en todos los APK (%s)" % (k, os.path.basename(apk)))
                    data.setdefault(k, found.get(k, b''))
    return data, errors


def parse(blob):
    """Lista ordenada de ('h', línea) y ('s', nombre, cuerpo); errores de formato."""
    items, errors = [], []
    cur = None
    body = []
    for line in blob.splitlines(keepends=True):
        if cur is None:
            m = BEGIN.match(line)
            if m:
                cur, body = m.group(1).decode('utf-8', 'replace'), []
            else:
                items.append(('h', line))
        else:
            m = END.match(line)
            if m and m.group(1).decode('utf-8', 'replace') == cur:
                items.append(('s', cur, b''.join(body)))
                cur = None
            else:
                body.append(line)
    if cur is not None:
        errors.append("la sección '%s' no se cierra" % cur)
    seen = set()
    for it in items:
        if it[0] == 's':
            if it[1] in seen:
                errors.append("la sección '%s' está repetida" % it[1])
            seen.add(it[1])
    return items, errors


def render(items):
    out = []
    for it in items:
        if it[0] == 'h':
            out.append(it[1])
        else:
            out.append(('===== BEGIN %s =====\n' % it[1]).encode())
            out.append(embed(it[2]))
            out.append(('===== END %s =====\n' % it[1]).encode())
    return b''.join(out)


def expected(workdir):
    exp = {}
    exp['dart'] = read_list(os.path.join(workdir, 'exp-dart.txt'))
    exp['so'] = [l.split(None, 1) for l in read_list(os.path.join(workdir, 'exp-so.txt'))]
    exp['artifacts'] = read_list(os.path.join(workdir, 'exp-artifacts.txt'))
    exp['fonts'] = [d[len(PREFIX):] if d.startswith(PREFIX) else d
                    for d in read_list(os.path.join(workdir, 'exp-fonts.txt'))]
    return exp


def entries_of(exp):
    entries = ['engine:flutter']
    entries += ['dart:' + p for p in exp['dart']]
    entries += ['native:' + so for so, _ in exp['so']]
    entries += ['android:' + a for a in exp['artifacts']]
    entries += ['font:' + d for d in exp['fonts']]
    entries += ['license:' + t for t in TXT]
    entries += ['license:' + d + '/OFL.txt' for d in exp['fonts']]
    return entries


def emit(out, version, workdir, root, apks):
    exp = expected(workdir)
    src, errors = sources(apks)
    if errors:
        return errors
    notices = inflate(src['NOTICES.Z'])
    lines = ['Third-party notices\n', 'Version: %s\n' % version,
             'Generated (UTC): %s\n' % datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')]
    for apk in apks:
        lines.append('APK: %s sha256 %s\n' % (os.path.basename(apk), sha(open(apk, 'rb').read())))
    for k in sorted(src):
        lines.append('%s sha256: %s\n' % (k, sha(src[k])))
    items = [('h', l.encode()) for l in lines]
    items.append(('s', 'ENTRIES', ('\n'.join(entries_of(exp)) + '\n').encode()))
    items.append(('s', 'NOTICES', notices))
    for k in sorted(src):
        if k != 'NOTICES.Z':
            items.append(('s', k, src[k]))
    with open(out, 'wb') as f:
        f.write(render(items))
    return []


def verify_bytes(blob, exp, src, root):
    errors = []
    items, perr = parse(blob)
    errors += perr
    secs = {it[1]: it[2] for it in items if it[0] == 's'}
    header = b''.join(it[1] for it in items if it[0] == 'h').decode('utf-8', 'replace')
    if not re.search(r'^Version: \S+$', header, re.M):
        errors.append("la cabecera no trae la versión")
    if not re.search(r'^Generated \(UTC\): \d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$', header, re.M):
        errors.append("la cabecera no trae la fecha UTC")
    if not re.search(r'^APK: \S+ sha256 [0-9a-f]{64}$', header, re.M):
        errors.append("la cabecera no trae el nombre y el sha256 de ningún APK")
    for k in sorted(src):
        if ('%s sha256: %s' % (k, sha(src[k]))) not in header.split('\n'):
            errors.append("la cabecera no trae el sha256 correcto de '%s'" % k)
    # Cuerpos: iguales a los del APK comprobado.
    notices = inflate(src['NOTICES.Z'])
    want = {'NOTICES': notices}
    for k in src:
        if k != 'NOTICES.Z':
            want[k] = src[k]
    for k in sorted(want):
        if k not in secs:
            errors.append("falta la sección '%s'" % k)
        elif secs[k] != embed(want[k]):
            errors.append("el cuerpo de '%s' no es el del APK (falta texto o está cambiado)" % k)
    # Lo que dice el cuerpo emitido (no las variables de quien lo emitió).
    names = extract_names(secs.get('NOTICES', b''))
    listed = set(secs.get('ENTRIES', b'').decode('utf-8', 'replace').split('\n'))
    for e in entries_of(exp):
        if e not in listed:
            errors.append("falta la entrada '%s' en la lista" % e)
    if 'flutter' not in names:
        errors.append("el cuerpo de NOTICES no trae la licencia del framework ('flutter')")
    for p in exp['dart']:
        if p not in names:
            errors.append("el paquete de Dart '%s' no está en el cuerpo de NOTICES" % p)
    for so, target in exp['so']:
        kind, _, what = target.partition(':')
        if kind == 'notices' and what not in names:
            errors.append("'%s' necesita la entrada '%s' en el cuerpo de NOTICES y no está" % (so, what))
        elif kind == 'asset' and ('assets/licenses/' + what) not in secs:
            errors.append("'%s' necesita la sección 'assets/licenses/%s' y no está" % (so, what))
    android = set(l.strip() for l in secs.get('assets/licenses/android.txt', b'').decode('utf-8', 'replace').split('\n'))
    for a in exp['artifacts']:
        if a not in android:
            errors.append("el artefacto de Android '%s' no está en el cuerpo de android.txt" % a)
    for d in exp['fonts']:
        if (d + '/OFL.txt') not in secs:
            errors.append("las fuentes de '%s' no llevan su OFL.txt (sección '%s/OFL.txt')" % (d, d))
    # Sin rutas locales.
    text = blob.decode('utf-8', 'replace')
    local = ['/Users/', root]
    home = os.environ.get('HOME', '')
    if len(home) > 3:
        local.append(home)
    for frag in local:
        if frag and frag in text:
            errors.append("el archivo trae una ruta local ('%s')" % frag)
    return errors


def drop_lines(body, pred):
    return b''.join(l for l in body.splitlines(keepends=True) if not pred(l.rstrip(b'\n').decode('utf-8', 'replace').strip()))


def negative(blob, exp, src, root):
    base = verify_bytes(blob, exp, src, root)
    if base:
        return ['el archivo original ya falla: ' + base[0]]
    items, _ = parse(blob)
    muts = []  # (descripción, función(items) -> items, texto que debe nombrar el error)

    def edit(items, name, fn):
        return [('s', it[1], fn(it[2])) if it[0] == 's' and it[1] == name else it for it in items]

    def without(items, name):
        return [it for it in items if not (it[0] == 's' and it[1] == name)]

    if exp['dart']:
        p = exp['dart'][0]
        muts.append(("quitar el paquete de Dart '%s'" % p,
                     lambda i: edit(edit(i, 'ENTRIES', lambda b: drop_lines(b, lambda l: l == 'dart:' + p)),
                                    'NOTICES', lambda b: drop_lines(b, lambda l: l == p)), p))
    for so, target in exp['so']:
        kind, _, what = target.partition(':')
        muts.append(("quitar de la lista la biblioteca '%s'" % so,
                     lambda i, so=so: edit(i, 'ENTRIES', lambda b: drop_lines(b, lambda l: l == 'native:' + so)), so))
        if kind == 'notices':
            muts.append(("quitar de NOTICES la entrada '%s' de '%s'" % (what, so),
                         lambda i, what=what: edit(i, 'NOTICES', lambda b: drop_lines(b, lambda l: l == what)), what))
    if exp['artifacts']:
        a = exp['artifacts'][0]
        muts.append(("quitar el artefacto de Android '%s'" % a,
                     lambda i: edit(edit(i, 'ENTRIES', lambda b: drop_lines(b, lambda l: l == 'android:' + a)),
                                    'assets/licenses/android.txt', lambda b: drop_lines(b, lambda l: l == a)), a))
    if exp['fonts']:
        d = exp['fonts'][0]
        muts.append(("quitar las fuentes de '%s' (entrada y OFL)" % d,
                     lambda i: without(edit(i, 'ENTRIES', lambda b: drop_lines(b, lambda l: l == 'font:' + d)),
                                       d + '/OFL.txt'), d))
    for k in TXT + [d + '/OFL.txt' for d in exp['fonts']]:
        muts.append(("cortar el cuerpo de '%s'" % k,
                     lambda i, k=k: edit(i, k, lambda b: b[:len(b) // 2]), k))
    errors = []
    for desc, fn, needle in muts:
        got = verify_bytes(render(fn(items)), exp, src, root)
        named = [e for e in got if needle in e]
        if named:
            print('OK (negativo) %s: falla y nombra la entrada (%d errores)' % (desc, len(got)))
        else:
            errors.append("la mutación '%s' NO falla nombrando '%s' (errores: %d)" % (desc, needle, len(got)))
    print('Mutaciones comprobadas: %d' % len(muts))
    return errors


def main(argv):
    mode = argv[1]
    if mode == 'names':
        raw = open(argv[2], 'rb').read()
        names = extract_names(inflate(raw))
        open(argv[3], 'w').write('\n'.join(sorted(names)) + '\n')
        return 0
    path, version, workdir, root = argv[2:6]
    apks = argv[6:]
    if mode == 'emit':
        errors = emit(path, version, workdir, root, apks)
    else:
        src, errors = sources(apks)
        if not errors:
            blob = open(path, 'rb').read()
            exp = expected(workdir)
            errors = verify_bytes(blob, exp, src, root) if mode == 'verify' else negative(blob, exp, src, root)
    for e in errors:
        print('::error::third-party-notices: ' + e)
    return 1 if errors else 0


sys.exit(main(sys.argv))
PY

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
python3 "$WORK/notices.py" names "$WORK/NOTICES.Z" "$WORK/notices-names.txt"
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
: > "$WORK/exp-dart.txt"
for pkg in $dart_pkgs; do
  grep -Fxq "$pkg" <<<"$sdk_pkgs" && continue
  dart_count=$((dart_count + 1))
  echo "$pkg" >> "$WORK/exp-dart.txt"
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
cp "$WORK/artifacts.txt" "$WORK/exp-artifacts.txt"
art_count=0
while read -r art; do
  art_count=$((art_count + 1))
  grep -Fxq "$art" "$ASSETS/android.txt" \
    || fail "El artefacto de Android '$art' no está en assets/licenses/android.txt (comprueba la licencia de su POM contra threat-model §5 y añádelo)"
done < "$WORK/artifacts.txt"
echo "Artefactos de Android: $art_count, todos en android.txt."

# --- Por APK: .so, fuentes y archivos de licencias ---------------------------------------------
: > "$WORK/exp-so.txt"
: > "$WORK/exp-fonts.txt"
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
    case "$entry" in skip|unknown) ;; *) echo "$so $entry" >> "$WORK/exp-so.txt" ;; esac
    case "$entry" in
      skip) ;;
      unknown) fail "$name: '$path' no tiene entrada de licencia conocida (añádela a so_entry de tools/check-licenses.sh y su aviso al archivo de avisos: NOTICES o assets/licenses)" ;;
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
    echo "$dir" >> "$WORK/exp-fonts.txt"
    grep -Fxq "$dir/OFL.txt" <<<"$listing" || fail "$name: las fuentes de $dir no llevan su OFL.txt"
  done

  for f in pdfium.txt sqlite.txt android.txt; do
    grep -Fxq "assets/flutter_assets/assets/licenses/$f" <<<"$listing" \
      || fail "$name: falta assets/licenses/$f dentro del APK (¿declarado en pubspec.yaml?)"
  done
  [ "$errors" -eq "$errors_before" ] && echo "OK $name: $so_count bibliotecas nativas, $font_count carpetas de fuentes con su OFL."
done

[ "$status" -eq 0 ] && echo "Licencias completas (${#apks[@]} APK)."

# --- Archivo de avisos de terceros: se emite del APK comprobado y se verifica ya emitido -------------
# (CA-015-14b, ADR-0026). Solo se emite si todo lo anterior ha pasado; con --notices-file (o
# --negative) se verifica el archivo que ya existe, sin regenerarlo.
for f in exp-so.txt exp-fonts.txt; do sort -u "$WORK/$f" -o "$WORK/$f"; done
version="$(sed -n 's/^version:[[:space:]]*//p' "$APP/pubspec.yaml" | head -n1)"
[ -n "$version" ] || fail "app/pubspec.yaml no dice la versión"
notices() { python3 "$WORK/notices.py" "$1" "$2" "${version:-?}" "$WORK" "$ROOT" "${apks[@]}"; }

if [ -n "$NOTICES_ARG" ]; then
  notices_file="$NOTICES_ARG"
elif [ "$NEGATIVE" -eq 1 ]; then
  notices_file="$NOTICES_OUT"
  [ -f "$notices_file" ] || fail "No existe $notices_file (ejecuta antes tools/check-licenses.sh sin --negative)"
else
  notices_file="$NOTICES_OUT"
  if [ "$status" -eq 0 ]; then
    mkdir -p "$(dirname "$notices_file")"
    notices emit "$notices_file" || status=1
  else
    echo "::error::No se emite el archivo de avisos: hay comprobaciones que fallan"
  fi
fi
if [ -f "$notices_file" ]; then
  if notices verify "$notices_file"; then
    echo "Archivo de avisos verificado sobre el archivo emitido ($(wc -c < "$notices_file" | tr -d ' ') bytes): $notices_file"
  else
    status=1
  fi
  if [ "$NEGATIVE" -eq 1 ] && [ "$status" -eq 0 ]; then
    notices negative "$notices_file" || status=1
  fi
fi
exit "$status"
