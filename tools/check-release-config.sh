#!/usr/bin/env bash
# Puerta de publicación (spec 012, CA-012-05; spec 015, CA-015-13b): falla si
#  - alguna de las tres direcciones de app/identity.yaml (privacyPolicyUrl, thirdPartyLicensesUrl,
#    helpUrl) no es una `https` de un dominio propio (no el marcador example.com ni ningún dominio
#    reservado, sin `?`, `#` ni `\`, con una ruta de solo letras ASCII, cifras y `._~-/` sin `%`, `.`,
#    `..` ni `//`), o si dos de ellas son la misma dirección;
#  - lo generado desde el yaml (lib/app/app_identity.g.dart…) no está al día (`gen_identity.dart
#    --check`): la puerta valida lo que se compila, no solo el yaml;
#  - docs/legal/privacy-policy.md sigue con huecos ([NOMBRE DE LA APP], [FECHA], [RESPONSABLE],
#    [CONTACTO] y sus versiones EN) o con marcas de documento ([Suposición], [Assumption],
#    [Pendiente], [Pending]) en las partes ES y EN (spec 020, CA-020-11);
#  - alguno de esos archivos falta, está vacío, no es YAML válido o no se puede leer (falla cerrada,
#    CA-020-12: nunca se da por buena una comprobación que no ha podido hacerse).
#
#   tools/check-release-config.sh                                    (los valores del repositorio)
#   tools/check-release-config.sh --identity <archivo> --policy <archivo>   (valores de prueba)
#   tools/check-release-config.sh ... --generated-root <carpeta>     (otra copia de app/ para lo generado)
#   tools/check-release-config.sh ... --json <archivo>               (además, la lista de errores con su clase)
#
# Lo ejecuta el trabajo de publicación (`.github/workflows/release.yml`, id `identity`, con `--json`:
# spec 020, CA-020-02), que clasifica sus errores (CA-020-05): en una entrega a testers los avisos de
# identidad se listan y en una publicación tienen que pasar. NO corre en las compilaciones locales,
# de desarrollo ni de la CI de las PR, donde los marcadores son normales (CA-020-08). Necesita `dart`;
# no instala nada ni usa la red.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Las rutas dadas se resuelven antes de entrar en app/ (donde vive el paquete de Dart).
# Si la carpeta no existe, la ruta se pasa tal cual: la herramienta informa de que el archivo no
# existe (falla cerrada, CA-020-12) y escribe el JSON.
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
    --json)
      [ $# -ge 2 ] || { echo "::error::--json necesita un valor"; exit 2; }
      args+=("--json" "$(abs_file "$2")")
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

# La herramienta comprueba también lo generado (`gen_identity.dart --check`) y lo cuenta como un
# fallo más, en la salida y en el JSON.
exec dart run tool/check_release_config.dart --generated-root "$generated_root" "${args[@]}"
