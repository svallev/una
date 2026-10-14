#!/usr/bin/env bash
# La comprobación 0 del trabajo de publicación (spec 020, CA-020-02 punto 0, P-020-3 a): la CI y
# Security del commit que se entrega terminaron en verde.
#
#   tools/release/check-ci-runs.sh --repo <dueño/nombre> --sha <commit de 40 caracteres>
#
# Para cada uno de `.github/workflows/ci.yml` y `security.yml` pide a GitHub (`gh api`, con
# `GH_TOKEN` en el entorno del paso) las ejecuciones por la **ruta** del workflow (no por su nombre,
# que otro archivo podría copiar), del evento `push` a `main` y con el `head_sha` exacto, y se queda
# con la **última** (mayor `run_number`): tiene que estar `completed` y `success`. Cancelada,
# saltada, neutral, en curso, en cola o ausente es un fallo: nunca espera ni da por buena una CI que
# no ha visto. Residual (threat-model §5): el OSV-Scanner de Security es del momento de fusionar; una
# vulnerabilidad publicada después no para el modo estricto hasta la ejecución semanal.
# Falla cerrada: `gh` ausente o que falla, o una respuesta que no se entiende, es un fallo.
# Códigos: 0 bien, 1 fallo, 2 uso incorrecto. Necesita `gh` y `python3`; no instala nada.
set -euo pipefail

usage() {
  echo "Uso: $0 --repo <dueño/nombre> --sha <commit de 40 caracteres>" >&2
  exit 2
}

repo=""
sha=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) [ $# -ge 2 ] || usage; repo="$2"; shift 2 ;;
    --sha) [ $# -ge 2 ] || usage; sha="$2"; shift 2 ;;
    *) usage ;;
  esac
done
export LC_ALL=C
printf '%s' "$repo" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || { echo "::error::--repo no es dueño/nombre: usa --repo <dueño/nombre>" >&2; usage; }
printf '%s' "$sha" | grep -qE '^[0123456789abcdef]{40}$' || { echo "::error::--sha no es un commit de 40 caracteres hexadecimales en minúsculas" >&2; usage; }

command -v gh >/dev/null 2>&1 || { echo "::error::No hay gh en el PATH: no se puede comprobar la CI del commit"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "::error::No hay python3 en el PATH: no se puede leer la respuesta de GitHub"; exit 1; }

status=0
for wf in ci.yml security.yml; do
  if ! body="$(gh api -H 'Accept: application/vnd.github+json' \
      "repos/$repo/actions/workflows/$wf/runs?event=push&branch=main&head_sha=$sha&per_page=100" 2>&1)"; then
    echo "::error::$wf: no se pudieron leer las ejecuciones ($(printf '%s' "$body" | head -c 200 | tr -d '\n\r'))"
    status=1
    continue
  fi
  if ! msg="$(printf '%s' "$body" | python3 -I -c '
import json, sys
wf, sha = sys.argv[1], sys.argv[2]
path = ".github/workflows/" + wf
try:
    data = json.load(sys.stdin)
    runs = data["workflow_runs"]
    assert isinstance(runs, list)
except Exception:
    print("la respuesta de GitHub no se entiende")
    sys.exit(1)
mine = []
for r in runs:
    if not isinstance(r, dict):
        print("una ejecución de la respuesta no se entiende")
        sys.exit(1)
    if r.get("path") == path and r.get("event") == "push" and r.get("head_branch") == "main" and r.get("head_sha") == sha:
        n = r.get("run_number")
        if not isinstance(n, int) or isinstance(n, bool):
            print("una ejecución sin run_number")
            sys.exit(1)
        mine.append(r)
if not mine:
    print("ninguna ejecución de push a main sobre este commit: espera a que empiece la CI y vuelve a lanzar")
    sys.exit(1)
last = max(mine, key=lambda r: r["run_number"])
status, conclusion = last.get("status"), last.get("conclusion")
if status != "completed":
    print("la última ejecución (n.º %d) no ha terminado (%s): espera a que termine la CI de este commit y vuelve a lanzar" % (last["run_number"], status))
    sys.exit(1)
if conclusion != "success":
    print("la última ejecución (n.º %d) terminó en %s, no en success" % (last["run_number"], conclusion))
    sys.exit(1)
print("última ejecución n.º %d en verde" % last["run_number"])
' "$wf" "$sha")"; then
    echo "::error::$wf: $(printf '%s' "$msg" | tr -d '\r' | head -c 300)"
    status=1
    continue
  fi
  echo "OK $wf: $msg"
done
exit "$status"
