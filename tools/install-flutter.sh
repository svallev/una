#!/usr/bin/env bash
# Instala el SDK de Flutter en la versión fijada en .fvmrc (raíz del repo).
# Lo usan CI (GitHub Actions) y Vercel (ADR-0010). Sin acciones ni scripts de terceros.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FVMRC="$ROOT/.fvmrc"
DEST="${FLUTTER_HOME:-$HOME/flutter}"

if [ ! -f "$FVMRC" ]; then
  echo "No existe .fvmrc: la versión de Flutter se fija en F2 (ver docs/PLAN.md)." >&2
  exit 1
fi

VERSION="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FVMRC" | head -n1)"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Versión de Flutter no válida en .fvmrc: '$VERSION' (se exige X.Y.Z del canal estable)." >&2
  exit 1
fi

LOCK="$ROOT/tools/flutter-sdk.lock"
EXPECTED="$(awk -v v="$VERSION" '$1 == v {print $2}' "$LOCK")"
if [ -z "$EXPECTED" ]; then
  echo "Falta el commit de Flutter $VERSION en tools/flutter-sdk.lock." >&2
  exit 1
fi

if [ -x "$DEST/bin/flutter" ] && [ "$(git -C "$DEST" describe --tags 2>/dev/null || true)" = "$VERSION" ]; then
  echo "Flutter $VERSION ya instalado en $DEST"
else
  rm -rf "$DEST"
  git clone --depth 1 --branch "$VERSION" https://github.com/flutter/flutter.git "$DEST"
fi

ACTUAL="$(git -C "$DEST" rev-parse HEAD)"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "::error::La etiqueta $VERSION de Flutter apunta a $ACTUAL; se esperaba $EXPECTED (tools/flutter-sdk.lock)." >&2
  exit 1
fi
echo "Flutter $VERSION @ $ACTUAL (verificado)"
"$DEST/bin/flutter" config --no-analytics >/dev/null
"$DEST/bin/dart" --disable-analytics >/dev/null 2>&1 || true
"$DEST/bin/flutter" --version
