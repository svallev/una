#!/usr/bin/env bash
# La etiqueta del trabajo de publicación (spec 020, CA-020-03 c y d, CA-020-05 e; CL-020-1, 2, 3, 17
# y 19; plan §3.2, id `tag`).
#
#   tools/release/check-tag.sh --early --mode strict|testers --ref <refs/…>
#       «Rojo al empezar», antes de compilar: en `strict` la referencia tiene que ser una etiqueta
#       `refs/tags/vX.Y.Z` (tres números) y en `testers`, `refs/heads/main` (las entregas a testers
#       salen de main, CL-020-3). No necesita repositorio ni escribe JSON.
#   tools/release/check-tag.sh --mode strict|testers --ref <refs/…> --json <archivo>
#                              [--repo <carpeta>] [--main-ref <refs/…>]
#       La comprobación completa. En `strict`: la forma de la etiqueta (c), que coincida con la
#       `version:` de `app/pubspec.yaml` de **esa** etiqueta (sin el `+build`) (c), que su commit sea
#       antecesor de `origin/main` (d), que el commit comprobado (HEAD) sea el de la etiqueta (CL-020-19)
#       y que el `+build` (el versionCode) supere al de la etiqueta `vX.Y.Z` más alta de las demás
#       (CL-020-17: Play lo rechazaría; las etiquetas que no casan con `^vX.Y.Z$` y la propia no
#       cuentan). En `testers`: que la referencia sea `refs/heads/main` (si no, fallo) y, como aviso
#       de identidad (CA-020-05 e), que no hay etiqueta.
#
# Con `--json` escribe `{version, complete, checks, issues: [{kind, subject, message}]}` de forma
# atómica y al final; `kind` es `missing` (el aviso de testers) o `fault` (todo lo demás). Nunca hay
# un aviso y un fallo a la vez (CL-020-20): en `testers`, una referencia que no es main es solo un fallo. Lo que viene de la etiqueta se sanea antes de mostrarlo (nada
# fuera de `A-Za-z0-9._/+~-`), así que un nombre raro no rompe el JSON ni abre una orden `::`.
# Sale con 0 sin hallazgos, 1 con alguno y 2 con un uso incorrecto. Falla cerrada: lo que no se puede
# leer (repositorio, etiqueta, `main`, pubspec de una etiqueta anterior) es un fallo.
# Necesita `git` y `bash`; no instala nada ni usa la red.
set -uo pipefail
export LC_ALL=C

usage() {
  echo "Uso: $0 --early --mode strict|testers --ref <refs/…>" >&2
  echo "     $0 --mode strict|testers --ref <refs/…> --json <archivo> [--repo <carpeta>] [--main-ref <refs/…>]" >&2
  exit 2
}

mode=""
ref=""
ref_given=0
json=""
repo="."
main_ref="refs/remotes/origin/main"
early=0
while [ $# -gt 0 ]; do
  case "$1" in
    --early) early=1; shift ;;
    --mode) [ $# -ge 2 ] || usage; mode="$2"; shift 2 ;;
    --ref) [ $# -ge 2 ] || usage; ref="$2"; ref_given=1; shift 2 ;;
    --json) [ $# -ge 2 ] || usage; json="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
    --main-ref) [ $# -ge 2 ] || usage; main_ref="$2"; shift 2 ;;
    *) usage ;;
  esac
done
case "$mode" in strict | testers) ;; *) usage ;; esac
[ "$ref_given" -eq 1 ] || usage
if [ "$early" -eq 0 ] && [ -z "$json" ]; then usage; fi

# Solo A-Za-z0-9._/+~- y como mucho 120 caracteres: lo demás se cambia por «?».
safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._/+~-' '?' | head -c 120; }

TAG_REF_RE='^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$'
TAG_NAME_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'

early_msg() {
  echo "::error::$1"
  exit 1
}

if [ "$early" -eq 1 ]; then
  if [ "$mode" = "strict" ]; then
    [[ "$ref" =~ $TAG_REF_RE ]] || early_msg "La referencia «$(safe "$ref")» no es una etiqueta vX.Y.Z (tres números): el modo estricto se lanza con una etiqueta así (CA-020-03 c)."
  else
    [ "$ref" = "refs/heads/main" ] || early_msg "La referencia «$(safe "$ref")» no es refs/heads/main: las entregas a testers se lanzan desde main (CL-020-3)."
  fi
  echo "OK referencia $(safe "$ref") válida para el modo $mode"
  exit 0
fi

kinds=()
messages=()
add_issue() {
  kinds+=("$1")
  messages+=("$2")
}

g() { git -C "$repo" "$@"; }

# La `version:` de app/pubspec.yaml en la etiqueta $1; deja X.Y.Z en $ver y el +build en $build.
read_pubspec() {
  ver=""
  build=""
  local text line
  text="$(g show "refs/tags/$1:app/pubspec.yaml" 2>/dev/null)" || return 1
  line="$(printf '%s\n' "$text" | grep -E '^version:' | head -n1)" || return 1
  local re='^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*(#.*)?$'
  [[ "$line" =~ $re ]] || return 2
  ver="${BASH_REMATCH[1]}"
  build="${BASH_REMATCH[2]}"
}

