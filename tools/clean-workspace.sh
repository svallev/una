#!/usr/bin/env bash
# Frees disk space after a PR is merged (skill /post-merge).
#
#   tools/clean-workspace.sh                 # dry run: lists what it would delete, with sizes
#   tools/clean-workspace.sh --apply         # deletes it
#   tools/clean-workspace.sh --global        # dry run of what is outside the repo (Gradle, SDK)
#   tools/clean-workspace.sh --global --apply
#
# In the repo it deletes only regenerable, untracked build output: app/build, app/.dart_tool,
# the Android .gradle/.kotlin/.cxx folders, coverage, the build folders of the spikes and
# .DS_Store files. It keeps app/build/mastg-NNN while spec NNN is not «Implementada» (it is
# the evidence of its MASTG pass). Outside the repo it deletes only what is obsolete: the
# Gradle versions the wrapper no longer uses and the system images no emulator uses.
# Never follows symlinks, never touches a tracked file or anything outside its list.
set -euo pipefail

apply=0
global=0
for arg in "$@"; do
  case "$arg" in
    --apply) apply=1 ;;
    --global) global=1 ;;
    -h | --help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "uso: $0 [--global] [--apply]" >&2; exit 2 ;;
  esac
done

root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "error: no es un repositorio git" >&2; exit 2; }
cd "$root"

total_kb=0
count=0

size_kb() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }
human() { awk -v k="$1" 'BEGIN { split("K M G T", u); i = 1; while (k >= 1024 && i < 4) { k /= 1024; i++ } printf (i == 1 ? "%d%s" : "%.1f%s"), k, u[i] }'; }

# remove <path> <reason>: checks, reports and (with --apply) deletes one path.
remove() {
  local path="$1" why="$2"
  [[ -e "$path" || -L "$path" ]] || return 0
  if [[ -L "$path" ]]; then
    echo "  omitido (enlace simbólico): $path" >&2
    return 0
  fi
  if [[ "$path" != /* ]] && [[ -n "$(git ls-files -- "$path" | head -n 1)" ]]; then
    echo "  omitido (tiene archivos en git): $path" >&2
    return 0
  fi
  local kb
  kb="$(size_kb "$path")"
  kb="${kb:-0}"
  total_kb=$((total_kb + kb))
  count=$((count + 1))
  printf '  %8s  %s  (%s)\n' "$(human "$kb")" "$path" "$why"
  if ((apply)); then
    rm -rf -- "$path"
  fi
}

# A spec is finished when its Estado line starts with **Implementada** (not «parcialmente»).
spec_finished() {
  local spec
  for spec in specs/"$1"-*/spec.md; do
    [[ -f "$spec" ]] || continue
    grep -E '^- \*\*Estado:\*\* \*\*Implementada\*\*' "$spec" >/dev/null && return 0
  done
  return 1
}

clean_repo() {
  echo "Proyecto ($root):"
  local entry name
  if [[ -d app/build && ! -L app/build ]]; then
    for entry in app/build/* app/build/.[!.]*; do
      [[ -e "$entry" || -L "$entry" ]] || continue
      name="${entry#app/build/}"
      if [[ "$name" =~ ^mastg-([0-9]{3})$ ]] && ! spec_finished "${BASH_REMATCH[1]}"; then
        echo "  conservado: $entry (la spec ${BASH_REMATCH[1]} no está Implementada)"
        continue
      fi
      remove "$entry" "compilación"
    done
  fi
  remove app/.dart_tool "Dart y build hooks; se regenera con pub get"
  remove app/coverage "cobertura"
  remove app/android/.gradle "Gradle del proyecto"
  remove app/android/.kotlin "Kotlin del proyecto"
  remove app/android/app/.cxx "CMake"
  if [[ -d spikes ]]; then
    while IFS= read -r -d '' entry; do
      remove "$entry" "spike"
    done < <(find spikes \( -name build -o -name .dart_tool -o -name .gradle -o -name .kotlin -o -name .cxx \) -type d -prune -print0)
  fi
  while IFS= read -r -d '' entry; do
    remove "$entry" "Finder"
  done < <(find . -path ./.git -prune -o -name .DS_Store -type f -print0)
}

clean_global() {
  echo "Fuera del proyecto (solo lo obsoleto):"
  local props="app/android/gradle/wrapper/gradle-wrapper.properties" current dir version
  current="$(sed -n 's/^distributionUrl=.*gradle-\([0-9][0-9.]*\)-.*/\1/p' "$props" 2>/dev/null)"
  if [[ -z "$current" ]]; then
    echo "  error: no se lee la versión de Gradle de $props; no se toca la caché de Gradle" >&2
  else
    echo "  Gradle del wrapper: $current (se conserva; también modules-2, la caché de dependencias)"
    for dir in "$HOME"/.gradle/caches/[0-9]* "$HOME"/.gradle/wrapper/dists/gradle-*; do
      [[ -d "$dir" ]] || continue
      version="$(basename "$dir")"
      version="${version#gradle-}"
      version="${version%-all}"
      version="${version%-bin}"
      [[ "$version" == "$current" ]] && continue
      remove "$dir" "Gradle $version, que ya no usa el wrapper"
    done
  fi
  local sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}" used image rel
  used="$(cat "$HOME"/.android/avd/*.avd/config.ini 2>/dev/null | sed -n 's/^image\.sysdir\.[0-9]*=//p' | sed 's#/*$##')"
  if [[ -d "$sdk/system-images" ]]; then
    while IFS= read -r -d '' image; do
      rel="${image#"$sdk"/}"
      if grep -Fx -- "$rel" <<<"$used" >/dev/null; then
        echo "  conservada: $image (la usa un emulador)"
        continue
      fi
      remove "$image" "imagen de sistema sin emulador"
    done < <(find "$sdk/system-images" -mindepth 3 -maxdepth 3 -type d -print0)
  fi
  local pub="${PUB_CACHE:-$HOME/.pub-cache}"
  if [[ -d "$pub" ]]; then
    echo "  sin tocar: $pub ($(human "$(size_kb "$pub")")): la usan los proyectos; vaciarla obliga a descargarlo todo"
  fi
}

if ((global)); then clean_global; else clean_repo; fi

if ((apply)); then
  echo "Borrado: $count elementos, $(human "$total_kb")."
else
  echo "Se borrarían $count elementos, $(human "$total_kb"). Nada borrado: repite con --apply."
fi
