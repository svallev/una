#!/bin/bash
# SessionStart (solo en sesiones en la nube): deja listo Flutter para analizar y probar la app.
# - Instala el SDK que fija .fvmrc en /opt/flutter-<versión> si falta o está incompleto.
#   Se descarga del bucket oficial y se comprueba su SHA-256 contra releases_linux.json.
# - Lo pone en el PATH de la sesión y marca el SDK como directorio seguro de git
#   (el SDK pertenece a otro usuario y la sesión corre como root).
# - Ejecuta `flutter pub get` en app/ (la caché del contenedor lo hace barato).
# Idempotente y sin interacción. Sin red de la app: solo toca el entorno de desarrollo.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flutter"])' "$ROOT/.fvmrc")"
SDK="/opt/flutter-$VERSION"
ARCHIVE_DIR="/opt/sdk-dl"

sdk_ok() {
  [ -x "$SDK/bin/flutter" ] && [ -x "$SDK/bin/cache/dart-sdk/bin/dart" ]
}

install_sdk() {
  echo "Instalando Flutter $VERSION en $SDK…" >&2
  mkdir -p "$ARCHIVE_DIR"
  local file="flutter_linux_${VERSION}-stable.tar.xz"
  local manifest="$ARCHIVE_DIR/releases_linux.json"
  curl -fsS -o "$manifest" https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
  local info archive sha
  info="$(python3 - "$manifest" "$VERSION" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for r in data["releases"]:
    if r["version"] == sys.argv[2] and r["channel"] == "stable":
        print(r["archive"], r["sha256"])
        break
PY
)"
  [ -n "$info" ] || { echo "Flutter $VERSION no figura en releases_linux.json" >&2; exit 1; }
  archive="${info%% *}"
  sha="${info##* }"
  if ! echo "$sha  $ARCHIVE_DIR/$file" | sha256sum -c --status 2>/dev/null; then
    curl -fsS -o "$ARCHIVE_DIR/$file" "https://storage.googleapis.com/flutter_infra_release/releases/$archive"
    echo "$sha  $ARCHIVE_DIR/$file" | sha256sum -c --status
  fi
  rm -rf "$SDK" "$SDK.tmp"
  mkdir -p "$SDK.tmp"
  tar -xf "$ARCHIVE_DIR/$file" -C "$SDK.tmp"
  mv "$SDK.tmp/flutter" "$SDK"
  rmdir "$SDK.tmp"
}

if ! sdk_ok; then
  install_sdk
fi

git config --global --add safe.directory "$SDK" 2>/dev/null || true
export PATH="$SDK/bin:$PATH"
export CI=true

# Descarga los artefactos de Dart/Flutter la primera vez y comprueba que el SDK funciona.
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version >&2
(cd "$ROOT/app" && flutter pub get >&2)

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$SDK/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi
