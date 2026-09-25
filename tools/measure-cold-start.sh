#!/usr/bin/env bash
# Mide el arranque en frío de la app instalada (CA-001-09, T-001-17).
#
#   tools/measure-cold-start.sh <serial-adb> [arranques=20] [paquete=invalid.pending.app]
#
# Requisitos: compilación *release* instalada y al menos una tarea creada (la app
# debe abrir directamente en la tarea actual). Cada arranque detiene el proceso
# (`am start -S`) y registra TotalTime: desde el lanzamiento hasta el primer
# fotograma de la actividad, que en Flutter es el primer fotograma de la app
# (FlutterActivity retrasa el dibujo hasta entonces) y ya muestra la tarea
# (se lee antes de `runApp`).
set -euo pipefail

SERIAL="${1:?Uso: $0 <serial-adb> [arranques] [paquete]}"
RUNS="${2:-20}"
PKG="${3:-invalid.pending.app}"
ADB=(adb -s "$SERIAL")

"${ADB[@]}" shell pm path "$PKG" >/dev/null || { echo "La app $PKG no está instalada" >&2; exit 1; }

times=()
for ((i = 1; i <= RUNS; i++)); do
  t="$("${ADB[@]}" shell am start -W -S -n "$PKG/.MainActivity" | awk -F': ' '/TotalTime/ {print $2}' | tr -d '\r')"
  if [ -n "$t" ]; then times+=("$t"); echo "arranque $i: ${t} ms"; else echo "arranque $i: sin dato" >&2; fi
  sleep 2
done
"${ADB[@]}" shell am force-stop "$PKG"

[ "${#times[@]}" -gt 0 ] || { echo "Sin medidas válidas" >&2; exit 1; }
printf '%s\n' "${times[@]}" | sort -n | awk '
  { v[NR] = $1 }
  END {
    p50 = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
    p90 = v[int(0.9 * NR + 0.999)]
    printf "n=%d  min=%d  p50=%d  p90=%d  max=%d ms\n", NR, v[1], p50, p90, v[NR]
  }'
