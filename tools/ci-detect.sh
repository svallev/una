#!/usr/bin/env bash
# Qué hay que correr en la CI (spec 023, CA-023-18; antes la lógica estaba dentro de `ci.yml`):
# a partir de los archivos que cambia una PR decide dos cosas y las escribe en la salida estándar,
# una por línea, listas para añadir a `$GITHUB_OUTPUT`:
#
#   build=true|false   ¿hay que compilar y probar la app (trabajos flutter, android e ios)?
#   store=true|false   ¿hay que comprobar la ficha de tienda («Ficha»)? (La web vive en su propio
#                      repositorio, svallev/una-web, con su CI; ADR-0029.)
#
#   git diff --name-only -z HEAD^1 HEAD | tools/ci-detect.sh --event pull_request
#
# La lista llega por la entrada estándar, separada por NUL (`git diff -z`: un nombre con espacios o con
# saltos de línea no se parte). Se usa un trabajo y no `paths:` en `on:` porque un trabajo saltado
# cuenta como superado para las comprobaciones obligatorias; un workflow que no arranca las deja
# pendientes (docs/testing.md).
#
# Falla cerrada: fuera de una PR (main, a mano) todo es `true`; una lista vacía en una PR también (si
# `git diff` no dijo nada, no se sabe que no cambie nada); un argumento que no entiende es el código 2,
# sin escribir ningún resultado. Códigos: 0 bien, 1 fallo, 2 uso incorrecto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
  echo "uso: tools/ci-detect.sh --event <pull_request|push|…>  (archivos separados por NUL en la entrada)" >&2
  exit 2
}

[ $# -eq 2 ] && [ "$1" = "--event" ] && [ -n "$2" ] || usage
event="$2"

# ¿Compila esta ruta la app? Documentación y especificaciones, no; la ficha, tampoco, salvo lo que leen
# los tests de `app/test`: si un test nuevo lee otro archivo de `docs/`, `specs/` o `store/`, hay que
# añadirlo aquí. Cualquier otra ruta con carpeta (o un archivo de la raíz que no es
# `.md`) compila.
is_build() {
  case "$1" in
    # Los que leen los tests de la app: glosario, modelo de amenazas, política de privacidad.
    docs/glossary.md|docs/security/threat-model.md|docs/legal/privacy-policy.md) return 0 ;;
    docs/*|specs/*) return 1 ;;
    # El test de Data Safety lee `data-safety.md`; los de iconos, `icon-512.png`; el *golden* del
    # gráfico, `feature-graphic.png`.
    store/google-play/data-safety.md|store/google-play/icon-512.png|store/google-play/feature-graphic.png) return 0 ;;
    store/*) return 1 ;;
    */*) return 0 ;;
    *.md) return 1 ;;
    *) return 0 ;;
  esac
}

# ¿Comprueba esta ruta la ficha? Lo suyo (`store/google-play/` salvo el icono, que no entra en la ficha
# que se comprueba) y lo que lee `store/google-play/check.mjs`.
is_store() {
  case "$1" in
    store/google-play/icon-512.png) return 1 ;;
    store/google-play/*) return 0 ;;
    docs/legal/privacy-policy.md|app/identity.yaml) return 0 ;;
    tools/check-android-permissions.sh|tools/ci-detect.sh) return 0 ;;
    .github/workflows/ci.yml) return 0 ;;
    *) return 1 ;;
  esac
}

build=false
store=false
has_app=false
[ -f "$ROOT/app/pubspec.yaml" ] && has_app=true

if [ "$event" != "pull_request" ]; then
  # En main (y a mano) se construye todo lo que existe.
  build=$has_app
  store=true
else
  seen=0
  while IFS= read -r -d '' f || [ -n "$f" ]; do
    [ -n "$f" ] || continue
    seen=$((seen + 1))
    if is_build "$f"; then build=true; fi
    if is_store "$f"; then store=true; fi
  done
  if [ "$seen" -eq 0 ]; then
    # Una PR sin archivos no existe: si la lista llega vacía, algo falló al pedirla.
    build=true
    store=true
  fi
  # Sin la app no hay nada que compilar (como antes); la ficha sí se decide.
  if [ "$has_app" != true ]; then build=false; fi
fi

echo "build=$build"
echo "store=$store"
