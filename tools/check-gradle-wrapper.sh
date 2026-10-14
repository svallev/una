#!/usr/bin/env bash
# Falla si el wrapper de Gradle no está verificado (spec 020, CA-020-14; threat-model §5):
#   1. app/android/gradle/wrapper/gradle-wrapper.properties lleva `distributionSha256Sum` (una sola
#      línea, 64 hex en minúsculas) y es la que fija tools/gradle-wrapper.lock para el archivo del
#      `distributionUrl` (que tiene que ser de https://services.gradle.org/distributions/). Gradle
#      comprueba esa suma al descargar la distribución; aquí se exige que exista y que sea la fijada,
#      también cuando una actualización de Flutter reescribe el archivo y la suma desaparece (CL-020-18).
#   2. El gradle-wrapper.jar que se ejecuta es uno de los que publica Gradle (sumas del lock). El jar
#      no está en el repositorio: lo copia Flutter de su caché al compilar, así que esto corre
#      DESPUÉS de `flutter build` y detecta un jar alterado; no impide que se haya ejecutado (P-020-2).
#
#   tools/check-gradle-wrapper.sh                       (tras compilar; desde cualquier carpeta)
#   tools/check-gradle-wrapper.sh [--properties <archivo>] [--jar <archivo>] [--lock <archivo>]
#       (otros archivos: pruebas)
#
# Falla cerrada: una forma de escribir la clave que Gradle aceptaría pero que aquí no se lee
# (espacios, `:`, dos líneas) es un fallo, no un permiso. Códigos: 0 bien, 1 fallo, 2 uso.
set -euo pipefail
# Los rangos de [a-f] dependen del idioma (en algunos aceptan mayúsculas): intercalación de bytes.
export LC_ALL=C

HERE="$(cd "$(dirname "$0")" && pwd)"
PROPS="$HERE/../app/android/gradle/wrapper/gradle-wrapper.properties"
JAR="$HERE/../app/android/gradle/wrapper/gradle-wrapper.jar"
LOCK="$HERE/gradle-wrapper.lock"

usage() { echo "Uso: $0 [--properties <archivo>] [--jar <archivo>] [--lock <archivo>]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --properties|--jar|--lock)
      [ $# -ge 2 ] || usage
      case "$1" in
        --properties) PROPS="$2" ;;
        --jar) JAR="$2" ;;
        --lock) LOCK="$2" ;;
      esac
      shift ;;
    *) usage ;;
  esac
  shift
done

status=0
fail() { echo "::error::$*"; status=1; }
sha256() { if command -v sha256sum >/dev/null; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }
HEX='^[0123456789abcdef]{64}$'

# ─── El lock ──────────────────────────────────────────────────────────────────
dist_files=()   # archivos de distribución del lock
dist_sums=()    # su suma, en el mismo orden
jar_sums=()
if [ ! -f "$LOCK" ] || [ ! -r "$LOCK" ]; then
  fail "No se puede leer tools/gradle-wrapper.lock ($LOCK): sin él no hay con qué comparar"
else
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    read -r kw a b rest <<< "$line"
    if [ -n "${rest:-}" ] || [[ ! "${b:-}" =~ $HEX ]]; then
      fail "tools/gradle-wrapper.lock línea $n mal formada (se espera «distribution|wrapper-jar <nombre> <sha256 en minúsculas>»)"
      continue
    fi
    case "$kw" in
      distribution)
        i=0
        for f in ${dist_files[@]+"${dist_files[@]}"}; do
          if [ "$f" = "$a" ] && [ "${dist_sums[$i]}" != "$b" ]; then
            fail "tools/gradle-wrapper.lock tiene dos sumas distintas para $a"
          fi
          i=$((i + 1))
        done
        dist_files+=("$a"); dist_sums+=("$b") ;;
      wrapper-jar) jar_sums+=("$b") ;;
      *) fail "tools/gradle-wrapper.lock línea $n mal formada (se espera «distribution|wrapper-jar <nombre> <sha256 en minúsculas>»)" ;;
    esac
  done < "$LOCK"
  [ "${#dist_files[@]}" -gt 0 ] || fail "tools/gradle-wrapper.lock no tiene ninguna línea «distribution»"
  [ "${#jar_sums[@]}" -gt 0 ] || fail "tools/gradle-wrapper.lock no tiene ninguna línea «wrapper-jar»"
