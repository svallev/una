# Configuración de Claude Code del proyecto

Objetivo: que el desarrollo con Claude Code sea **consistente** (SDD, convenciones) y **seguro** (secretos, dependencias, skills), con el mínimo de permisos.

## Qué está instalado y qué falta por instalar

| Pieza | Ubicación | Estado |
|---|---|---|
| `CLAUDE.md` | raíz | ✅ Instalado |
| Skills del proyecto (8 + `find-skills` adaptada) | `.claude/skills/` | ✅ Instaladas |
| Subagentes (4) | `.claude/agents/` | ✅ Instalados |
| Permisos y hooks | `.claude/settings.json` + `.claude/hooks/*.sh` | ⏳ **Pendiente de que los instales tú** (ver §4). El modo automático de Claude Code, con buen criterio, no permite que Claude escriba su propia configuración de permisos y hooks. `.claude/hooks/block-sensitive-files.sh` ya existe, pero no hace nada hasta que `settings.json` lo referencie |
| MCP | — | Ninguno nuevo (ver §5) |

## 1. Skills del proyecto

| Skill | Para qué | Cuándo |
|---|---|---|
| `/spec-new` | Crear `specs/NNN-*/spec.md` desde la plantilla y pasarla por `spec-reviewer` | Funcionalidad nueva |
| `/spec-implement NNN` | Plan → tareas → tests → código → verificación de los CA → DoD | Implementar una spec aprobada |
| `/adr-new` | Nuevo ADR con matriz y consecuencias; actualiza el índice | Decisiones técnicas |
| `/security-check` | Checklist de seguridad sobre el diff + política de skills y MCP | Antes de cada PR |
| `/i18n-check` | Textos incrustados, claves ES/EN, plurales, glosario | Tras tocar UI |
| `/strings-add` | Añadir textos a las ARB ES/EN con descripción y placeholders | Cada texto nuevo |
| `/tokens-validate` | `tokens.json` válido, contraste AA, sin valores sueltos | Tras tocar tokens o UI |
| `/release-checklist` | Checklist de versión y tiendas (solo si la invocas tú) | Antes de publicar |
| `find-skills` (adaptada) | Buscar skills existentes **sin** instalar a nivel global ni sin confirmación; revisión obligatoria | Cuando preguntes por skills |

## 2. Subagentes

| Subagente | Herramientas | Papel |
|---|---|---|
| `spec-reviewer` | Solo lectura | Constitución, CA verificables, cobertura, textos ES/EN, coherencia |
| `security-reviewer` | Solo lectura | Amenazas T-x / MASVS sobre diffs, specs o planes |
| `a11y-reviewer` | Solo lectura | Gestos → acciones semánticas, foco, anuncios, contraste, texto grande |
| `test-writer` | Lectura, escritura, Bash | Tests desde los CA (unitarios, widgets, goldens, integración, migraciones) |

## 3. Skills, plugins y MCP de terceros: evaluación

Política (P11): **solo a nivel de proyecto, revisadas antes de instalar, nunca con `-g` ni `-y`**.

| Candidato | Evaluación | Decisión |
|---|---|---|
| `find-skills` (vercel-labs), ya presente en `.agents/skills/` | Indica `npx skills add … -g -y` (global y sin confirmación). Por lo demás, solo es texto | **Adaptada** en `.claude/skills/find-skills` (sin `-g`/`-y` y con revisión obligatoria). **[Pendiente]** Decidir si se borra la copia original de `.agents/skills/find-skills`: la usan otros agentes compatibles y un `npx skills update` podría restaurar el enlace. Recomendación: borrarla y quitarla de `skills-lock.json` |
| GitHub Spec Kit | CLI de Python con scripts de shell y comandos | No se instala (ADR-0003); se copian sus convenciones |
| Skills oficiales de Flutter/Dart o de Anthropic para Flutter | **[Pendiente]** Revisar en F2 si existen y qué ejecutan | Evaluar con `find-skills` en F2 |
| Plugin de Vercel | Ya lo tienes a nivel de usuario (no del proyecto) | No se añade al proyecto; útil para consultar despliegues |
| Context7 | Ya lo tienes a nivel de usuario | Suficiente para la documentación de librerías |

