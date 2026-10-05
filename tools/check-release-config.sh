#!/usr/bin/env bash
# Puerta de publicación (spec 012, CA-012-05; spec 015, CA-015-13b): falla si
#  - alguna de las tres direcciones de app/identity.yaml (privacyPolicyUrl, thirdPartyLicensesUrl,
#    helpUrl) no es una `https` de un dominio propio (no el marcador example.com ni ningún dominio
#    reservado, sin `?`, `#` ni `\`), o si dos de ellas son la misma dirección;
#  - lo generado desde el yaml (lib/app/app_identity.g.dart…) no está al día (`gen_identity.dart
#    --check`): la puerta valida lo que se compila, no solo el yaml;
#  - docs/legal/privacy-policy.md sigue con huecos ([NOMBRE DE LA APP], [FECHA], [RESPONSABLE],
#    [CONTACTO] y sus versiones EN).
#
#   tools/check-release-config.sh                                    (los valores del repositorio)
#   tools/check-release-config.sh --identity <archivo> --policy <archivo>   (valores de prueba)
#   tools/check-release-config.sh ... --generated-root <carpeta>     (otra copia de app/ para lo generado)
#
# Se ejecuta en `/release-checklist` **antes de cada entrega a testers** y antes de publicar (en una
# entrega a testers con marcadores se anota qué falla; antes de publicar tiene que pasar) y, en F6,
# en el trabajo de CI que genere el artefacto de publicación (aún no existe): NO en las
# compilaciones locales ni de desarrollo, donde los marcadores son normales. Necesita `dart`; no
# instala nada ni usa la red.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Las rutas dadas se resuelven antes de entrar en app/ (donde vive el paquete de Dart).
abs_file() {
  local dir
  dir="$(dirname "$1")"
  [ -d "$dir" ] || { echo "::error::no existe el directorio de $1"; exit 1; }
  echo "$(cd "$dir" && pwd)/$(basename "$1")"
}

args=()
have_policy=0
generated_root="$ROOT/app"
while [ $# -gt 0 ]; do
  case "$1" in
    --policy)
      [ $# -ge 2 ] || { echo "::error::--policy necesita un valor"; exit 2; }
      have_policy=1
      args+=("--policy" "$(abs_file "$2")")
      shift 2
      ;;
    --identity)
      [ $# -ge 2 ] || { echo "::error::--identity necesita un valor"; exit 2; }
      args+=("--identity" "$(abs_file "$2")")
      shift 2
      ;;
    --generated-root)
      [ $# -ge 2 ] || { echo "::error::--generated-root necesita un valor"; exit 2; }
      [ -d "$2" ] || { echo "::error::no existe la carpeta $2"; exit 1; }
      generated_root="$(cd "$2" && pwd)"
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

status=0
if ! dart run tool/gen_identity.dart --check --root "$generated_root"; then
  echo "::error::lo generado desde identity.yaml no está al día: ejecuta \`dart run tool/gen_identity.dart\` en app/"
  status=1
fi

check_status=0
dart run tool/check_release_config.dart "${args[@]}" || check_status=$?
if [ "$check_status" -ne 0 ]; then
  exit "$check_status"
fi
exit "$status"
