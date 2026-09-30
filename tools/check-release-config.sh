#!/usr/bin/env bash
# Puerta de publicación (spec 012, CA-012-05): falla si la dirección de la política de
# privacidad (app/identity.yaml → privacyPolicyUrl) no es una `https` de un dominio propio
# (no el marcador example.com ni ningún dominio reservado), o si docs/legal/privacy-policy.md
# sigue con huecos ([NOMBRE DE LA APP], [FECHA], [RESPONSABLE], [CONTACTO] y sus versiones EN).
#
#   tools/check-release-config.sh                                   (los valores del repositorio)
#   tools/check-release-config.sh --url <dirección> --policy <archivo>   (valores de prueba)
#
# SOLO en la lista de publicación (`/release-checklist`) y en el trabajo de CI que genere el
# artefacto de publicación (F6, aún no existe): NO en las compilaciones locales ni de desarrollo,
# donde el marcador es normal. Necesita `dart`; no instala nada ni usa la red.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Las rutas dadas se resuelven antes de entrar en app/ (donde vive el paquete de Dart).
args=()
have_policy=0
while [ $# -gt 0 ]; do
  case "$1" in
    --policy)
      [ $# -ge 2 ] || { echo "::error::--policy necesita un valor"; exit 2; }
      have_policy=1
      dir="$(dirname "$2")"
      [ -d "$dir" ] || { echo "::error::no existe el directorio de la política ($dir)"; exit 1; }
      args+=("--policy" "$(cd "$dir" && pwd)/$(basename "$2")")
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done
if [ "$have_policy" -eq 0 ]; then
  args+=("--policy" "$ROOT/docs/legal/privacy-policy.md")
fi

cd "$ROOT/app"
exec dart run tool/check_release_config.dart "${args[@]}"