## 4. Permisos y hooks: **propuesta para instalar**

### 4.1 Cómo instalarlo (lo haces tú)

1. Revisa los tres bloques de abajo.
2. Crea `.claude/settings.json` con el contenido de §4.2.
3. Crea `.claude/hooks/guard-bash.sh` (§4.3) y `.claude/hooks/format-and-validate.sh` (§4.4). `block-sensitive-files.sh` ya está.
4. `chmod +x .claude/hooks/*.sh`
5. Reinicia la sesión de Claude Code y ejecuta `/hooks` en una terminal interactiva para comprobar que aparecen.
6. Prueba: pide a Claude "lee el archivo `.env`" → debe bloquearlo. Prueba también `npx skills add algo -g` → bloqueado.

### 4.2 `.claude/settings.json`

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git status *)", "Bash(git diff *)", "Bash(git log *)", "Bash(git show *)",
      "Bash(git add *)", "Bash(git commit *)", "Bash(git switch *)", "Bash(git branch *)",
      "Bash(git restore --staged *)",
      "Bash(fvm flutter analyze *)", "Bash(fvm flutter test *)", "Bash(fvm flutter pub get *)",
      "Bash(fvm flutter gen-l10n *)", "Bash(fvm dart format *)", "Bash(fvm dart run build_runner *)",
      "Bash(flutter analyze *)", "Bash(flutter test *)", "Bash(flutter pub get *)",
      "Bash(flutter gen-l10n *)", "Bash(dart format *)", "Bash(dart run build_runner *)",
      "Bash(node tools/validate-tokens.mjs)", "Bash(node ../tools/validate-tokens.mjs)"
    ],
    "ask": [
      "Bash(git push *)", "Bash(git reset --hard *)", "Bash(git rebase *)",
      "Bash(gh repo *)", "Bash(gh pr merge *)", "Bash(gh release *)", "Bash(gh secret *)", "Bash(gh api *)",
      "Bash(vercel *)", "Bash(npx *)", "Bash(npm install *)", "Bash(brew install *)",
      "Bash(fvm flutter pub add *)", "Bash(flutter pub add *)", "Bash(dart pub add *)",
      "Bash(claude plugin *)", "Bash(claude mcp *)", "Bash(rm -rf *)"
    ],
    "deny": [
      "Read(./.env)", "Read(./.env.*)", "Read(**/*.jks)", "Read(**/*.keystore)", "Read(**/key.properties)",
      "Read(**/*.p8)", "Read(**/*.p12)", "Read(**/*.pem)", "Read(**/*.mobileprovision)",
      "Read(**/google-services.json)", "Read(**/GoogleService-Info.plist)", "Read(./secrets/**)",
      "Edit(./.env)", "Edit(./.env.*)", "Edit(**/*.jks)", "Edit(**/*.keystore)", "Edit(**/key.properties)",
      "Edit(**/*.p8)", "Edit(**/*.p12)", "Edit(**/*.pem)", "Edit(**/*.mobileprovision)", "Edit(./secrets/**)"
    ]
  },
  "enableAllProjectMcpServers": false,
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|MultiEdit|NotebookEdit|Grep|Glob",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-sensitive-files.sh" }]
      },
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/guard-bash.sh", "timeout": 600 }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/format-and-validate.sh" }]
      }
    ]
  }
}
```

Por qué así:
- **allow:** solo operaciones locales, de lectura o reversibles (git sin push, análisis, tests, formateo, generación de código).
- **ask:** todo lo que publica, instala, borra en masa o toca configuración de Claude (push, `gh`, `vercel`, `npx`, añadir dependencias, plugins y MCP).
- **deny:** secretos y firma, como segunda barrera además del hook.
- `enableAllProjectMcpServers: false`: un `.mcp.json` que llegue en una PR no se activa solo.

### 4.3 `.claude/hooks/guard-bash.sh`

Bloquea los comandos que tocan secretos, las instalaciones de skills globales o sin confirmación, los plugins y MCP sin `--scope project`, y, antes de `git commit`, valida los tokens y ejecuta los tests si existe la app.

```bash
#!/usr/bin/env bash
set -uo pipefail
INPUT="$(cat)"
CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$CMD" ] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
block() { echo "Bloqueado por política del proyecto: $1" >&2; exit 2; }

