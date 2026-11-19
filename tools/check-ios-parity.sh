#!/usr/bin/env bash
# Paridad de iOS con Android (spec 028, CA-028-04 a 08, 17 y 20): comprueba el proyecto de iOS contra
# lo que dice la spec sin compilar nada. Lee archivos del repositorio, sin red; bash + `python3` de la
# biblioteca estándar (los plist con `plistlib`, nada de `plutil`), así que corre igual en macOS y en
# Ubuntu (trabajo `flutter` de la CI, donde la prueba del propio script).
#
#   tools/check-ios-parity.sh [--root DIR] [--section NOMBRE]...
#
#   --root DIR       árbol que se comprueba (por defecto, este repositorio; los tests le pasan uno
#                    de mentira). De él se leen `app/ios/`, `app/android/…/*.kt`, `design/tokens.json`
#                    y `tools/ios-parity.sections`. Las sumas de los iconos de la plantilla
#                    (`tools/fixtures/ios-template-icons.sha256`) son del script, no del árbol.
#   --section NOMBRE corre esa sección aunque no esté activa (repetible). Sin ninguna, corre las
#                    activas de `tools/ios-parity.sections` y lista las demás como PENDIENTE.
#
# Secciones: project, plist, l10n, launch, icon, privacy, network y channel:una/<canal>
# (images, webview, notifications, screen, links, a11y). Cada tarea que hace verde una sección la
# añade a `tools/ios-parity.sections`; con la T-028-21 están todas.
#
# Falla cerrado: un archivo que falta, vacío o ilegible es un fallo que lo nombra, nunca un verde.
# Salida 0 = todo lo que corrió pasa; 1 = algún fallo (mensajes `::error::` en español); 2 = uso.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
requested=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      [ $# -ge 2 ] || { echo "::error::--root necesita un valor" >&2; exit 2; }
      [ -d "$2" ] || { echo "::error::--root: no existe la carpeta $2" >&2; exit 2; }
      ROOT="$(cd "$2" && pwd)"
      shift 2
      ;;
    --section)
      [ $# -ge 2 ] || { echo "::error::--section necesita un valor" >&2; exit 2; }
      requested="${requested}${2}"$'\n'
      shift 2
      ;;
    *)
      echo "::error::argumento desconocido: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "::error::Falta python3 (biblioteca estándar, sin paquetes)" >&2
  exit 1
fi

IOS_PARITY_ROOT="$ROOT" IOS_PARITY_TOOLS="$SCRIPT_DIR" IOS_PARITY_SECTIONS="$requested" \
  exec python3 -I - <<'PY'
import glob
import hashlib
import json
import os
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = os.environ["IOS_PARITY_ROOT"]
TOOLS = os.environ["IOS_PARITY_TOOLS"]
REQUESTED = [s.strip() for s in os.environ.get("IOS_PARITY_SECTIONS", "").split("\n") if s.strip()]

IOS = "app/ios"
RUNNER = IOS + "/Runner"
KOTLIN = "app/android/app/src/main/kotlin"

# Canal -> (Kotlin de referencia, relativo a la carpeta del paquete; Swift espejo en Runner/).
CHANNELS = {
    "una/images": ("ImageImport.kt", "Images.swift"),
    "una/webview": ("WebViewHardening.kt", "WebViewHardening.swift"),
    "una/notifications": ("notifications/NotificationsChannel.kt", "Notifications.swift"),
    "una/screen": ("MainActivity.kt", "Screen.swift"),
    "una/links": ("LinkOpener.kt", "Links.swift"),
    "una/a11y": ("AccessibilityTimeouts.kt", "A11y.swift"),
}

