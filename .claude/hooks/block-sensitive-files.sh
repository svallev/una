#!/usr/bin/env bash
# PreToolUse (Read|Edit|Write|MultiEdit|NotebookEdit|Grep|Glob):
# bloquea el acceso a secretos y archivos de firma. Exit 2 = bloquear (stderr llega a Claude).
set -uo pipefail

INPUT="$(cat)"
TARGET="$(printf '%s' "$INPUT" | jq -r '[.tool_input.file_path, .tool_input.path, .tool_input.notebook_path, .tool_input.pattern, .tool_input.glob] | map(select(. != null and . != "")) | join("\n")' 2>/dev/null)"

[ -z "$TARGET" ] && exit 0

SENSITIVE='(^|/)\.env($|\.[^/]*$)|\.jks$|\.keystore$|(^|/)key\.properties$|\.p8$|\.p12$|\.pem$|\.key$|\.cer$|\.mobileprovision$|\.provisionprofile$|(^|/)google-services\.json$|(^|/)GoogleService-Info\.plist$|(^|/)secrets(/|$)|service-account[^/]*\.json$'
ALLOWED='(^|/)\.env\.example$'

while IFS= read -r t; do
  if printf '%s' "$t" | grep -Eq "$SENSITIVE" && ! printf '%s' "$t" | grep -Eq "$ALLOWED"; then
    echo "Bloqueado por política del proyecto: '$t' es un archivo sensible (secretos o firma). Ver CLAUDE.md → Qué NO hacer. Si de verdad hace falta, pídeselo al propietario para que lo haga él." >&2
    exit 2
  fi
done <<< "$TARGET"

exit 0
