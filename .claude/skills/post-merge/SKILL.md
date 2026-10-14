---
name: post-merge
description: Tras fusionar una PR en GitHub, pone main al día, borra la rama local y libera espacio (compilaciones, cachés de los spikes y, con permiso, lo obsoleto fuera del repositorio). Úsala cuando el propietario diga que ha fusionado una PR o lo pida.
argument-hint: "[nº de PR]"
---

# Después de fusionar una PR

Decisión del propietario (2026-10-14): tras **cada** PR fusionada se limpia todo lo posible. Liberar espacio pesa más que el tiempo de la siguiente compilación.

## 1. Comprobar que está fusionada (si algo falla, para)

- `gh pr view <nº> --json state,headRefName,mergeCommit`. Sin número: la PR de la rama actual. Tiene que dar `MERGED`; si no, para y avisa.
- `git status --short` vacío. Si hay cambios sin commit, **para y pregunta**: no se cambia de rama con trabajo a medias.

## 2. Ramas

- `git checkout main && git pull --ff-only && git fetch --prune`.
- Borra la rama local con `git branch -D <rama>` **solo si** `git diff --quiet <rama> main` (con squash, git no la ve fusionada, así que se compara el contenido). Si difiere, enseña `git log main..<rama>` y pregunta.
- Si la rama remota sigue existiendo (`git ls-remote --heads origin <rama>`), pregunta antes de borrarla.
- Otras ramas locales cuya PR ya esté fusionada: lístalas y pregunta.

## 3. Espacio dentro del repositorio (sin preguntar)

- `tools/clean-workspace.sh` (simulación) y, si la lista es la esperada, `tools/clean-workspace.sh --apply`.
- Borra `app/build`, `app/.dart_tool`, los `.gradle`/`.kotlin`/`.cxx` de Android, `coverage`, lo compilado de los spikes y los `.DS_Store`. Conserva `app/build/mastg-NNN` mientras la spec NNN no esté **Implementada**.
- Nunca borra a mano lo que el script no lista. Algo nuevo que ocupe mucho y sea regenerable se añade **al script** (con su test en `app/test/tool/clean_workspace_test.dart`), no a esta sesión.
- Después, `cd app && flutter pub get`, para que el análisis y el IDE sigan funcionando. La siguiente compilación tardará unos minutos más (recompila PDFium).

## 4. Fuera del repositorio (solo con el sí del propietario, cada vez)

- `tools/clean-workspace.sh --global`: informa y propone borrar solo lo obsoleto, es decir, las versiones de Gradle que ya no usa el *wrapper* (en `~/.gradle/caches/<versión>` y `~/.gradle/wrapper/dists`) y las imágenes de sistema que no usa ningún emulador.
- Enseña la lista con los tamaños y pregunta. Solo con un «sí» explícito: `tools/clean-workspace.sh --global --apply`.
- No se tocan sin pedirlo: `~/.gradle/caches/modules-2`, `~/.pub-cache`, los emuladores (AVD), el SDK ni nada de fuera del repositorio que el script no liste.

## 5. Informe

En una tabla corta: la rama borrada, el espacio liberado dentro y fuera del repositorio, lo que se conservó y por qué, y el espacio libre del disco (`df -h .`).