# 1. Secretos y firma
if printf '%s' "$CMD" | grep -Eq '(^|[[:space:]/"'"'"'])\.env([[:space:]"'"'"']|$|\.[A-Za-z]+)|\.jks\b|\.keystore\b|key\.properties|\.p8\b|\.p12\b|\.mobileprovision|google-services\.json|GoogleService-Info\.plist|(^|[[:space:]/])secrets/'; then
  printf '%s' "$CMD" | grep -Eq '\.env\.example' || block "el comando hace referencia a secretos o archivos de firma."
fi

# 2. Skills, plugins y MCP: nunca globales ni sin confirmación (P11)
if printf '%s' "$CMD" | grep -Eq '(npx|bunx|pnpm dlx)[[:space:]]+(-y[[:space:]]+|--yes[[:space:]]+)?skills[[:space:]]+(add|install|update)'; then
  printf '%s' "$CMD" | grep -Eq '(^|[[:space:]])(-g|--global|-y|--yes)([[:space:]]|$)' && block "skills con -g/-y prohibidas (P11)."
fi
if printf '%s' "$CMD" | grep -Eq 'claude[[:space:]]+(plugin[[:space:]]+install|mcp[[:space:]]+add)'; then
  printf '%s' "$CMD" | grep -Eq '(--scope|-s)[[:space:]=]+project' || block "plugins/MCP solo con --scope project y tras revisarlos (P11)."
fi

# 3. Antes de commit: tokens y tests
if printf '%s' "$CMD" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
  if command -v node >/dev/null 2>&1 && [ -f "$ROOT/design/tokens.json" ]; then
    node "$ROOT/tools/validate-tokens.mjs" >/dev/null 2>&1 || block "design/tokens.json no es válido (node tools/validate-tokens.mjs)."
  fi
  if [ -f "$ROOT/app/pubspec.yaml" ]; then
    if command -v fvm >/dev/null 2>&1; then FL="fvm flutter"; elif command -v flutter >/dev/null 2>&1; then FL="flutter"; else FL=""; fi
    if [ -n "$FL" ]; then
      OUT="$(cd "$ROOT/app" && $FL test --reporter=compact 2>&1)" || { printf '%s\n' "$OUT" | tail -n 40 >&2; block "hay tests fallando."; }
    fi
  fi
fi
exit 0
```

### 4.4 `.claude/hooks/format-and-validate.sh`

```bash
#!/usr/bin/env bash
set -uo pipefail
INPUT="$(cat)"
FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$FILE" ] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
case "$FILE" in
  *.dart)
    if command -v fvm >/dev/null 2>&1 && [ -f "$ROOT/.fvmrc" ]; then (cd "$ROOT" && fvm dart format "$FILE" >/dev/null 2>&1) || true
    elif command -v dart >/dev/null 2>&1; then dart format "$FILE" >/dev/null 2>&1 || true; fi ;;
  */design/tokens.json)
    if command -v node >/dev/null 2>&1; then
      OUT="$(node "$ROOT/tools/validate-tokens.mjs" 2>&1)" || { printf '%s\n' "$OUT" >&2; exit 2; }
    fi ;;
esac
exit 0
```

Nota: los hooks usan `jq`, que viene con macOS 15 o posterior (`/usr/bin/jq`).

## 5. MCP

**Ninguno nuevo en el proyecto.**
- **GitHub:** basta con `gh` CLI (menos superficie que un servidor MCP con token). Se reconsidera si hace falta automatizar la revisión de PR.
- **Vercel:** el plugin que tienes a nivel de usuario basta para consultar despliegues; no se añade al proyecto.
- Si algún día se añade uno: `.mcp.json` en el repo, `--scope project`, revisión del código del servidor, token con el mínimo de permisos y activación manual (sin `enableAllProjectMcpServers`).