fi

# ─── gradle-wrapper.properties ────────────────────────────────────────────────
if [ ! -f "$PROPS" ] || [ ! -r "$PROPS" ]; then
  fail "No se puede leer gradle-wrapper.properties ($PROPS)"
else
  sum_lines=()
  url_lines=()
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*distributionSha256Sum ]] && sum_lines+=("$line")
    [[ "$line" =~ ^[[:space:]]*distributionUrl ]] && url_lines+=("$line")
  done < "$PROPS"

  # distributionUrl: una sola línea, de services.gradle.org por https.
  dist_file=""
  url_re='^distributionUrl=https[\\]?://services\.gradle\.org/distributions/([A-Za-z0-9._-]+)$'
  if [ "${#url_lines[@]}" -ne 1 ]; then
    fail "gradle-wrapper.properties necesita exactamente un distributionUrl (tiene ${#url_lines[@]})"
  elif [[ "${url_lines[0]}" =~ $url_re ]]; then
    dist_file="${BASH_REMATCH[1]}"
  else
    fail "distributionUrl de gradle-wrapper.properties no es https://services.gradle.org/distributions/<archivo>"
  fi

  # distributionSha256Sum: una sola línea, bien formada.
  prop_sum=""
  sum_re="^distributionSha256Sum=([0123456789abcdef]{64})\$"
  if [ "${#sum_lines[@]}" -eq 0 ]; then
    fail "Falta distributionSha256Sum en gradle-wrapper.properties (¿una actualización de Flutter reescribió el archivo? Vuelve a poner la suma de tools/gradle-wrapper.lock)"
  elif [ "${#sum_lines[@]}" -gt 1 ]; then
    fail "distributionSha256Sum aparece ${#sum_lines[@]} veces en gradle-wrapper.properties (tiene que haber una sola línea)"
  elif [[ "${sum_lines[0]}" =~ $sum_re ]]; then
    prop_sum="${BASH_REMATCH[1]}"
  else
    fail "distributionSha256Sum de gradle-wrapper.properties mal formada (se espera «distributionSha256Sum=<64 hex en minúsculas>», sin espacios)"
  fi

  # La suma tiene que ser la que el lock fija para ese archivo.
  if [ -n "$dist_file" ] && [ -n "$prop_sum" ] && [ "${#dist_files[@]}" -gt 0 ]; then
    expected=""
    i=0
    for f in "${dist_files[@]}"; do
      [ "$f" = "$dist_file" ] && expected="${dist_sums[$i]}"
      i=$((i + 1))
    done
    if [ -z "$expected" ]; then
      fail "$dist_file no está en tools/gradle-wrapper.lock: añade la suma que publica Gradle (https://gradle.org/release-checksums/) al subir de versión"
    elif [ "$expected" != "$prop_sum" ]; then
      fail "distributionSha256Sum no coincide con tools/gradle-wrapper.lock para $dist_file"
    else
      echo "OK distributionSha256Sum $dist_file"
    fi
  fi
fi

# ─── gradle-wrapper.jar ───────────────────────────────────────────────────────
if [ ! -f "$JAR" ]; then
  fail "No existe el gradle-wrapper.jar ($JAR). Lo genera Flutter al compilar: flutter build apk --debug (desde app/) antes de esta comprobación"
elif [ "${#jar_sums[@]}" -gt 0 ]; then
  actual="$(sha256 < "$JAR")"
  found=false
  for s in "${jar_sums[@]}"; do [ "$s" = "$actual" ] && found=true; done
  if $found; then
    echo "OK gradle-wrapper.jar $actual"
  else
    fail "gradle-wrapper.jar tiene la suma $actual, que no está entre las que fija tools/gradle-wrapper.lock (¿alterado, o Flutter ha cambiado de jar? Contrasta con https://gradle.org/release-checksums/)"
  fi
fi

exit "$status"
