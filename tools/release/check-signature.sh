#!/usr/bin/env bash
# La firma del paquete de release (spec 020, CA-020-03 e, CA-020-05 d): `apksigner verify` en un APK
# y `jarsigner -verify -strict` + `keytool -printcert -jarfile` en un AAB.
#
#   tools/release/check-signature.sh [--mode strict|testers] [--json <archivo>] <apk|aab>...
#   (también --upload-cert <archivo>, --apksigner/--jarsigner/--keytool <ruta> para otras herramientas)
#
# Sin firma o con el certificado de depuración (`CN=Android Debug`) es un **aviso de identidad**; una
# firma que no verifica, un fallo. En modo `strict`, sin `tools/release/upload-cert.sha256` (la huella
# SHA-256 pública del certificado de subida, **[Pendiente, F6]**) también es un aviso; con él, un
# certificado distinto es un fallo. Con `--json` escribe la lista con su clase, para el resumen del
# trabajo de publicación. Falla cerrada: 0 paquetes es un fallo (código 2). Necesita `dart` y
# `apksigner` (build-tools del SDK de Android), `jarsigner` y `keytool` (JDK); no instala nada.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

abs_file() {
  local dir
  dir="$(dirname "$1")"
  if [ -d "$dir" ]; then
    echo "$(cd "$dir" && pwd)/$(basename "$1")"
  else
    case "$1" in
      /*) echo "$1" ;;
      *) echo "$PWD/$1" ;;
    esac
  fi
}

args=(--upload-cert "$ROOT/tools/release/upload-cert.sha256")
while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      [ $# -ge 2 ] || { echo "::error::--mode necesita un valor"; exit 2; }
      args+=("--mode" "$2")
      shift 2
      ;;
    --json|--upload-cert|--apksigner|--jarsigner|--keytool)
      [ $# -ge 2 ] || { echo "::error::$1 necesita un valor"; exit 2; }
      args+=("$1" "$(abs_file "$2")")
      shift 2
      ;;
    --*)
      echo "::error::argumento desconocido: $1" >&2
      exit 2
      ;;
    *)
      args+=("$(abs_file "$1")")
      shift
      ;;
  esac
done

cd "$ROOT/app"
exec dart run tool/check_signature.dart "${args[@]}"
