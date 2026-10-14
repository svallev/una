#!/usr/bin/env bash
# Falla si un APK lleva clases de las pruebas JVM (JUnit/Hamcrest), spec 019 (C-2, P-019-1):
# JUnit 4 (EPL-1.0) solo entra como `testImplementation` y no se distribuye
# (threat-model §5, excepción de licencia). Mira los nombres de las entradas del APK y los
# descriptores de clase dentro de los classes*.dex (`Lorg/junit/…;`).
#
#   tools/check-apk-no-test-classes.sh <apk|aab>...    (desde app/, tras compilar; un AAB lleva sus
#                                                       dex en base/dex/, spec 020, CA-020-02)
#
# Ojo: R8 elimina del release lo que nadie usa, así que el APK sale limpio aunque JUnit estuviera
# declarado como `implementation` (comprobado en T-019-04); de que sea solo `testImplementation` se
# encarga `test/tool/check_apk_no_test_classes_test.dart`. Este script atrapa lo que R8 conservara.
#
# Se pasa a los APK de **release** (los que se distribuyen). El de debug lleva el plugin
# `integration_test` (dependencia de desarrollo, solo debug), cuyo código *referencia*
# `org.junit.runner.*`: ahí el nombre aparece en los dex sin que JUnit esté empaquetado.
set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "Uso: $0 <apk|aab>..." >&2
  exit 2
fi

PATTERN_ENTRY='(^|/)(org/junit|org/hamcrest|junit/framework)(/|$)'
PATTERN_DEX='L(org/junit|org/hamcrest|junit/framework)/'

# Falla cerrada: nada de leer el paquete por una tubería (con `pipefail`, un `unzip` que falla dentro
# de un `if` o tras `|| true` dejaba en verde un paquete ilegible o sin dex). El listado y cada dex
# se leen antes, comprobando el código de `unzip`, y se busca en lo leído.
DEX_FILE="$(mktemp "${TMPDIR:-/tmp}/check-apk-dex.XXXXXX")"
trap 'rm -f "$DEX_FILE"' EXIT

status=0
for apk in "$@"; do
  apk_status=0
  if [ ! -f "$apk" ]; then
    echo "::error::No existe el paquete: $apk" >&2
    status=1
    continue
  fi
  if ! listing="$(unzip -Z1 "$apk" 2>/dev/null)"; then
    echo "::error::$apk: no se puede listar (no es un zip legible)"
    status=1
    continue
  fi
  # Sin `grep -q` (ni tuberías): ver T-020-07 (SIGPIPE con `pipefail`).
  if grep -E "$PATTERN_ENTRY" <<<"$listing" >/dev/null; then
    echo "::error::$apk lleva entradas de JUnit/Hamcrest (org/junit, org/hamcrest, junit/framework)"
    apk_status=1
  fi
  dexes="$(grep -E '^(base/dex/)?classes[0-9]*\.dex$' <<<"$listing" || true)"
  if [ -z "$dexes" ]; then
    echo "::error::$apk sin ningún classes*.dex (ni en la raíz ni en base/dex/): no se puede revisar"
    status=1
    continue
  fi
  while IFS= read -r dex; do
    [ -z "$dex" ] && continue
    if ! unzip -p "$apk" "$dex" >"$DEX_FILE" 2>/dev/null; then
      echo "::error::$apk: no se puede extraer $dex"
      apk_status=1
      continue
    fi
    if LC_ALL=C grep -aE "$PATTERN_DEX" "$DEX_FILE" >/dev/null; then
      echo "::error::$apk: $dex lleva clases de JUnit/Hamcrest"
      apk_status=1
    fi
  done <<<"$dexes"
  if [ "$apk_status" -eq 0 ]; then
    echo "OK: $apk sin clases de pruebas (org/junit, org/hamcrest)"
  else
    status=1
  fi
done
exit "$status"
