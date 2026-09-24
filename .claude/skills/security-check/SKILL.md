---
name: security-check
description: Pasa la checklist de seguridad del proyecto (docs/security/checklist.md) sobre los cambios actuales (diff contra main) y verifica la política de skills, plugins y MCP. Úsala antes de cada PR y al cerrar una spec.
---

# Comprobación de seguridad

1. Obtén el alcance: `git diff --stat main...HEAD` y `git diff main...HEAD` (más los archivos sin seguimiento relevantes).
2. Clasifica los archivos tocados por superficie (`docs/security/threat-model.md` §3): importación (T-3), WebView/URL (T-4/5/6), almacenamiento (T-1/7), nativo (T-8), dependencias (T-10), CI (T-11), firma (T-12), permisos y privacidad (T-13), Claude Code (`.claude/**`, `CLAUDE.md`, `skills-lock.json`).
3. Recorre **"Siempre"** y las secciones de `docs/security/checklist.md` que apliquen. Para cada punto: ✅ cumplido (con evidencia: archivo o test), ❌ incumplido (con la corrección) o N/A.
4. Comprobaciones automáticas rápidas:
   - Posibles secretos: `git diff main...HEAD | grep -nE '(api[_-]?key|secret|token|password|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY)'`.
   - Archivos sensibles en el índice: `git ls-files | grep -E '\.(jks|keystore|p8|p12|pem|mobileprovision)$|key\.properties|\.env$'` (debe estar vacío).
   - Permisos nuevos: diff de `AndroidManifest.xml`, `Info.plist` y `PrivacyInfo.xcprivacy`.
   - Dependencias nuevas: diff de `pubspec.yaml`/`pubspec.lock` → aplica `threat-model.md §5`.
   - Skills/plugins/MCP: diff de `.claude/`, `.mcp.json` y `skills-lock.json` → nada global ni con `-y`; el contenido de terceros, leído y resumido.
5. Si hay superficies T-3 a T-6 o T-10 a T-13, lanza también el subagente `security-reviewer`.
6. Resultado: tabla de puntos + lista de acciones. No marques nada como cumplido sin evidencia.
