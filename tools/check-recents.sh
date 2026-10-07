#!/usr/bin/env bash
# Verificación de la spec 011 (ocultar el contenido en "Recientes") con adb.
#
#   tools/check-recents.sh <serial-adb> capture <etiqueta> [directorio]
#   tools/check-recents.sh <serial-adb> compare <etiquetaA> <etiquetaB> <directorio>
#   tools/check-recents.sh <serial-adb> secure
#   tools/check-recents.sh <serial-adb> loop <vueltas> [directorio]
#   tools/check-recents.sh <serial-adb> record <vueltas> [directorio]
#   tools/check-recents.sh <serial-adb> fixtures push|clean
#
# El serial es OBLIGATORIO (no hay valor por defecto: con dos dispositivos
# conectados adb falla y nunca se debe tocar el móvil del propietario).
# Dispositivo físico (serial que no empieza por "emulator-"), solo con permiso
# explícito del propietario:
#   - secure (solo lee dumpsys, no captura nada): ALLOW_PHYSICAL=1.
#   - capture, compare, loop y record: ALLOW_PHYSICAL=1 Y ALLOW_PHYSICAL_SCREENSHOTS=1.
#     Capturan "Recientes" ENTERA, con las tarjetas de las demás apps del propietario
#     a la vista (mensajería, banco...), y le roban el foco.
# Directorio de salida: si no se pasa, se crea uno con mktemp -d (permisos 700) y se
# imprime al terminar; compare lo necesita explícito (el que imprimió capture).
#
# Flujo (CA-011-01, 04 y 08). Con la app en primer plano en la pantalla a probar:
#   1. capture uno      con la tarea A ("uno"): guarda <etiqueta>-front.png y
#                       <etiqueta>-recents.png y vuelve a la app.
#   2. (cambiar a la tarea B, "dos") capture dos
#   3. compare uno dos  falla si la tarjeta de "Recientes" enseña el contenido
#                       de la pantalla, o si las tarjetas de A y B difieren.
#   loop N:  N veces, segundo plano -> "Recientes" -> volver -> captura. Falla si
#            alguna tarjeta enseña contenido o alguna captura sale sin él (CA-011-08).
#   record N: N vueltas grabadas con screenrecord (fotogramas en bruto); falla si
#            hay un fotograma liso que no sea blanco (p. ej. negro) o si, una vez
#            visible la pantalla de la app, vuelve a desaparecer (parpadeo,
#            CA-011-03). El fotograma liso BLANCO al volver desde "Recientes" es
#            la excepción aceptada (CA-011-03 enmendado): se cuenta, no falla.
#   fixtures push|clean: escenario "grupo de 3 fotos distinguibles" (CA-016-13).
#            push deja en la galería del dispositivo tres fotos de prueba (roja, verde
#            y azul, con un número enorme: la 1, la 2 y la 3) en Pictures/una-recents; clean las
#            borra. Con ellas se crea una tarea con "Subir imágenes" (las tres, en ese
#            orden) y se repite el flujo de siempre con la tarea a la vista: capture
#            carrusel1 (foto 1), cambiar a la foto 3 (swipe), capture carrusel3, y
#            compare carrusel1 carrusel3 (la tarjeta no enseña ninguna foto y las dos
#            son idénticas); loop y record con el carrusel a la vista. Mismas
#            comprobaciones con el móvil en horizontal, con una foto que falta ("Foto no
#            disponible"), con "Preparando foto 2 de 3…" y con el editor y la preselección.
#            Solo emulador o dispositivo de pruebas: son archivos de prueba, sin datos reales.
#   VIA=direct abre "Recientes" desde la propia app (por defecto pasa por el
#            escritorio). Esa ruta queda FUERA de CA-011-01 (CL-011-14): el
#            lanzador enseña la ventana en vivo; el script solo informa.
#   secure:  falla si la ventana de la app lleva FLAG_SECURE ahora (CA-011-04) y también
#            si no encuentra la ventana de la app en dumpsys (imprime "unknown").
#   Tarjeta de "Recientes": capture, compare, loop y record comprueban que se ve (clara)
#            y que su interior es LISO (desviación típica <= FLAT_MAX_STD, 2 por defecto,
#            sin la franja de arriba ni los bordes): cualquier contenido residual falla
#            aunque sea igual con la tarea A y con la B.
#   RECENTS_WAIT=<segundos>  espera tras abrir "Recientes" (por defecto 2,5). Con una
#            imagen o un PDF el lanzador tarda más en pintar la tarjeta: si la captura sale
#            sin tarjeta (solo el fondo), sube la espera (4 s bastan en el emulador).
#
# Requisitos: adb (variable ADB, PATH o el SDK de Android en ~/Library/Android),
# python3 con Pillow y numpy. El paquete se cambia con PKG (por defecto
# invalid.pending.app; la compilación debug es invalid.pending.app.debug).
# Las capturas son de la app con datos de prueba (tareas "uno" y "dos"): no las
# guardes con datos reales.
#
# Códigos de salida: 0 todo bien; 1 un criterio falla; 2 uso incorrecto.
set -euo pipefail

