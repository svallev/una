import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_identity.g.dart';
import '../../app/providers.dart';
import '../../domain/services/privacy_link.dart';

/// Las tres páginas web de Ajustes (spec 015, CA-015-12a): se abren con la
/// misma función, [openExternalPage].
enum ExternalLink { privacy, licenses, help }

/// Las tres direcciones (CA-015-13a). Por defecto son las de `AppIdentity`
/// (constantes de compilación, P7): solo los tests pasan otras.
@immutable
class SettingsLinks {
  const SettingsLinks({
    this.privacy = AppIdentity.privacyPolicyUrl,
    this.licenses = AppIdentity.thirdPartyLicensesUrl,
    this.help = AppIdentity.helpUrl,
  });

  final String privacy;
  final String licenses;
  final String help;

  String of(ExternalLink kind) => switch (kind) {
    ExternalLink.privacy => privacy,
    ExternalLink.licenses => licenses,
    ExternalLink.help => help,
  };
}

/// Estado compartido por las tres filas de web de una pantalla de Ajustes.
///
/// - **Un solo [busy]** para las tres: tocar una fila y otra mientras se
///   comprueba `canOpen` o se abre la página no abre dos veces (CL-015-1).
/// - **El aviso** "No hay ninguna app para abrir este enlace." (CA-015-12b):
///   [noApp] dice si se ve y [attempt] cambia en cada intento fallido (clave de
///   `LiveNotice`: se anuncia una vez por intento, también con el mismo texto).
///   Quien lo posee lo quita con [clearNotice] en la siguiente acción con éxito
///   sobre cualquier control, o al salir del nivel.
///
/// [onActionSucceeded] avisa a la pantalla de que una acción con éxito (abrir la
/// página) quita también los avisos que no son de este
/// objeto (el de guardado, CA-015-12 "Los avisos").
///
/// Lo posee el `State` de la pantalla, que lo libera con [dispose].
class ExternalPageSession extends ChangeNotifier {
  ExternalPageSession({this.onActionSucceeded});

  /// Se llama en cada acción con éxito, haya o no aviso de enlace que quitar.
  final VoidCallback? onActionSucceeded;

  bool _busy = false;
  bool _noApp = false;
  int _attempt = 0;
  bool _disposed = false;

  bool get busy => _busy;
  bool get noApp => _noApp;
  int get attempt => _attempt;

  void _showNoApp() {
    if (_disposed) return;
    _noApp = true;
    _attempt++;
    notifyListeners();
  }

  /// La siguiente acción con éxito sobre cualquier control: quita el aviso de
  /// enlace si se ve y avisa a la pantalla para que quite los suyos.
  void clearNotice() {
    if (_disposed) return;
    onActionSucceeded?.call();
    if (!_noApp) return;
    _noApp = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Abre una de las tres webs de Ajustes en el navegador del sistema,
/// **directamente**: sin confirmación, sin tarjeta y sin aviso previo
/// (CA-015-12a, enmienda del propietario de 2026-10-05).
///
/// 1. [privacyLink] (solo `https`, sin usuario, sin dominio mal formado): si no
///    vale, no se llama a nada y sale el aviso (CA-015-12c).
/// 2. `canOpen` **en cada toque**, sin guardar la respuesta: si no hay app,
///    el aviso (CA-015-12b).
/// 3. `open`: si da `false` (o lanza), el aviso; si abre, se quitan los avisos.
///
/// No hay ruta nueva entre el toque y `open`, así que no hay foco que mover: la
/// fila conserva el suyo y el aviso tampoco lo mueve. No se registra la
/// dirección ni el error (P4, P5): cualquier fallo del opener es "no se puede
/// abrir".
Future<void> openExternalPage(
  BuildContext context,
  WidgetRef ref,
  ExternalLink kind, {
  required ExternalPageSession session,
  SettingsLinks links = const SettingsLinks(),
}) async {
  if (session.busy) return;
  session._busy = true;
  try {
    final opener = ref.read(linkOpenerProvider);
    final link = privacyLink(links.of(kind));
    // Se pregunta en cada toque, sin guardar la respuesta.
    if (link == null || !await opener.canOpen(link)) {
      if (context.mounted) session._showNoApp();
      return;
    }
    if (!context.mounted) return;
    if (!await opener.open(link)) {
      if (context.mounted) session._showNoApp();
      return;
    }
    if (context.mounted) session.clearNotice();
  } on Object {
    // Sin registrar nada: ni la dirección ni el error (T-4).
    if (context.mounted) session._showNoApp();
  } finally {
    session._busy = false;
  }
}
