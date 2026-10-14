#!/usr/bin/env bash
# Una comprobación del trabajo de publicación (spec 020, CA-020-02; plan §3.2): la ejecuta, guarda su
# salida y anota su resultado en `results.tsv`, que lee `app/tool/release_summary.dart`.
#
#   tools/release/run-check.sh <id> -- <comando> [argumentos…]
#
# `<id>` es el de la comprobación (minúsculas y guiones; el resumen tiene la lista cerrada). Un
# argumento que sea exactamente `{json}` se sustituye por la ruta del JSON de errores con clase de
# esa comprobación (`<carpeta>/<id>.json`), que se borra antes de empezar para que nunca se lea el
# de una ejecución anterior; esa ruta queda en la línea de `results.tsv`.
#
# Cada ejecución añade una línea `id<TAB>código<TAB>ruta del JSON (o vacío)` a
# `<carpeta>/results.tsv`, aunque la comprobación falle, y la salida (también la de error) se guarda
# en `<carpeta>/<id>.log` y se muestra. El script sale con el **código de la comprobación**: el paso
# del workflow lleva `continue-on-error`, de modo que su `outcome` en GitHub es el verdadero y el
# resumen puede cruzarlo con la línea de `results.tsv` (un id repetido, una línea que no casa o una
# comprobación sin línea son un fallo). La carpeta es `$RELEASE_DIR` o, si no, `$RUNNER_TEMP/release`
# (fuera del *workspace*, para que ni Gradle ni los *hooks* de pub la toquen). Códigos propios:
# 2 uso incorrecto. No instala nada ni usa la red.
set -uo pipefail

usage() {
  echo "Uso: $0 <id> -- <comando> [argumentos…]" >&2
  exit 2
}

[ $# -ge 3 ] || usage
id="$1"
shift
[ "$1" = "--" ] || usage
shift
[ $# -ge 1 ] || usage
if ! grep -E '^[a-z][a-z-]*$' <<<"$id" >/dev/null; then
  echo "::error::run-check: el id «${id}» no es válido (minúsculas y guiones)" >&2
  exit 2
fi

dir="${RELEASE_DIR:-}"
if [ -z "$dir" ]; then
  if [ -z "${RUNNER_TEMP:-}" ]; then
    echo "::error::run-check: define RELEASE_DIR o RUNNER_TEMP (carpeta de results.tsv)" >&2
    exit 2
  fi
  dir="$RUNNER_TEMP/release"
fi
mkdir -p "$dir" || { echo "::error::run-check: no se puede crear $dir" >&2; exit 2; }

json=""
cmd=()
for arg in "$@"; do
  if [ "$arg" = "{json}" ]; then
    json="$dir/$id.json"
    arg="$json"
  fi
  cmd+=("$arg")
done
[ -z "$json" ] || rm -f "$json"

# La comprobación puede no existir (127) o no poder ejecutarse (126): también se anota.
"${cmd[@]}" 2>&1 | tee "$dir/$id.log"
code="${PIPESTATUS[0]}"

printf '%s\t%s\t%s\n' "$id" "$code" "$json" >> "$dir/results.tsv"
exit "$code"
