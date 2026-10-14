#!/usr/bin/env bash
# Falla si el manifiesto combinado de Android pide permisos no permitidos (threat-model T-13),
# exporta algún <provider> o componente que no deba (T-8) o se aparta de la lista blanca de
# componentes (spec 019, CA-019-25).
#
#   tools/check-android-permissions.sh [release|debug]     (desde app/, tras compilar esa variante)
#   tools/check-android-permissions.sh [release|debug] --manifest <archivo>   (un manifiesto dado:
#       pruebas; no hace falta compilar)
#   tools/check-android-permissions.sh release --aab <archivo> [--aapt2 <ruta>]   (el manifiesto de un
#       AAB, que va en formato proto: se lee con `app/tool/check_package.dart --manifest-xml`, que
#       reempaqueta el módulo base y lo pasa a XML, y se revisa con las mismas reglas; spec 020,
#       P-020-1; falla cerrada si el AAB no se puede leer)
#   tools/check-android-permissions.sh --negative           (los manifiestos de prueba de
#       tools/fixtures/manifests/: cada uno tiene que fallar nombrando lo suyo; el bueno, pasar)
#
# Permisos permitidos (los mismos en release y debug):
#   - INTERNET: WebView de la tarea web (spec 009, ADR-0016; P4: "la carga de una URL que el
#     usuario ha pedido ver"). La herramienta de Flutter la añade además en debug.
#   - POST_NOTIFICATIONS: notificación local de la tarea actual (spec 019, ADR-0025); se pide al
#     encender el interruptor, nunca al arrancar (P5).
#   - RECEIVE_BOOT_COMPLETED: reprogramar la alarma tras reiniciar, también antes del primer
#     desbloqueo (spec 019).
# Ninguno de alarmas exactas (SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM): CA-019-11. Se revisan todos los
# <uses-permission*>, de cualquier espacio de nombres (p. ej. com.google.android.gms.permission.AD_ID),
# en todas sus formas: <uses-permission>, <uses-permission-sdk-23>, <uses-permission-sdk-m>…
# (CA-020-13), aunque la etiqueta se reparta en varias líneas; lo que está dentro de un comentario
# no cuenta.
#
# Lista blanca de componentes (activity, receiver, service, activity-alias; los provider, aparte):
#   - MainActivity (exportada) con exactamente un <intent-filter>: la acción MAIN y la categoría
#     LAUNCHER, sin <data>, sin BROWSABLE ni DEFAULT, sin otras acciones ni atributos (sin enlaces
#     profundos, T-8; CA-020-13), y la WebViewActivity de url_launcher (no exportada).
#   - ProfileInstallReceiver de androidx (exportado, protegido con android.permission.DUMP).
#   - WakeReceiver (spec 019): NO exportado, directBootAware="true", solo las seis difusiones
#     protegidas del sistema y la acción de la alarma propia fuera de todo <intent-filter>.
set -euo pipefail

MODE="release"
MANIFEST=""
AAB=""
AAPT2=""
NEGATIVE=false
usage() { echo "Uso: $0 [release|debug] [--manifest <archivo> | --aab <archivo> [--aapt2 <ruta>]] | $0 --negative" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    release|debug) MODE="$1" ;;
    --manifest) [ $# -ge 2 ] || usage; MANIFEST="$2"; shift ;;
    --aab) [ $# -ge 2 ] || usage; AAB="$2"; shift ;;
    --aapt2) [ $# -ge 2 ] || usage; AAPT2="$2"; shift ;;
    --negative) NEGATIVE=true ;;
    *) usage ;;
  esac
  shift
done
if [ -n "$AAB" ] && { [ -n "$MANIFEST" ] || [ "$NEGATIVE" = true ]; }; then usage; fi
if [ -n "$AAPT2" ] && [ -z "$AAB" ]; then usage; fi
ALLOWED=("android.permission.INTERNET" "android.permission.POST_NOTIFICATIONS" "android.permission.RECEIVE_BOOT_COMPLETED")