usage() { sed -n "2,65p" "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SERIAL="${1:-}"
[ -n "$SERIAL" ] || { echo "Falta el serial de adb (primer argumento). Sin serial no se ejecuta nada." >&2; usage; }
CMD="${2:-}"
[ -n "$CMD" ] || usage
shift 2
case "$SERIAL" in
  emulator-*) ;;
  *)
    [ "${ALLOW_PHYSICAL:-}" = "1" ] || {
      echo "'$SERIAL' no es un emulador. Un dispositivo físico solo se usa con permiso explícito del propietario (ALLOW_PHYSICAL=1)." >&2
      exit 2
    }
    if [ "$CMD" != "secure" ]; then
      [ "${ALLOW_PHYSICAL_SCREENSHOTS:-}" = "1" ] || {
        echo "'$SERIAL' es un dispositivo físico: '$CMD' captura \"Recientes\" ENTERA, con las tarjetas de las demás apps del propietario a la vista, y le roba el foco." >&2
        echo "Solo 'secure' se permite con ALLOW_PHYSICAL=1. Para '$CMD' hace falta además ALLOW_PHYSICAL_SCREENSHOTS=1, y solo con permiso explícito del propietario y sin guardar lo capturado (dispositivo.md §5.1)." >&2
        exit 2
      }
    fi ;;
esac

PKG="${PKG:-invalid.pending.app}"
ACTIVITY="$PKG/invalid.pending.app.MainActivity"

ADB_BIN="${ADB:-$(command -v adb || true)}"
[ -n "$ADB_BIN" ] || ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
[ -x "$ADB_BIN" ] || { echo "No encuentro adb (variable ADB)" >&2; exit 2; }
adb() { "$ADB_BIN" -s "$SERIAL" "$@"; }

if [ "$CMD" != "compare" ]; then
  [ "$(adb get-state 2>/dev/null || true)" = "device" ] || { echo "El dispositivo $SERIAL no está disponible" >&2; exit 2; }
fi

# ¿Lleva la ventana de la app FLAG_SECURE? Imprime "secure", "not-secure" o "unknown"
# (no se encontró la ventana de la app en dumpsys: no se puede afirmar nada).
secure_state() {
  adb shell dumpsys window windows | awk -v w="Window{.* $PKG/" '
    $0 ~ "Window #" && $0 ~ w { inwin = 1; seen = 1; next }
    inwin && $0 ~ "Window #" { inwin = 0 }
    inwin && $1 ~ /^fl=/ { if ($0 ~ /(^|[ =])SECURE( |$)/) found = 1 }
    END { print !seen ? "unknown" : found ? "secure" : "not-secure" }'
}

# Directorio de salida: el pedido o, por defecto, uno temporal privado (mktemp -d).
# Se imprime al terminar para poder localizar las capturas (y borrarlas).
OUT=""
setup_out() {
  if [ -n "${1:-}" ]; then OUT="$1"; mkdir -p "$OUT"
  else local base="${TMPDIR:-/tmp}"; OUT="$(mktemp -d "${base%/}/check-recents.XXXXXX")"; fi
  trap 'echo "Capturas en: $OUT"' EXIT
}

