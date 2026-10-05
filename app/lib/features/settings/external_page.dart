import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_identity.g.dart';
import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/services/privacy_link.dart';
import '../../ui/request_focus.dart';
import '../attachments/link_confirm_sheet.dart';

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
///   comprueba `canOpen` no apila dos confirmaciones (CL-015-1).
/// - **El aviso** "No hay ninguna app para abrir este enlace." (CA-015-12b):
///   [noApp] dice si se ve y [attempt] cambia en cada intento fallido (clave de
///   `LiveNotice`: se anuncia una vez por intento, también con el mismo texto).
///   Quien lo posee lo quita con [clearNotice] en la siguiente acción con éxito
///   sobre cualquier control, o al salir del nivel.
///
/// Lo posee el `State` de la pantalla, que lo libera con [dispose].
class ExternalPageSession extends ChangeNotifier {
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

  /// Quita el aviso si se ve.
  void clearNotice() {
    if (_disposed || !_noApp) return;
    _noApp = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Abre una de las tres webs de Ajustes en el navegador del sistema, tras
/// preguntar (CA-015-12a, patrón de CA-012-04 y CA-008-12).
///
/// 1. [privacyLink] (solo `https`, sin usuario, sin dominio mal formado): si no
///    vale, no se llama a nada y sale el aviso (CA-015-12c).
/// 2. `canOpen` **en cada toque**, sin guardar la respuesta: si no hay app,
///    el aviso, sin mover el foco (CA-015-12b).
/// 3. La confirmación "¿Abrir {host} en el navegador?" (el foco entra en
///    "Cancelar"), con la tarea de debajo sin girar (`allowRotation: false`).
/// 4. `open` **solo si se confirma**. Si cancela o `open` da `false` (aviso), el
///    foco vuelve a la fila ([focus] y [semantics], el nodo accesible del propio
///    control) cuando la confirmación ya se fue.
///
/// No se registra la dirección ni el error (P4, P5): cualquier fallo del
/// opener es "no se puede abrir".
Future<void> openExternalPage(
  BuildContext context,
  WidgetRef ref,
  ExternalLink kind, {
  required ExternalPageSession session,
  required FocusNode focus,
  required GlobalKey semantics,
  SettingsLinks links = const SettingsLinks(),
}) async {
  if (session.busy) return;
  session._busy = true;
  final opener = ref.read(linkOpenerProvider);
  void refocus() => requestFocusAfter(
    after: UnaMotion.sheetOut,
    isMounted: () => context.mounted,
    node: focus,
    semantics: semantics,
  );
  try {
    final link = privacyLink(links.of(kind));
    // Se pregunta en cada toque, sin guardar la respuesta.
    if (link == null || !await opener.canOpen(link)) {
      if (context.mounted) session._showNoApp();
      return;
    }
    if (!context.mounted) return;
    // Hay app: el aviso de un intento anterior ya no vale, aunque después se
    // cancele (CA-015-12, ciclo de vida de los avisos).
    session.clearNotice();
    final open = await showLinkConfirmSheet(
      context,
      link,
      allowRotation: false,
    );
    if (!context.mounted) return;
    if (open != true) return refocus();
    if (!await opener.open(link)) {
      if (!context.mounted) return;
      session._showNoApp();
      return refocus();
    }
    if (context.mounted) session.clearNotice();
  } on Object {
    // Sin registrar nada: ni la dirección ni el error (T-4).
    if (context.mounted) session._showNoApp();
  } finally {
    session._busy = false;
  }
}