# Los manifiestos de prueba (CA-020-13): cada uno de expected.tsv (archivo, TAB, texto que el error
# tiene que nombrar) debe fallar; ok.xml, pasar; y ningún .xml queda sin su línea.
if [ "$NEGATIVE" = true ]; then
  if [ -n "$MANIFEST" ]; then usage; fi
  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  DIR="$(cd "$(dirname "$0")" && pwd)/fixtures/manifests"
  bad=0
  n=0
  if ! out="$(bash "$SELF" release --manifest "$DIR/ok.xml" 2>&1)"; then
    echo "::error::El manifiesto bueno (ok.xml) debería pasar y falla: $out"
    bad=1
  fi
  listed=" "
  while IFS=$'\t' read -r file text; do
    case "$file" in ''|'#'*) continue ;; esac
    listed="$listed$file "
    n=$((n + 1))
    if [ -z "$text" ]; then echo "::error::expected.tsv: $file sin el texto que debe nombrar"; bad=1; continue; fi
    if out="$(bash "$SELF" release --manifest "$DIR/$file" 2>&1)"; then
      echo "::error::$file debería fallar y pasa"
      bad=1
    elif ! grep -qF -- "$text" <<<"$out"; then
      echo "::error::$file falla, pero sin nombrar «${text}»: ${out}"
      bad=1
    fi
  done < "$DIR/expected.tsv"
  for f in "$DIR"/*.xml; do
    base="$(basename "$f")"
    [ "$base" = "ok.xml" ] && continue
    case "$listed" in *" $base "*) ;; *) echo "::error::$base no está en expected.tsv (nadie lo ejecutaría)"; bad=1 ;; esac
  done
  [ "$n" -ge 1 ] || { echo "::error::expected.tsv sin ningún caso"; bad=1; }
  [ "$bad" -eq 0 ] && echo "Los $n manifiestos negativos fallan como se esperaba y el bueno pasa."
  exit $bad
fi

if [ -n "$AAB" ]; then
  # El manifiesto del AAB, como XML en un archivo temporal (se borra al salir).
  abs() { case "$1" in /*) echo "$1" ;; *) echo "$PWD/$1" ;; esac; }
  TOOLS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  AAB_ABS="$(abs "$AAB")"
  MANIFEST="$(mktemp "${TMPDIR:-/tmp}/aab-manifest.XXXXXX")"
  trap 'rm -f "$MANIFEST"' EXIT
  aapt_args=()
  [ -n "$AAPT2" ] && aapt_args=(--aapt2 "$(abs "$AAPT2")")
  if ! (cd "$TOOLS_ROOT/app" && dart run tool/check_package.dart ${aapt_args[@]+"${aapt_args[@]}"} --manifest-xml "$MANIFEST" "$AAB_ABS") >&2; then
    echo "::error::No se pudo leer el manifiesto de $AAB" >&2
    exit 1
  fi
elif [ -z "$MANIFEST" ]; then
  MANIFEST="$(find build/app/intermediates/merged_manifest -path "*/$MODE/*" -name AndroidManifest.xml 2>/dev/null | head -n1 || true)"
  if [ -z "$MANIFEST" ]; then
    echo "No se encontró el manifiesto combinado de $MODE. Compila antes: flutter build apk --$MODE" >&2
    exit 1
  fi
elif [ ! -f "$MANIFEST" ] || [ ! -r "$MANIFEST" ]; then
  echo "::error::No se puede leer el manifiesto $MANIFEST" >&2
  exit 1
fi
# Falla cerrada: un archivo vacío o que no es un manifiesto no se da por bueno.
if ! grep -q '<manifest\b' "$MANIFEST"; then
  echo "::error::$(basename "$MANIFEST") no es un manifiesto de Android (sin <manifest>)" >&2
  exit 1
fi
PKG="$(tr '\n' ' ' < "$MANIFEST" | grep -oE '<manifest[^>]*' | grep -oE 'package="[^"]*"' | head -n1 | sed 's/package="\(.*\)"/\1/')"

status=0
count=0
# Todas las formas de pedir un permiso (<uses-permission>, -sdk-23, -sdk-m…), sin los comentarios y
# aunque la etiqueta ocupe varias líneas. Salida: "etiqueta TAB nombre" (nombre vacío = ilegible).
while IFS=$'\t' read -r tag perm; do
  [ -z "$tag" ] && continue
  count=$((count + 1))
  if [ -z "$perm" ]; then
    echo "::error::Etiqueta <$tag> sin android:name legible en el manifiesto de $MODE"
    status=1
    continue
  fi
  ok=false
  for a in "${ALLOWED[@]+"${ALLOWED[@]}"}"; do [ "$perm" = "$a" ] && ok=true; done
  # Permiso interno de androidx (nivel firma, lo declara la propia app)
  [ -n "$PKG" ] && [ "$perm" = "${PKG}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" ] && ok=true
  if [ "$ok" = false ]; then
    echo "::error::Permiso no permitido en el manifiesto de $MODE: $perm (<$tag>)"
    status=1
  fi
done < <(perl -0777 -e '
  open(my $fh, "<", $ARGV[0]) or die "no se puede leer $ARGV[0]";
  my $xml = do { local $/; <$fh> };
  $xml =~ s/<!--.*?-->//gs;
  my %seen;
  while ($xml =~ m{<(uses-permission[\w-]*)\b([^>]*)>}gs) {
    my ($tag, $attrs) = ($1, $2);
    my ($n1, $n2) = $attrs =~ /android:name\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/;
    my $name = defined $n1 ? $n1 : (defined $n2 ? $n2 : "");
    my $line = "$tag\t$name";
    print "$line\n" unless $seen{$line}++;
  }
' "$MANIFEST")

# Ningún <provider> exportado (T-8): el FileProvider de la cámara (spec 007) da permisos
# puntuales con grantUriPermissions, nunca acceso general.
while IFS= read -r provider; do
  [ -z "$provider" ] && continue
  if ! grep -q 'android:exported="false"' <<<"$provider"; then
    echo "::error::<provider> exportado o sin android:exported=\"false\" en $MODE: $(grep -oE 'android:name="[^"]+"' <<<"$provider" | head -n1)"
    status=1
  fi
done < <(tr '\n' ' ' < "$MANIFEST" | grep -oE '<provider[^>]*>')

# Componentes (spec 019, CA-019-25): lista blanca exacta. Un componente nuevo, o uno de la lista con
# otro `exported`/permiso/arranque directo/acciones, falla. Las clases propias usan el `namespace`
# (el `package` del manifiesto combinado de debug y profile lleva además el sufijo de la variante).
BASE_PKG="$PKG"
case "$MODE" in debug|profile) BASE_PKG="${PKG%.$MODE}" ;; esac

components_report="$(perl -0777 -e '
  my ($file, $base) = @ARGV;
  open(my $fh, "<", $file) or die "no se puede leer $file";
  my $xml = do { local $/; <$fh> };
  $xml =~ s/<!--.*?-->//gs;
  my $alarm = "$base.action.NOTIFICATION_ALARM";
  my @errors;
  my %found;
  my @systemActions = qw(
    android.intent.action.LOCKED_BOOT_COMPLETED android.intent.action.BOOT_COMPLETED
    android.intent.action.TIME_SET android.intent.action.TIMEZONE_CHANGED
    android.intent.action.LOCALE_CHANGED android.intent.action.MY_PACKAGE_REPLACED);
  my %system = map { $_ => 1 } @systemActions;
  while ($xml =~ m{<(activity-alias|activity|receiver|service)\b([^>]*?)(?:/>|>(.*?)</\1>)}gs) {
    my ($type, $attrs, $body) = ($1, $2, defined $3 ? $3 : "");
    my ($name)   = $attrs =~ /android:name="([^"]*)"/;
    my ($export) = $attrs =~ /android:exported="([^"]*)"/;
    my ($perm)   = $attrs =~ /android:permission="([^"]*)"/;
    my ($direct) = $attrs =~ /android:directBootAware="([^"]*)"/;
    $name = "" unless defined $name;
    $export = "" unless defined $export;
    my @actions = $body =~ /<action\b[^>]*android:name="([^"]*)"/g;
    $found{$name} = 1;
    if ($type eq "activity" && $name eq "$base.MainActivity") {
      push @errors, "MainActivity debe llevar android:exported=\"true\"" unless $export eq "true";
      # CA-020-13 (a): exactamente un <intent-filter>, MAIN + LAUNCHER y nada más (sin enlaces
      # profundos: ni <data>, ni BROWSABLE, ni DEFAULT, ni otras acciones o categorías).
      my $filters = () = $body =~ /<intent-filter\b/g;
      if ($filters != 1) {
        push @errors, "MainActivity debe tener exactamente un <intent-filter> y tiene $filters <intent-filter>";
      } else {
        my ($fattrs, $inner) = ("", "");
        if ($body =~ m{<intent-filter\b([^>]*?)/>}s) {
          ($fattrs, $inner) = ($1, "");
        } elsif ($body =~ m{<intent-filter\b([^>]*)>(.*?)</intent-filter>}s) {
          ($fattrs, $inner) = ($1, $2);
        } else {
          push @errors, "MainActivity: <intent-filter> sin cerrar";
        }
        for my $attr ($fattrs =~ /([\w:.-]+)\s*=/g) {
          push @errors, "MainActivity: el <intent-filter> lleva el atributo $attr";
        }
        for my $kid ($inner =~ /<([A-Za-z][\w:.-]*)/g) {
          next if $kid eq "action" || $kid eq "category";
          push @errors, $kid eq "data"
            ? "MainActivity: el <intent-filter> lleva un <data> (enlace profundo)"
            : "MainActivity: el <intent-filter> lleva un <$kid>";
        }
        my (@acts, @cats);
        while ($inner =~ m{<(action|category)\b([^>]*)>}gs) {
          my ($kind, $a) = ($1, $2);
          my ($n1, $n2) = $a =~ /android:name\s*=\s*(?:"([^"]*)"|\x27([^\x27]*)\x27)/;
          my $v = defined $n1 ? $n1 : (defined $n2 ? $n2 : "");
          if ($v eq "") {
            push @errors, "MainActivity: <$kind> del <intent-filter> sin android:name legible";
          } elsif ($kind eq "action") { push @acts, $v } else { push @cats, $v }
        }
        my $main = "android.intent.action.MAIN";
        my $launch = "android.intent.category.LAUNCHER";
        push @errors, "MainActivity: el <intent-filter> no tiene la acción $main" unless grep { $_ eq $main } @acts;
        push @errors, "MainActivity: el <intent-filter> no tiene la categoría $launch" unless grep { $_ eq $launch } @cats;
        my %seenAct;
        for my $x (@acts) { push @errors, "MainActivity: el <intent-filter> tiene la acción $x de más" if $x ne $main || $seenAct{$x}++; }
        my %seenCat;
        for my $x (@cats) { push @errors, "MainActivity: el <intent-filter> tiene la categoría $x de más" if $x ne $launch || $seenCat{$x}++; }
      }
    } elsif ($type eq "activity" && $name eq "io.flutter.plugins.urllauncher.WebViewActivity") {
      push @errors, "WebViewActivity debe llevar android:exported=\"false\"" unless $export eq "false";
    } elsif ($type eq "receiver" && $name eq "androidx.profileinstaller.ProfileInstallReceiver") {
      push @errors, "ProfileInstallReceiver debe ir protegido con android:permission=\"android.permission.DUMP\""
        unless defined $perm && $perm eq "android.permission.DUMP";
    } elsif ($type eq "receiver" && $name eq "$base.notifications.WakeReceiver") {
      push @errors, "WakeReceiver exportado o sin android:exported=\"false\"" unless $export eq "false";
      push @errors, "WakeReceiver sin android:directBootAware=\"true\" (debe funcionar antes del primer desbloqueo)"
        unless defined $direct && $direct eq "true";
      for my $a (@actions) {
        push @errors, "WakeReceiver escucha una acción fuera de la lista blanca: $a" unless $system{$a};
      }
    } else {
      push @errors, "Componente no permitido (<$type> $name)";
    }
  }
  push @errors, "Falta MainActivity en el manifiesto" unless $found{"$base.MainActivity"};
  push @errors, "Falta el WakeReceiver en el manifiesto" unless $found{"$base.notifications.WakeReceiver"};
  # La alarma propia llega por un PendingIntent explícito: ninguna <action> igual en ningún filtro.
  while ($xml =~ m{<intent-filter\b.*?</intent-filter>}gs) {
    my $filter = $&;
    push @errors, "La acción de la alarma está en un <intent-filter>: $alarm" if $filter =~ /\Q$alarm\E/ || $filter =~ /NOTIFICATION_ALARM/;
  }
  print "$_\n" for @errors;
' "$MANIFEST" "$BASE_PKG")"
if [ -n "$components_report" ]; then
  while IFS= read -r line; do
    echo "::error::$line (manifiesto de $MODE)"
  done <<<"$components_report"
  status=1
fi

[ "$status" -eq 0 ] && echo "Permisos y componentes de $MODE correctos ($count permisos revisados; $MANIFEST)."
exit $status