# API de «motivo obligatorio» de Apple -> categoría del manifiesto (CA-028-17). Si un .swift usa una,
# su categoría tiene que estar declarada (con su razón) en PrivacyInfo.xcprivacy.
API_TABLE = [
    ("DiskSpace", r"\b(?:volumeAvailableCapacity\w*|volumeTotalCapacity\w*|systemFreeSize|systemSize"
                  r"|NSFileSystemFreeSize|NSFileSystemSize|statfs|fstatfs|statvfs|fstatvfs)\b"),
    ("FileTimestamp", r"\b(?:creationDate|modificationDate|contentModificationDate|fileCreationDate"
                      r"|fileModificationDate|creationDateKey|contentModificationDateKey"
                      r"|attributeModificationDate|NSFileCreationDate|NSFileModificationDate)\b"),
    ("SystemBootTime", r"\b(?:systemUptime|mach_absolute_time|mach_continuous_time"
                       r"|clock_gettime_nsec_np)\b"),
    ("UserDefaults", r"\b(?:UserDefaults|NSUserDefaults)\b"),
]

# Lo que no puede aparecer en el Swift propio (CA-028-17, contrato §0.1): red y registros.
FORBIDDEN = [
    ("URLSession", r"\bURLSession\w*"),
    ("NSURLConnection", r"\bNSURLConnection\b"),
    ("NWConnection", r"\bNWConnection\b"),
    ("CFNetwork", r"\bCFNetwork\b"),
    ("print", r"\bprint\s*\("),
    ("debugPrint", r"\bdebugPrint\s*\("),
    ("NSLog", r"\bNSLog\b"),
    ("os_log", r"\bos_log\b"),
    ("Logger", r"\bLogger\b"),
]

STRING = r'"(?:\\.|[^"\\\n])*"'
_TOKEN = re.compile(r'"""(?:.|\n)*?"""|' + STRING + r'|//[^\n]*|/\*(?:.|\n)*?\*/')


class Problems(list):
    """Lista de mensajes de fallo de una sección."""

    def add(self, msg):
        self.append(msg)


def strip_comments(src):
    """Quita comentarios de Swift/Kotlin conservando los saltos de línea y las cadenas."""
    def rep(m):
        s = m.group(0)
        if s.startswith("//"):
            return ""
        if s.startswith("/*"):
            return re.sub(r"[^\n]", "", s)
        return s
    return _TOKEN.sub(rep, src)


def path(rel):
    return os.path.join(ROOT, *rel.split("/"))


def read_bytes(rel, problems):
    p = path(rel)
    try:
        with open(p, "rb") as f:
            data = f.read()
    except OSError:
        problems.add("%s: no existe o no se puede leer" % rel)
        return None
    if not data.strip():
        problems.add("%s: está vacío" % rel)
        return None
    return data


def read_text(rel, problems):
    data = read_bytes(rel, problems)
    if data is None:
        return None
    for enc in ("utf-8-sig", "utf-16"):
        if enc == "utf-16" and not data.startswith((b"\xff\xfe", b"\xfe\xff")):
            continue
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    problems.add("%s: no es texto UTF-8" % rel)
    return None


def read_plist(rel, problems):
    data = read_bytes(rel, problems)
    if data is None:
        return None
    try:
        value = plistlib.loads(data)
    except Exception:
        problems.add("%s: no es un plist válido" % rel)
        return None
    if not isinstance(value, dict):
        problems.add("%s: la raíz del plist no es un diccionario" % rel)
        return None
    return value


def swift_files(problems):
    """Los .swift propios de la app (recursivo en Runner/; RunnerTests queda fuera)."""
    base = path(RUNNER)
    found = sorted(glob.glob(os.path.join(base, "**", "*.swift"), recursive=True))
    if not found:
        problems.add("%s: no hay ningún .swift" % RUNNER)
    return found


def code_of(file_path, problems):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return strip_comments(f.read())
    except (OSError, UnicodeDecodeError):
        problems.add("%s: no se puede leer" % os.path.relpath(file_path, ROOT))
        return None


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def hex_rgb(value):
    m = re.fullmatch(r"#([0-9A-Fa-f]{6})", value or "")
    if not m:
        return None
    h = m.group(1)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ──────────────────────────── secciones ────────────────────────────

