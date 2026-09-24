#!/usr/bin/env bash
# Falla si el manifiesto combinado de Android declara permisos no permitidos (threat-model T-13).
# Se ejecuta desde app/ tras `flutter build apk --debug`.
set -euo pipefail

ALLOWED=(
  "android.permission.INTERNET"   # WebView de tareas URL (ADR-0007)
  "android.permission.CAMERA"     # Solo si "Hacer foto" usa el permiso (spec 007)
)

MANIFEST="$(find build/app/intermediates -path '*merged_manifest*' -name AndroidManifest.xml | head -n1)"
if [ -z "$MANIFEST" ]; then
  echo "No se encontró el manifiesto combinado" >&2
  exit 1
fi

status=0
while IFS= read -r perm; do
  ok=false
  for a in "${ALLOWED[@]}"; do [ "$perm" = "$a" ] && ok=true; done
  # Permisos internos que Flutter añade en debug (conexión con la herramienta de desarrollo)
  [[ "$perm" == *".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" ]] && ok=true
  if [ "$ok" = false ]; then
    echo "::error::Permiso no permitido en el manifiesto: $perm"
    status=1
  fi
done < <(grep -o 'android:name="android\.permission\.[A-Z_]*"\|android:name="[a-z0-9_.]*\.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"' "$MANIFEST" | sed 's/android:name="\(.*\)"/\1/' | sort -u)

exit $status