shot() { adb exec-out screencap -p > "$1"; }
back_to_app() { adb shell am start -n "$ACTIVITY" >/dev/null 2>&1; sleep 2; }
# Abre "Recientes". Por defecto pasa antes por el escritorio (la app queda en
# segundo plano y parada: la tarjeta es la instantánea del sistema). Con
# VIA=direct lo abre desde la propia app: en Android 14+ el lanzador puede enseñar
# ahí la ventana en vivo de la app en lugar de la instantánea.
open_recents() {
  if [ "${VIA:-home}" = "home" ]; then adb shell input keyevent KEYCODE_HOME; sleep 2; fi
  adb shell input keyevent KEYCODE_APP_SWITCH; sleep "${RECENTS_WAIT:-2.5}"
}

# Con VIA=direct la tarjeta con contenido es lo esperado (CL-011-14): solo informa.
direct_route() { [ "${VIA:-home}" = "direct" ]; }

# check_card <etiqueta> <captura-de-recientes>: la tarjeta se ve (cardlight) y su
# interior es liso (flat). Devuelve 1 si falla, salvo con VIA=direct (CL-011-14, solo informa).
check_card() {
  local l="$1" f="$2" r
  if ! r="$(img cardlight "$f")"; then
    echo "[$l] FALLO: no se ve la tarjeta de la app en 'Recientes' ($r); repite con RECENTS_WAIT=4" >&2; return 1
  fi
  if ! r="$(img flat "$f")"; then
    if direct_route; then echo "[$l] INFORMATIVO (VIA=direct, CL-011-14): el interior de la tarjeta no es liso ($r)"; return 0; fi
    echo "[$l] FALLO CA-011-01: el interior de la tarjeta no es liso, hay contenido residual ($r)" >&2; return 1
  fi
  echo "[$l] tarjeta visible y lisa: $r"
}