def section_project(p):
    text = read_text(IOS + "/Runner.xcodeproj/project.pbxproj", p)
    if text is None:
        return
    configs = re.findall(r"isa = XCBuildConfiguration;(.*?)^\s*name = (\w+);", text, re.S | re.M)
    if not configs:
        p.add("project.pbxproj: no tiene configuraciones de compilación")
        return
    have = {"IPHONEOS_DEPLOYMENT_TARGET": set(), "TARGETED_DEVICE_FAMILY": set()}
    for body, name in configs:
        for m in re.finditer(r"IPHONEOS_DEPLOYMENT_TARGET = ([^;]+);", body):
            value = m.group(1).strip().strip('"')
            have["IPHONEOS_DEPLOYMENT_TARGET"].add(name)
            if value not in ("16.0", "16"):
                p.add("configuración %s: IPHONEOS_DEPLOYMENT_TARGET = %s (debe ser 16.0, CA-028-04)" % (name, value))
        for m in re.finditer(r"TARGETED_DEVICE_FAMILY = ([^;]+);", body):
            value = m.group(1).strip().strip('"')
            have["TARGETED_DEVICE_FAMILY"].add(name)
            if value != "1":
                p.add('configuración %s: TARGETED_DEVICE_FAMILY = "%s" (solo iPhone: debe ser 1, CA-028-04)' % (name, value))
    for key, names in have.items():
        for needed in ("Debug", "Release", "Profile"):
            if needed not in names:
                p.add("la configuración %s no fija %s" % (needed, key))


def section_plist(p):
    info = read_plist(RUNNER + "/Info.plist", p)
    if info is None:
        return
    if info.get("UIUserInterfaceStyle") != "Light":
        p.add("Info.plist: UIUserInterfaceStyle = %r (debe ser Light, CA-028-05)" % (info.get("UIUserInterfaceStyle"),))
    usage = sorted(k for k in info if re.fullmatch(r"NS\w*UsageDescription", k))
    if usage != ["NSCameraUsageDescription"]:
        p.add("Info.plist: las descripciones de uso son %s (solo debe haber NSCameraUsageDescription, CA-028-10)" % (usage,))
    langs = info.get("CFBundleLocalizations")
    if not isinstance(langs, list) or sorted(langs) != ["ca", "en", "es"]:
        p.add("Info.plist: CFBundleLocalizations = %r (debe ser en, es y ca, CA-028-08)" % (langs,))
    orient = info.get("UISupportedInterfaceOrientations")
    needed = ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
              "UIInterfaceOrientationLandscapeRight"]
    if not isinstance(orient, list):
        p.add("Info.plist: falta UISupportedInterfaceOrientations (CA-028-13)")
    else:
        for o in needed:
            if o not in orient:
                p.add("Info.plist: UISupportedInterfaceOrientations no incluye %s (CA-028-13)" % o)


def parse_strings(rel, p):
    """Lee un .strings (`"clave" = "valor";`) como diccionario; None si falta o está mal formado."""
    text = read_text(rel, p)
    if text is None:
        return None
    text = strip_comments(text)
    pair = re.compile(r"(%s|[A-Za-z0-9_.]+)\s*=\s*(%s)\s*;" % (STRING, STRING))
    out = {}
    rest = []
    last = 0
    for m in pair.finditer(text):
        rest.append(text[last:m.start()])
        last = m.end()
        key = m.group(1).strip('"')
        if key in out:
            p.add("%s: la clave %s está repetida" % (rel, key))
        out[key] = m.group(2)
    rest.append(text[last:])
    if "".join(rest).strip():
        p.add("%s: tiene líneas que no son «clave» = «valor»;" % rel)
    if not out:
        p.add("%s: no tiene ninguna clave" % rel)
    return out


def section_l10n(p):
    tables = {}
    for lang in ("en", "es", "ca"):
        tables[lang] = parse_strings("%s/%s.lproj/InfoPlist.strings" % (RUNNER, lang), p)
    present = {k: v for k, v in tables.items() if v is not None}
    if len(present) < 3:
        return
    ref = set(present["en"])
    for lang in ("es", "ca"):
        keys = set(present[lang])
        for k in sorted(ref - keys):
            p.add("%s.lproj/InfoPlist.strings: falta la clave %s (está en en)" % (lang, k))
        for k in sorted(keys - ref):
            p.add("%s.lproj/InfoPlist.strings: sobra la clave %s (no está en en)" % (lang, k))
    if present["ca"] != present["es"]:
        p.add("ca.lproj/InfoPlist.strings no es igual que es.lproj (ca = es, CA-028-08)")


