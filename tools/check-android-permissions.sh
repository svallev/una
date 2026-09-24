#!/usr/bin/env bash
# Falla si el manifiesto combinado de Android pide permisos no permitidos (threat-model T-13).
#
#   tools/check-android-permissions.sh [release|debug]     (desde app/, tras compilar esa variante)
#
# La release es la que importa: sin ningún permiso hasta la spec 009 (INTERNET para
# la WebView de tareas URL, ADR-0007). Se revisan todos los <uses-permission*>, de
# cualquier espacio de nombres (p. ej. com.google.android.gms.permission.AD_ID).
set -euo pipefail

MODE="${1:-release}"
case "$MODE" in
  release) ALLOWED=() ;;                              # Spec 009 añadirá android.permission.INTERNET
  debug)   ALLOWED=("android.permission.INTERNET") ;; # La herramienta de Flutter la añade en debug
  *) echo "Uso: $0 [release|debug]" >&2; exit 2 ;;
esac

MANIFEST="$(find build/app/intermediates/merged_manifest -path "*/$MODE/*" -name AndroidManifest.xml | head -n1)"
if [ -z "$MANIFEST" ]; then
  echo "No se encontró el manifiesto combinado de $MODE. Compila antes: flutter build apk --$MODE" >&2
  exit 1
fi
PKG="$(grep -o 'package="[^"]*"' "$MANIFEST" | head -n1 | sed 's/package="\(.*\)"/\1/')"

status=0
count=0
while IFS= read -r perm; do
  [ -z "$perm" ] && continue
  count=$((count + 1))
  ok=false
  for a in "${ALLOWED[@]+"${ALLOWED[@]}"}"; do [ "$perm" = "$a" ] && ok=true; done
  # Permiso interno de androidx (nivel firma, lo declara la propia app)
  [ "$perm" = "${PKG}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" ] && ok=true
  if [ "$ok" = false ]; then
    echo "::error::Permiso no permitido en el manifiesto de $MODE: $perm"
    status=1
  fi
done < <(grep -oE '<uses-permission(-sdk-23)?[^>]*>' "$MANIFEST" | grep -oE 'android:name="[^"]+"' | sed 's/android:name="\(.*\)"/\1/' | sort -u)

[ "$status" -eq 0 ] && echo "Permisos de $MODE correctos ($count revisados; $MANIFEST)."
exit $status
