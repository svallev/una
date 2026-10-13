#!/usr/bin/env bash
# Falla si el manifiesto combinado de Android pide permisos no permitidos (threat-model T-13),
# exporta algún <provider> o componente que no deba (T-8) o se aparta de la lista blanca de
# componentes (spec 019, CA-019-25).
#
#   tools/check-android-permissions.sh [release|debug]     (desde app/, tras compilar esa variante)
#
# Permisos permitidos (los mismos en release y debug):
#   - INTERNET: WebView de la tarea web (spec 009, ADR-0016; P4: "la carga de una URL que el
#     usuario ha pedido ver"). La herramienta de Flutter la añade además en debug.
#   - POST_NOTIFICATIONS: notificación local de la tarea actual (spec 019, ADR-0025); se pide al
#     encender el interruptor, nunca al arrancar (P5).
#   - RECEIVE_BOOT_COMPLETED: reprogramar la alarma tras reiniciar, también antes del primer
#     desbloqueo (spec 019).
# Ninguno de alarmas exactas (SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM): CA-019-11. Se revisan todos los
# <uses-permission*>, de cualquier espacio de nombres (p. ej. com.google.android.gms.permission.AD_ID).
#
# Lista blanca de componentes (activity, receiver, service, activity-alias; los provider, aparte):
#   - MainActivity (exportada, MAIN/LAUNCHER) y la WebViewActivity de url_launcher (no exportada).
#   - ProfileInstallReceiver de androidx (exportado, protegido con android.permission.DUMP).
#   - WakeReceiver (spec 019): NO exportado, directBootAware="true", solo las seis difusiones
#     protegidas del sistema y la acción de la alarma propia fuera de todo <intent-filter>.
set -euo pipefail

MODE="${1:-release}"
case "$MODE" in
  release|debug)
    ALLOWED=("android.permission.INTERNET" "android.permission.POST_NOTIFICATIONS" "android.permission.RECEIVE_BOOT_COMPLETED") ;;
  *) echo "Uso: $0 [release|debug]" >&2; exit 2 ;;
esac

MANIFEST="$(find build/app/intermediates/merged_manifest -path "*/$MODE/*" -name AndroidManifest.xml | head -n1)"
if [ -z "$MANIFEST" ]; then
  echo "No se encontró el manifiesto combinado de $MODE. Compila antes: flutter build apk --$MODE" >&2
  exit 1
fi
PKG="$(grep -o 'package="[^"]*"' "$MANIFEST" | head -n1 | sed 's/package="\(.*\)"/\1/')"

status=0
count=0
while IFS= read -r perm; do
  [ -z "$perm" ] && continue
  count=$((count + 1))
  ok=false
  for a in "${ALLOWED[@]+"${ALLOWED[@]}"}"; do [ "$perm" = "$a" ] && ok=true; done
  # Permiso interno de androidx (nivel firma, lo declara la propia app)
  [ "$perm" = "${PKG}.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" ] && ok=true
  if [ "$ok" = false ]; then
    echo "::error::Permiso no permitido en el manifiesto de $MODE: $perm"
    status=1
  fi
done < <(grep -oE '<uses-permission(-sdk-23)?[^>]*>' "$MANIFEST" | grep -oE 'android:name="[^"]+"' | sed 's/android:name="\(.*\)"/\1/' | sort -u)

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