def components_to_rgb(comp):
    """Componentes de un color de `Contents.json` (flotantes 0-1, `0xNN` o enteros 0-255) -> 0-255."""
    out = []
    for k in ("red", "green", "blue"):
        v = str(comp.get(k, "")).strip()
        try:
            if v.lower().startswith("0x"):
                out.append(int(v, 16))
            elif "." in v:
                out.append(int(round(float(v) * 255)))
            else:
                out.append(int(v))
        except ValueError:
            return None
    try:
        alpha = float(comp.get("alpha", 1))
    except ValueError:
        alpha = None
    return tuple(out), alpha


def section_launch(p):
    tokens_raw = read_text("design/tokens.json", p)
    colorset_rel = RUNNER + "/Assets.xcassets/LaunchBackground.colorset/Contents.json"
    colorset_raw = read_text(colorset_rel, p)
    story_rel = RUNNER + "/Base.lproj/LaunchScreen.storyboard"
    story_raw = read_bytes(story_rel, p)
    paper = None
    if tokens_raw is not None:
        try:
            paper = hex_rgb(json.loads(tokens_raw)["color"]["paper"]["$value"])
        except (ValueError, KeyError, TypeError):
            paper = None
        if paper is None:
            p.add("design/tokens.json: no se lee color.paper")
    if colorset_raw is not None:
        try:
            entries = json.loads(colorset_raw).get("colors")
        except ValueError:
            entries = None
        if not isinstance(entries, list) or not entries:
            p.add("%s: no tiene colores" % colorset_rel)
        else:
            for e in entries:
                if "appearances" in e:
                    p.add("%s: tiene una variante (appearances): el arranque es siempre paper, sin oscuro (CA-028-06)" % colorset_rel)
            first = entries[0].get("color", {}) if isinstance(entries[0], dict) else {}
            parsed = components_to_rgb(first.get("components", {})) if isinstance(first, dict) else None
            if not parsed or None in parsed:
                p.add("%s: no se leen los componentes del color" % colorset_rel)
            elif paper is not None:
                rgb, alpha = parsed
                if rgb != paper:
                    p.add("%s: el color es %s y paper es %s (CA-028-06)" % (colorset_rel, rgb, paper))
                if alpha != 1:
                    p.add("%s: el color no es opaco (alpha %s)" % (colorset_rel, alpha))
    if story_raw is not None:
        try:
            tree = ET.fromstring(story_raw)
        except ET.ParseError:
            p.add("%s: no es XML válido" % story_rel)
            return
        tags = {el.tag for el in tree.iter()}
        if "imageView" in tags or "image" in tags:
            p.add("%s: lleva una imagen (el arranque es un fondo liso, sin icono, CA-028-06)" % story_rel)
        refs = any(el.tag == "color" and el.get("key") == "backgroundColor" and el.get("name") == "LaunchBackground"
                   for el in tree.iter())
        if not refs:
            p.add("%s: el fondo de la vista no es el color LaunchBackground" % story_rel)


