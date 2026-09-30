#!/usr/bin/env bash
# Verificación de la spec 011 (ocultar el contenido en "Recientes") con adb.
#
#   tools/check-recents.sh <serial-adb> capture <etiqueta> [directorio]
#   tools/check-recents.sh <serial-adb> compare <etiquetaA> <etiquetaB> [directorio]
#   tools/check-recents.sh <serial-adb> secure
#   tools/check-recents.sh <serial-adb> loop <vueltas> [directorio]
#   tools/check-recents.sh <serial-adb> record <vueltas> [directorio]
#
# El serial es OBLIGATORIO (no hay valor por defecto: con dos dispositivos
# conectados adb falla y nunca se debe tocar el móvil del propietario). Para un
# dispositivo físico (serial que no empieza por "emulator-") hace falta además
# ALLOW_PHYSICAL=1, que solo se pone con permiso explícito del propietario.
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
#            hay un fotograma liso negro o blanco o si, una vez visible la pantalla
#            de la app, vuelve a desaparecer (parpadeo, CA-011-03).
#   VIA=direct abre "Recientes" desde la propia app (por defecto pasa por el escritorio).
#   secure:  falla si la ventana de la app lleva FLAG_SECURE ahora (CA-011-04).
#
# Requisitos: adb (variable ADB, PATH o el SDK de Android en ~/Library/Android),
# python3 con Pillow y numpy. El paquete se cambia con PKG (por defecto
# invalid.pending.app; la compilación debug es invalid.pending.app.debug).
# Las capturas son de la app con datos de prueba (tareas "uno" y "dos"): no las
# guardes con datos reales.
#
# Códigos de salida: 0 todo bien; 1 un criterio falla; 2 uso incorrecto.
set -euo pipefail

usage() { sed -n "2,34p" "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

SERIAL="${1:-}"
[ -n "$SERIAL" ] || { echo "Falta el serial de adb (primer argumento). Sin serial no se ejecuta nada." >&2; usage; }
case "$SERIAL" in
  emulator-*) ;;
  *) [ "${ALLOW_PHYSICAL:-}" = "1" ] || {
       echo "'$SERIAL' no es un emulador. Un dispositivo físico solo se usa con permiso explícito del propietario (ALLOW_PHYSICAL=1)." >&2
       exit 2
     } ;;
esac
CMD="${2:-}"
[ -n "$CMD" ] || usage
shift 2

PKG="${PKG:-invalid.pending.app}"
ACTIVITY="$PKG/invalid.pending.app.MainActivity"

ADB_BIN="${ADB:-$(command -v adb || true)}"
[ -n "$ADB_BIN" ] || ADB_BIN="$HOME/Library/Android/sdk/platform-tools/adb"
[ -x "$ADB_BIN" ] || { echo "No encuentro adb (variable ADB)" >&2; exit 2; }
adb() { "$ADB_BIN" -s "$SERIAL" "$@"; }

if [ "$CMD" != "compare" ]; then
  [ "$(adb get-state 2>/dev/null || true)" = "device" ] || { echo "El dispositivo $SERIAL no está disponible" >&2; exit 2; }
fi

# ¿Lleva la ventana de la app FLAG_SECURE? Imprime "secure" o "not-secure".
secure_state() {
  adb shell dumpsys window windows | awk -v w="Window{.* $PKG/" '
    $0 ~ "Window #" && $0 ~ w { inwin = 1; next }
    inwin && $0 ~ "Window #" { inwin = 0 }
    inwin && $1 ~ /^fl=/ { if ($0 ~ /(^|[ =])SECURE( |$)/) found = 1 }
    END { print found ? "secure" : "not-secure" }'
}