# Análisis de imágenes (Pillow + numpy). Subcomandos: nonblank, ncc, same, frames.
img() {
  python3 - "$@" <<'PY'
import sys
import numpy as np
from PIL import Image

# Posición de la tarjeta de "Recientes" (fracciones de la pantalla) medida en el
# Pixel 6a / emulador de 1080x2400. Se puede cambiar con CARD="x0,y0,x1,y1".
import os
CARD = tuple(float(v) for v in os.environ.get("CARD", "0.160,0.122,0.840,0.802").split(","))
MARGIN = 0.06  # se descartan las esquinas redondeadas de la tarjeta


def gray(path):
    return np.asarray(Image.open(path).convert("L"), dtype=np.float32)


def card_of(rec):
    h, w = rec.shape
    x0, y0, x1, y1 = CARD
    return rec[int(y0 * h):int(y1 * h), int(x0 * w):int(x1 * w)]


def inner(a):
    h, w = a.shape
    return a[int(MARGIN * h):int((1 - MARGIN) * h), int(MARGIN * w):int((1 - MARGIN) * w)]


def ncc(a, b):
    a = a - a.mean()
    b = b - b.mean()
    d = np.sqrt((a * a).sum() * (b * b).sum())
    return 0.0 if d < 1e-6 else float((a * b).sum() / d)


def front_as_card(front, rec):
    """La captura a pantalla completa, reducida al tamaño de la tarjeta."""
    card = card_of(rec)
    h, w = card.shape
    img = Image.fromarray(front.astype(np.uint8)).resize((w, h), Image.BILINEAR)
    return np.asarray(img, dtype=np.float32), card


cmd = sys.argv[1]
if cmd == "nonblank":
    a = gray(sys.argv[2])
    body = a[int(0.1 * a.shape[0]):, :]
    print(f"mean={body.mean():.1f} std={body.std():.1f}")
    sys.exit(0 if body.std() > 5 and body.mean() > 8 else 1)
elif cmd == "ncc":  # ncc <front> <recents>: parecido entre la tarjeta y la pantalla
    front, rec = gray(sys.argv[2]), gray(sys.argv[3])
    f, c = front_as_card(front, rec)
    v = ncc(inner(f), inner(c))
    print(f"{v:.3f}")
elif cmd == "cardlight":  # cardlight <recents>: ¿hay una tarjeta clara en su sitio?
    # Evita el falso "idénticas" de dos capturas sin tarjeta (el lanzador tarda en
    # pintarla): el fondo del lanzador es oscuro; la tarjeta vacía es clara y lisa.
    c = inner(card_of(gray(sys.argv[2])))
    print(f"media={c.mean():.0f} desv={c.std():.1f}")
    sys.exit(0 if c.mean() > 200 else 1)
elif cmd == "flat":  # flat <recents>: ¿el interior de la tarjeta es liso?
    # La tarjeta esperada es un fondo liso (blanco). El interior que se mira excluye la
    # franja de arriba (12 % de la tarjeta: en API 37 es la barra negra con la hora y los
    # iconos del sistema, escalada) y un 6 % abajo y a los lados (esquinas y borde).
    # Calibrado (1080x2400): tarjeta vacía std 0,00; línea base (con contenido) 32-33;
    # ruta directa 32; selector de fotos 76; cámara 91. Umbral por defecto 2.
    c = card_of(gray(sys.argv[2]))
    h, w = c.shape
    x = c[int(0.12 * h):int(0.94 * h), int(0.06 * w):int(0.94 * w)]
    limit = float(os.environ.get("FLAT_MAX_STD", "2"))
    print(f"desv={x.std():.2f} (max {limit:g})")
    sys.exit(0 if x.std() <= limit else 1)
elif cmd == "same":  # same <recentsA> <recentsB>: ¿tarjetas idénticas?
    a, b = inner(card_of(gray(sys.argv[2]))), inner(card_of(gray(sys.argv[3])))
    frac = float((np.abs(a - b) > 8).mean())
    print(f"{frac:.5f}")
    sys.exit(0 if frac < 0.001 else 1)
elif cmd == "frames":  # frames <raw> <front.png> <ancho> <alto>: parpadeo
    raw, front_png, w, h = sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
    data = np.fromfile(raw, dtype=np.uint8)
    size = w * h * 3
    n = len(data) // size
    if n == 0:
        print("sin fotogramas"); sys.exit(1)
    frames = data[: n * size].reshape(n, h, w, 3).astype(np.float32).mean(axis=3)
    ref = np.asarray(Image.open(front_png).convert("L").resize((w, h), Image.BILINEAR), dtype=np.float32)
    # Zona central (15-85 %): sin la barra de estado ni la píldora de gestos y sin los
    # bordes, que en la animación de vuelta enseñan el fondo del lanzador (con la zona
    # completa un fotograma blanco no salía "liso" y no se contaba).
    body = (slice(int(0.15 * h), int(0.85 * h)), slice(int(0.15 * w), int(0.85 * w)))
    sims = [ncc(f[body], ref[body]) for f in frames]
    # La grabación empieza con "Recientes" en pantalla: solo cuentan los
    # fotogramas desde que algo cambia (la vuelta a la app).
    start = next((i for i in range(1, n) if np.abs(frames[i][body] - frames[0][body]).mean() > 1.0), n)
    smooth = [i for i in range(start, n) if frames[i][body].std() < 3]
    # Excepción aceptada (CA-011-03): fotograma liso BLANCO al volver desde
    # "Recientes". Cualquier otro liso (negro u otro color) es fallo.
    white = [i for i in smooth if frames[i][body].mean() > 235]
    blank = [i for i in smooth if i not in white]
    # Fotogramas con la pantalla de la app (mismo dibujo que la referencia).
    shown = [i for i in range(start, n) if sims[i] > 0.9]
    lost = [i for i in range(shown[0], n) if sims[i] <= 0.9] if shown else []
    if len(sys.argv) > 6:  # tira de fotogramas para revisarlos a ojo
        Image.fromarray(np.concatenate([f.astype(np.uint8) for f in data[: n * size].reshape(n, h, w, 3)], axis=1)).save(sys.argv[6])
    print(f"fotogramas={n} desde={start} con_la_app={len(shown)} blancos_aceptados={white} lisos_fallo={blank} perdidos={lost}")
    sys.exit(0 if (shown and not blank and not lost) else 1)
PY
}

