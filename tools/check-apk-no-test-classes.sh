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

status=0
for apk in "$@"; do
  apk_status=0
  if [ ! -f "$apk" ]; then
    echo "::error::No existe el paquete: $apk" >&2
    status=1
    continue
  fi
  if unzip -Z1 "$apk" | grep -qE "$PATTERN_ENTRY"; then
    echo "::error::$apk lleva entradas de JUnit/Hamcrest (org/junit, org/hamcrest, junit/framework)"
    apk_status=1
  fi
  while IFS= read -r dex; do
    [ -z "$dex" ] && continue
    if unzip -p "$apk" "$dex" | LC_ALL=C grep -qaE "$PATTERN_DEX"; then
      echo "::error::$apk: $dex lleva clases de JUnit/Hamcrest"
      apk_status=1
    fi
  done < <(unzip -Z1 "$apk" | grep -E '^(base/dex/)?classes[0-9]*\.dex$' || true)
  if [ "$apk_status" -eq 0 ]; then
    echo "OK: $apk sin clases de pruebas (org/junit, org/hamcrest)"
  else
    status=1
  fi
done
exit "$status"