shot() { adb exec-out screencap -p > "$1"; }
back_to_app() { adb shell am start -n "$ACTIVITY" >/dev/null 2>&1; sleep 2; }
# Abre "Recientes". Por defecto pasa antes por el escritorio (la app queda en
# segundo plano y parada: la tarjeta es la instantánea del sistema). Con
# VIA=direct lo abre desde la propia app: en Android 14+ el lanzador puede enseñar
# ahí la ventana en vivo de la app en lugar de la instantánea.
open_recents() {
  if [ "${VIA:-home}" = "home" ]; then adb shell input keyevent KEYCODE_HOME; sleep 2; fi
  adb shell input keyevent KEYCODE_APP_SWITCH; sleep 2.5
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
    body = slice(int(0.1 * h), h)  # sin la barra de estado (reloj)
    sims = [ncc(f[body], ref[body]) for f in frames]
    # La grabación empieza con "Recientes" en pantalla: solo cuentan los
    # fotogramas desde que algo cambia (la vuelta a la app).
    start = next((i for i in range(1, n) if np.abs(frames[i][body] - frames[0][body]).mean() > 1.0), n)
    blank = [i for i in range(start, n) if frames[i][body].std() < 3 and (frames[i][body].mean() < 20 or frames[i][body].mean() > 235)]
    # Fotogramas con la pantalla de la app (mismo dibujo que la referencia).
    shown = [i for i in range(start, n) if sims[i] > 0.9]
    lost = [i for i in range(shown[0], n) if sims[i] <= 0.9] if shown else []
    if len(sys.argv) > 6:  # tira de fotogramas para revisarlos a ojo
        Image.fromarray(np.concatenate([f.astype(np.uint8) for f in data[: n * size].reshape(n, h, w, 3)], axis=1)).save(sys.argv[6])
    print(f"fotogramas={n} desde={start} con_la_app={len(shown)} lisos={blank} perdidos={lost}")
    sys.exit(0 if (shown and not blank and not lost) else 1)
PY
}

case "$CMD" in
  secure)
    st="$(secure_state)"
    echo "FLAG_SECURE en la ventana de la app: $st"
    [ "$st" = "not-secure" ] || { echo "FALLO CA-011-04: con la app delante no debe haber FLAG_SECURE" >&2; exit 1; }
    ;;

  capture)
    LABEL="${1:?Falta la etiqueta}"
    OUT="${2:-.}"; mkdir -p "$OUT"
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
    back_to_app
    exit "$fail"
    ;;

  compare)
    A="${1:?Falta la etiqueta A}"; B="${2:?Falta la etiqueta B}"
    OUT="${3:-.}"
    fail=0
    for L in "$A" "$B"; do
      v="$(img ncc "$OUT/$L-front.png" "$OUT/$L-recents.png")"
      if python3 -c "import sys; sys.exit(0 if float('$v') < 0.5 else 1)"; then
        echo "[$L] la tarjeta no se parece a la pantalla (parecido $v): bien"
      else
        echo "FALLO CA-011-01: la tarjeta de '$L' enseña el contenido (parecido $v con la pantalla)" >&2; fail=1
      fi
    done
    if diff="$(img same "$OUT/$A-recents.png" "$OUT/$B-recents.png")"; then
      echo "las tarjetas de $A y $B son idénticas (píxeles distintos: $diff): bien"
    else
      echo "FALLO CA-011-01: las tarjetas de $A y $B difieren (píxeles distintos: $diff)" >&2; fail=1
    fi
    exit "$fail"
    ;;

  loop)
    N="${1:?Faltan las vueltas}"; OUT="${2:-.}"; mkdir -p "$OUT"
    fail=0
    shot "$OUT/loop-ref.png"
    img nonblank "$OUT/loop-ref.png" >/dev/null || { echo "La pantalla de referencia está en negro" >&2; exit 1; }
    for ((i = 1; i <= N; i++)); do
      open_recents
      shot "$OUT/loop-$i-recents.png"
      v="$(img ncc "$OUT/loop-ref.png" "$OUT/loop-$i-recents.png")"
      back_to_app
      shot "$OUT/loop-$i-front.png"
      st="$(secure_state)"
      msg="vuelta $i: parecido tarjeta=$v; FLAG_SECURE delante=$st"
      python3 -c "import sys; sys.exit(0 if float('$v') < 0.5 else 1)" || { msg="$msg  <- FALLO: la tarjeta enseña el contenido"; fail=1; }
      [ "$st" = "not-secure" ] || { msg="$msg  <- FALLO: FLAG_SECURE con la app delante"; fail=1; }
      img nonblank "$OUT/loop-$i-front.png" >/dev/null || { msg="$msg  <- FALLO: la captura sale sin contenido"; fail=1; }
      echo "$msg"
    done
    exit "$fail"
    ;;

  record)
    N="${1:?Faltan las vueltas}"; OUT="${2:-.}"; mkdir -p "$OUT"
    W=270; H=600
    fail=0
    shot "$OUT/record-ref.png"
    for ((i = 1; i <= N; i++)); do
      open_recents
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

  *) usage ;;
esac