case "$CMD" in
  secure)
    st="$(secure_state)"
    echo "FLAG_SECURE en la ventana de la app: $st"
    [ "$st" != "unknown" ] || { echo "FALLO: no encuentro la ventana de $PKG en dumpsys (¿la app está abierta y delante?); no se puede afirmar que no lleve FLAG_SECURE" >&2; exit 1; }
    [ "$st" = "not-secure" ] || { echo "FALLO CA-011-04: con la app delante no debe haber FLAG_SECURE" >&2; exit 1; }
    ;;

  capture)
    LABEL="${1:?Falta la etiqueta}"
    setup_out "${2:-}"
    fail=0
    # Con la app delante (CA-011-04): sin FLAG_SECURE y captura con contenido.
    st="$(secure_state)"
    shot "$OUT/$LABEL-front.png"
    echo "[$LABEL] delante: FLAG_SECURE=$st; $(img nonblank "$OUT/$LABEL-front.png" || echo 'CAPTURA SIN CONTENIDO')"
    [ "$st" = "not-secure" ] || { echo "FALLO CA-011-04: FLAG_SECURE con la app delante" >&2; fail=1; }
    img nonblank "$OUT/$LABEL-front.png" >/dev/null || { echo "FALLO CA-011-04: la captura sale sin contenido" >&2; fail=1; }
    # Con la app detrás, en "Recientes".
    open_recents
    shot "$OUT/$LABEL-recents.png"
    echo "[$LABEL] recientes: FLAG_SECURE=$(secure_state); parecido tarjeta/pantalla=$(img ncc "$OUT/$LABEL-front.png" "$OUT/$LABEL-recents.png")"
    check_card "$LABEL" "$OUT/$LABEL-recents.png" || fail=1
    back_to_app
    exit "$fail"
    ;;

  compare)
    A="${1:?Falta la etiqueta A}"; B="${2:?Falta la etiqueta B}"
    [ -n "${3:-}" ] || { echo "Falta el directorio de las capturas (el que imprimió 'capture')" >&2; exit 2; }
    OUT="$3"
    fail=0
    for L in "$A" "$B"; do
      check_card "$L" "$OUT/$L-recents.png" || fail=1
      v="$(img ncc "$OUT/$L-front.png" "$OUT/$L-recents.png")"
      if python3 -c "import sys; sys.exit(0 if float('$v') < 0.5 else 1)"; then
        echo "[$L] la tarjeta no se parece a la pantalla (parecido $v): bien"
      elif direct_route; then
        echo "[$L] INFORMATIVO (VIA=direct, CL-011-14): la tarjeta enseña la ventana en vivo (parecido $v)"
      else
        echo "FALLO CA-011-01: la tarjeta de '$L' enseña el contenido (parecido $v con la pantalla)" >&2; fail=1
      fi
    done
    if diff="$(img same "$OUT/$A-recents.png" "$OUT/$B-recents.png")"; then
      echo "las tarjetas de $A y $B son idénticas (píxeles distintos: $diff): bien"
    elif direct_route; then
      echo "INFORMATIVO (VIA=direct, CL-011-14): las tarjetas de $A y $B difieren (píxeles distintos: $diff)"
    else
      echo "FALLO CA-011-01: las tarjetas de $A y $B difieren (píxeles distintos: $diff)" >&2; fail=1
    fi
    exit "$fail"
    ;;

  loop)
    N="${1:?Faltan las vueltas}"; setup_out "${2:-}"
    fail=0
    shot "$OUT/loop-ref.png"
    img nonblank "$OUT/loop-ref.png" >/dev/null || { echo "La pantalla de referencia está en negro" >&2; exit 1; }
    for ((i = 1; i <= N; i++)); do
      open_recents
      shot "$OUT/loop-$i-recents.png"
      v="$(img ncc "$OUT/loop-ref.png" "$OUT/loop-$i-recents.png")"
      cardmsg="$(check_card "vuelta $i" "$OUT/loop-$i-recents.png" 2>&1)" || fail=1
      back_to_app
      shot "$OUT/loop-$i-front.png"
      st="$(secure_state)"
      msg="vuelta $i: parecido tarjeta=$v; FLAG_SECURE delante=$st"
      if ! python3 -c "import sys; sys.exit(0 if float('$v') < 0.5 else 1)"; then
        if direct_route; then msg="$msg  <- informativo (VIA=direct, CL-011-14)"
        else msg="$msg  <- FALLO: la tarjeta enseña el contenido"; fail=1; fi
      fi
      [ "$st" = "not-secure" ] || { msg="$msg  <- FALLO: FLAG_SECURE (o ventana no encontrada) con la app delante"; fail=1; }
      img nonblank "$OUT/loop-$i-front.png" >/dev/null || { msg="$msg  <- FALLO: la captura sale sin contenido"; fail=1; }
      echo "$msg"
      echo "$cardmsg"
    done
    exit "$fail"
    ;;

  record)
    N="${1:?Faltan las vueltas}"; setup_out "${2:-}"
    W=270; H=600
    fail=0
    shot "$OUT/record-ref.png"
    for ((i = 1; i <= N; i++)); do
      open_recents
      shot "$OUT/record-$i-recents.png"
      check_card "vuelta $i" "$OUT/record-$i-recents.png" || fail=1
      # Se graba solo la vuelta a la app. screenrecord no termina solo con un
      # cliente adb: se limita por tiempo y se corta desde aquí.
      adb exec-out screenrecord --output-format=raw-frames --time-limit 4 --size ${W}x${H} - > "$OUT/record-$i.raw" &
      rec=$!
      sleep 1
      adb shell am start -n "$ACTIVITY" >/dev/null 2>&1
      sleep 4.5
      adb shell pkill -INT screenrecord >/dev/null 2>&1 || true
      sleep 1
      kill "$rec" 2>/dev/null || true; wait "$rec" 2>/dev/null || true
      msg="vuelta $i: $(img frames "$OUT/record-$i.raw" "$OUT/record-ref.png" $W $H "$OUT/record-$i-tira.png")" || fail=1
      echo "$msg"
      rm -f "$OUT/record-$i.raw"
    done
    exit "$fail"
    ;;

  fixtures)
    SUB="${1:-}"
    DIR_ON_DEVICE="/sdcard/Pictures/una-recents"
    case "$SUB" in
      push)
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/una-fixtures.XXXXXX")"
        trap 'rm -rf "${tmp:?}"' EXIT
        python3 - "$tmp" <<'PY'