check_strict() {
  if ! [[ "$ref" =~ $TAG_REF_RE ]]; then
    add_issue fault "la referencia «$(safe "$ref")» no es una etiqueta vX.Y.Z (tres números)"
    return
  fi
  local tag="${ref#refs/tags/}" stag
  stag="$(safe "$tag")"
  local tag_commit head
  if ! tag_commit="$(g rev-parse --verify -q --end-of-options "refs/tags/$tag^{commit}" 2>/dev/null)"; then
    add_issue fault "no se puede leer la etiqueta $stag (¿no hay repositorio de git o la etiqueta no existe?)"
    return
  fi
  head="$(g rev-parse --verify -q HEAD 2>/dev/null)" || head=""
  if [ "$head" != "$tag_commit" ]; then
    add_issue fault "el commit comprobado no es el de la etiqueta $stag: se vuelve a comprobar desde cero sobre el commit nuevo (CL-020-19)"
  fi

  # (c) la versión del pubspec.yaml de esa etiqueta.
  local ver build rc=0 cur_build=""
  read_pubspec "$tag" || rc=$?
  if [ "$rc" -ne 0 ]; then
    add_issue fault "app/pubspec.yaml de $stag no tiene una version: X.Y.Z+build legible"
  else
    cur_build="$build"
    if [ "v$ver" != "$tag" ]; then
      add_issue fault "la etiqueta $stag no coincide con la version de app/pubspec.yaml ($(safe "$ver")+$(safe "$build")): tiene que ser v$(safe "$ver")"
    fi
  fi

  # (d) el commit está en la historia de main.
  if ! g rev-parse --verify -q --end-of-options "$main_ref^{commit}" >/dev/null 2>&1; then
    add_issue fault "no se puede comprobar que el commit esté en main: no existe $(safe "$main_ref")"
  else
    g merge-base --is-ancestor "$tag_commit" "$main_ref" >/dev/null 2>&1
    case $? in
      0) ;;
      1) add_issue fault "el commit de la etiqueta $stag no está en la historia de main (CA-020-03 d, CL-020-2)" ;;
      *) add_issue fault "no se pudo comprobar si el commit de la etiqueta $stag está en main" ;;
    esac
  fi

  # CL-020-17: el versionCode supera al de la etiqueta anterior más alta (solo vX.Y.Z, sin la propia).
  if [ -n "$cur_build" ]; then
    local names prev
    names="$(g for-each-ref --format='%(refname:strip=2)' refs/tags/ 2>/dev/null)" || names=""
    prev="$(printf '%s\n' "$names" | grep -E "$TAG_NAME_RE" | grep -vxF "$tag" \
      | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n1)"
    if [ -n "$prev" ]; then
      rc=0
      read_pubspec "v$prev" || rc=$?
      if [ "$rc" -ne 0 ]; then
        add_issue fault "no se puede leer el versionCode de la etiqueta anterior v$(safe "$prev") (app/pubspec.yaml sin version X.Y.Z+build)"
      elif [ "$cur_build" -le "$build" ]; then
        add_issue fault "el versionCode $cur_build (el +build de app/pubspec.yaml) no supera al de la etiqueta anterior más alta v$(safe "$prev") ($build): Google Play lo rechazaría (CL-020-17)"
      fi
    fi
  fi
}

check_testers() {
  if [ "$ref" != "refs/heads/main" ]; then
    add_issue fault "la referencia «$(safe "$ref")» no es refs/heads/main: las entregas a testers se lanzan desde main (CL-020-3)"
    return
  fi
  add_issue missing "no hay etiqueta: es una entrega a testers (modo testers), no una publicación (CA-020-05 e)"
}

if [ "$mode" = "strict" ]; then check_strict; else check_testers; fi

# El JSON, atómico y al final, con `complete: true`. Los mensajes no llevan comillas ni barras.
{
  printf '{\n  "version": 1,\n  "complete": true,\n  "checks": ["tag"],\n  "issues": ['
  sep=""
  for i in ${kinds[@]+"${!kinds[@]}"}; do
    printf '%s\n    {"kind": "%s", "subject": "tag", "message": "%s"}' "$sep" "${kinds[$i]}" "${messages[$i]}"
    sep=","
  done
  [ -z "$sep" ] || printf '\n  '
  printf ']\n}\n'
} > "$json.tmp" 2>/dev/null && mv "$json.tmp" "$json" || {
  echo "::error::no se puede escribir $(safe "$json")"
  exit 1
}

if [ "${#kinds[@]}" -eq 0 ]; then
  echo "OK etiqueta $(safe "${ref#refs/tags/}"): forma, versión, main y versionCode"
  exit 0
fi
for i in "${!kinds[@]}"; do
  echo "::error::tag: ${messages[$i]}"
done
exit 1
