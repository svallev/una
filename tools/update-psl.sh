#!/usr/bin/env bash
# Public Suffix List empaquetada (spec 009, CA-009-11: "mismo sitio" = mismo dominio
# registrable). La lista es de Mozilla (MPL-2.0) y va sin modificar como asset en
# app/assets/psl/public_suffix_list.dat; tools/psl.lock fija su versión y su sha256.
#
#   tools/update-psl.sh           descarga la lista oficial (publicsuffix.org, la única URL
#                                 que admiten), la copia al asset y reescribe tools/psl.lock
#   tools/update-psl.sh --check   sin red (CI): falla si el asset no coincide con el lock
#
# Al actualizar: revisar el diff del asset en la PR y pasar test/domain/public_suffix_test.dart.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSET="$ROOT/app/assets/psl/public_suffix_list.dat"
LOCK="$ROOT/tools/psl.lock"
URL="https://publicsuffix.org/list/public_suffix_list.dat"

sha256() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
header() { sed -n "s|^// $1: *||p" "$2" | head -n1; }
lock_value() { awk -v k="$1" '$1 == k { print $2 }' "$LOCK"; }

if [ "${1:-}" = "--check" ]; then
  [ -f "$ASSET" ] || { echo "::error::No existe $ASSET"; exit 1; }
  expected="$(lock_value sha256)"
  [ -n "$expected" ] || { echo "::error::tools/psl.lock no tiene sha256"; exit 1; }
  actual="$(sha256 "$ASSET")"
  if [ "$actual" != "$expected" ]; then
    echo "::error::El asset de la PSL no coincide con tools/psl.lock ($actual). Actualízala con tools/update-psl.sh"
    exit 1
  fi
  version="$(header VERSION "$ASSET")"
  if [ "$version" != "$(lock_value version)" ]; then
    echo "::error::La versión del asset ($version) no es la de tools/psl.lock"
    exit 1
  fi
  echo "OK PSL $version $actual"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl --proto '=https' --tlsv1.2 -fsSL "$URL" -o "$tmp"

# Comprobaciones mínimas de que es la lista y no una página de error.
grep -q '^// ===BEGIN ICANN DOMAINS===' "$tmp" || { echo "No parece la PSL (sin ICANN)"; exit 1; }
grep -q '^// ===END PRIVATE DOMAINS===' "$tmp" || { echo "No parece la PSL (sin PRIVATE)"; exit 1; }
grep -q 'Mozilla Public' "$tmp" || { echo "Sin el aviso de licencia MPL-2.0"; exit 1; }
version="$(header VERSION "$tmp")"
commit="$(header COMMIT "$tmp")"
[ -n "$version" ] && [ -n "$commit" ] || { echo "Sin VERSION o COMMIT en la cabecera"; exit 1; }

mkdir -p "$(dirname "$ASSET")"
cp "$tmp" "$ASSET"
cat > "$LOCK" <<EOF
# Public Suffix List empaquetada (spec 009, CA-009-11). Generado por tools/update-psl.sh:
# no se edita a mano. CI comprueba que app/assets/psl/public_suffix_list.dat es exactamente
# esta (tools/update-psl.sh --check). Origen: $URL (MPL-2.0).
# Descargada el $(date -u +%Y-%m-%d).
version $version
commit $commit
sha256 $(sha256 "$ASSET")
EOF
echo "PSL $version ($commit) → $ASSET"