import sys
from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
colors = [(220, 40, 40), (40, 170, 70), (40, 80, 220)]
for i, color in enumerate(colors, start=1):
    img = Image.new("RGB", (1200, 1600), color)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.load_default(size=900)
    except TypeError:
        font = ImageFont.load_default()
    d.text((600, 800), str(i), fill=(255, 255, 255), anchor="mm", font=font)
    img.save(f"{out}/foto-{i}.jpg", quality=85)
PY
        adb shell mkdir -p "$DIR_ON_DEVICE"
        for i in 1 2 3; do
          adb push "$tmp/foto-$i.jpg" "$DIR_ON_DEVICE/foto-$i.jpg" >/dev/null
          adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$DIR_ON_DEVICE/foto-$i.jpg" >/dev/null
        done
        echo "Tres fotos de prueba en $DIR_ON_DEVICE (la 1 roja, la 2 verde, la 3 azul). Al acabar: fixtures clean."
        ;;
      clean)
        for i in 1 2 3; do
          adb shell rm -f "$DIR_ON_DEVICE/foto-$i.jpg"
          adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$DIR_ON_DEVICE/foto-$i.jpg" >/dev/null
        done
        adb shell rmdir "$DIR_ON_DEVICE" 2>/dev/null || true
        echo "Fotos de prueba borradas de $DIR_ON_DEVICE."
        ;;
      *) usage ;;
    esac
    ;;

  *) usage ;;
esac