def template_sums(p):
    fixture = os.path.join(TOOLS, "fixtures", "ios-template-icons.sha256")
    try:
        with open(fixture, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError:
        p.add("tools/fixtures/ios-template-icons.sha256: no existe o no se puede leer")
        return None
    sums = set(re.findall(r"^([0-9a-f]{64})\b", text, re.M))
    if not sums:
        p.add("tools/fixtures/ios-template-icons.sha256: no tiene ninguna suma")
        return None
    return sums


def png_info(data):
    """(ancho, alto, tipo de color, tiene tRNS) de un PNG, o None si no lo es."""
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR" or len(data) < 33:
        return None
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    trns = False
    pos = 8
    while pos + 8 <= len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        if kind == b"tRNS":
            trns = True
        if kind in (b"IDAT", b"IEND"):
            break
        pos += 12 + length
    return width, height, color_type, trns


def section_icon(p):
    sums = template_sums(p)
    folder = path(RUNNER + "/Assets.xcassets/AppIcon.appiconset")
    pngs = sorted(glob.glob(os.path.join(folder, "*.png")))
    if not pngs:
        p.add("%s/Assets.xcassets/AppIcon.appiconset: no hay ningún PNG" % RUNNER)
        return
    big = False
    for f in pngs:
        name = os.path.basename(f)
        try:
            with open(f, "rb") as fh:
                data = fh.read()
        except OSError:
            p.add("AppIcon.appiconset/%s: no se puede leer" % name)
            continue
        if sums is not None and hashlib.sha256(data).hexdigest() in sums:
            p.add("AppIcon.appiconset/%s es el icono de la plantilla de Flutter (CA-028-07)" % name)
        info = png_info(data)
        if info is None:
            p.add("AppIcon.appiconset/%s: no es un PNG válido" % name)
            continue
        w, h, color_type, trns = info
        if color_type in (4, 6) or trns:
            p.add("AppIcon.appiconset/%s tiene canal alfa o transparencia (iOS la rechaza, CA-028-07)" % name)
        if (w, h) == (1024, 1024):
            big = True
    if not big:
        p.add("AppIcon.appiconset: falta el icono de 1024 x 1024")


def section_privacy(p):
    manifest = read_plist(RUNNER + "/PrivacyInfo.xcprivacy", p)
    declared = {}
    if manifest is not None:
        if manifest.get("NSPrivacyTracking") is not False:
            p.add("PrivacyInfo.xcprivacy: NSPrivacyTracking debe ser false (CA-028-17)")
        if manifest.get("NSPrivacyTrackingDomains"):
            p.add("PrivacyInfo.xcprivacy: NSPrivacyTrackingDomains debe estar vacío (CA-028-17)")
        if manifest.get("NSPrivacyCollectedDataTypes"):
            p.add("PrivacyInfo.xcprivacy: NSPrivacyCollectedDataTypes debe estar vacío: la app no recoge datos (CA-028-17)")
        apis = manifest.get("NSPrivacyAccessedAPITypes", [])
        if not isinstance(apis, list):
            p.add("PrivacyInfo.xcprivacy: NSPrivacyAccessedAPITypes no es una lista")
            apis = []
        for entry in apis:
            kind = entry.get("NSPrivacyAccessedAPIType") if isinstance(entry, dict) else None
            reasons = entry.get("NSPrivacyAccessedAPITypeReasons") if isinstance(entry, dict) else None
            if not isinstance(kind, str):
                p.add("PrivacyInfo.xcprivacy: una API declarada sin categoría")
                continue
            if not isinstance(reasons, list) or not reasons or not all(isinstance(r, str) and r for r in reasons):
                p.add("PrivacyInfo.xcprivacy: %s sin razón declarada" % kind)
            declared[kind] = True
    for f in swift_files(p):
        code = code_of(f, p)
        if code is None:
            continue
        rel = os.path.relpath(f, ROOT)
        for category, pattern in API_TABLE:
            m = re.search(pattern, code)
            if m and ("NSPrivacyAccessedAPICategory" + category) not in declared:
                p.add("%s:%d usa %s (API de motivo obligatorio) y el manifiesto no declara NSPrivacyAccessedAPICategory%s"
                      % (rel, line_of(code, m.start()), m.group(0), category))


def section_network(p):
    for f in swift_files(p):
        code = code_of(f, p)
        if code is None:
            continue
        rel = os.path.relpath(f, ROOT)
        for name, pattern in FORBIDDEN:
            m = re.search(pattern, code)
            if m:
                p.add("%s:%d usa %s: sin red propia ni registros en el Swift (CA-028-17)" % (rel, line_of(code, m.start()), name))


def kotlin_methods(code):
    """Métodos del `when (call.method)` del canal: las etiquetas a profundidad 0 de su cuerpo."""
    m = re.search(r"when\s*\(\s*call\.method\s*\)\s*\{", code)
    if not m:
        return None
    methods = []
    depth = 0
    label = re.compile(r"^\s*(%s(?:\s*,\s*%s)*)\s*->" % (STRING, STRING))
    brace = re.compile(STRING + r"|[{}]")
    for line in code[m.end():].split("\n"):
        if depth == 0:
            lm = label.match(line)
            if lm:
                methods.extend(s[1:-1] for s in re.findall(STRING, lm.group(1)))
        for t in brace.findall(line):
            if t == "{":
                depth += 1
            elif t == "}":
                depth -= 1
        if depth < 0:
            break
    return methods


def swift_cases(code):
    names = set()
    for m in re.finditer(r"\bcase\s+(%s(?:\s*,\s*%s)*)\s*:" % (STRING, STRING), code):
        names.update(s[1:-1] for s in re.findall(STRING, m.group(1)))
    return names


def section_channel(channel):
    kt_rel, swift_name = CHANNELS[channel]

    def run(p):
        base = path(KOTLIN)
        hits = glob.glob(os.path.join(base, "**", *kt_rel.split("/")), recursive=True)
        if len(hits) != 1:
            p.add("%s/**/%s: se esperaba exactamente un archivo y hay %d" % (KOTLIN, kt_rel, len(hits)))
            return
        try:
            with open(hits[0], "r", encoding="utf-8") as f:
                kt = strip_comments(f.read())
        except (OSError, UnicodeDecodeError):
            p.add("%s: no se puede leer" % os.path.relpath(hits[0], ROOT))
            return
        methods = kotlin_methods(kt)
        if not methods:
            p.add("%s: no se encuentran los métodos del `when (call.method)`" % os.path.relpath(hits[0], ROOT))
            return
        swift_rel = "%s/%s" % (RUNNER, swift_name)
        swift = read_text(swift_rel, p)
        if swift is None:
            return
        cases = swift_cases(strip_comments(swift))
        for method in methods:
            if method not in cases:
                p.add("%s: falta `case \"%s\"` (está en %s, CA-028-20)" % (swift_rel, method, os.path.basename(hits[0])))
    return run


SECTIONS = {
    "project": section_project,
    "plist": section_plist,
    "l10n": section_l10n,
    "launch": section_launch,
    "icon": section_icon,
    "privacy": section_privacy,
    "network": section_network,
}
for _channel in CHANNELS:
    SECTIONS["channel:" + _channel] = section_channel(_channel)


def active_sections():
    problems = Problems()
    text = read_text("tools/ios-parity.sections", problems)
    if text is None:
        return None, problems
    names = []
    for raw in text.split("\n"):
        name = raw.split("#", 1)[0].strip()
        if not name:
            continue
        if name not in SECTIONS:
            problems.add("tools/ios-parity.sections: sección desconocida «%s»" % name)
        else:
            names.append(name)
    return names, problems


def main():
    for name in REQUESTED:
        if name not in SECTIONS:
            print("::error::sección desconocida: %s (hay: %s)" % (name, ", ".join(SECTIONS)), file=sys.stderr)
            return 2
    status = 0
    if REQUESTED:
        to_run, pending = list(dict.fromkeys(REQUESTED)), []
    else:
        to_run, problems = active_sections()
        if to_run is None or problems:
            for msg in problems:
                print("::error::%s" % msg, file=sys.stderr)
            return 1
        pending = [s for s in SECTIONS if s not in to_run]
    for name in to_run:
        problems = Problems()
        SECTIONS[name](problems)
        if problems:
            status = 1
            print("FALLO      %s" % name)
            for msg in problems:
                print("::error::%s: %s" % (name, msg), file=sys.stderr)
        else:
            print("OK         %s" % name)
    for name in pending:
        print("PENDIENTE  %s" % name)
    return status


sys.exit(main())
PY
