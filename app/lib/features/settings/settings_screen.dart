import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show AttributedString;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/locale_choice.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/live_notice.dart';
import '../../ui/settings_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_switch_row.dart';
import 'external_page.dart';
import 'language_label.dart';
import 'language_page.dart';
import 'settings_controller.dart';
import 'settings_page.dart';
import 'settings_route.dart';

/// Abre el nivel 1 de Ajustes (spec 015, CA-015-01a): sube desde abajo a
/// pantalla completa. Termina al cerrarse.
Future<void> openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(settingsSheetRoute<void>(context, (_) => const SettingsScreen()));

/// Nivel 1: Ajustes (spec 015, tablero 16 del prototipo). De arriba abajo:
/// **Idioma** · separador · **Pantalla siempre activa** (con su aviso de
/// guardado) · separador · **Información** (encabezado), Política de privacidad
/// y Licencias de terceros · **Ayuda** (con el aviso de enlace). Sin
/// Notificaciones: llega con la spec 019 y la estructura de bloques la admite
/// (CA-015-01c).
///
/// Las tres filas de web usan la misma función, [openExternalPage]. Los avisos
/// son regiones vivas ([LiveNotice]): **uno por interruptor** (spec 017,
/// CA-017-04), cada uno bajo su fila, y el de enlace tras Ayuda. El de cada
/// interruptor se quita cuando esa fila se guarda bien, al salir del nivel o al
/// abrir una web con éxito; el guardado con éxito de la otra fila **no** lo
/// quita (P-017-1, ajusta CA-015-12 solo en ese punto). El de enlace se quita
/// con cualquier acción con éxito (CA-015-12).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.links = const SettingsLinks()});

  /// Las tres direcciones (CA-015-13a). Solo se cambian en los tests: la app
  /// usa siempre las de la identidad.
  final SettingsLinks links;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// El foco y la clave de una fila: el nodo accesible de la fila los refleja
/// (`focusable`/`focused`) y, en "Idioma", se le devuelve el foco al volver. Las
/// filas de web no lo necesitan para volver (se abren sin ruta nueva, CA-015-12a).
class _RowFocus {
  _RowFocus(String name) : node = FocusNode(debugLabel: 'settings $name');
  final FocusNode node;
  final key = GlobalKey();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ExternalPageSession _session = ExternalPageSession(
    onActionSucceeded: _clearSaveNotices,
  );

  final _language = _RowFocus('language');
  final _privacy = _RowFocus('privacy');
  final _licenses = _RowFocus('licenses');
  final _help = _RowFocus('help');

  /// "No se pudo guardar el ajuste." bajo cada interruptor (CA-015-25,
  /// CA-017-04): el número del intento fallido de cada fila, o `null` si no hay
  /// aviso. El número es la clave de `LiveNotice` y sale de **un único
  /// contador** ([_noticeSeq]): los dos avisos son hermanos en la misma columna
  /// y, con un contador por fila, dos primeros fallos repetirían la clave.
  int? _keepAwakeNotice;
  int? _lockZoomNotice;
  int _noticeSeq = 0;

  /// La página de Idioma se está abriendo: otro toque no hace nada (CL-015-1).
  bool _openingLanguage = false;

  @override
  void dispose() {
    _session.dispose();
    _language.node.dispose();
    _privacy.node.dispose();
    _licenses.node.dispose();
    _help.node.dispose();
    super.dispose();
  }

  /// Quita los dos avisos de guardado (al salir del nivel o al abrir una web
  /// con éxito).
  void _clearSaveNotices() {
    if (!mounted || (_keepAwakeNotice == null && _lockZoomNotice == null)) {
      return;
    }
    setState(() {
      _keepAwakeNotice = null;
      _lockZoomNotice = null;
    });
  }

  /// Cambia "Pantalla siempre activa": guarda primero y el interruptor se mueve
  /// solo si se guardó (CA-015-03). Un fallo da el aviso, sin mover el foco.
  Future<void> _toggleKeepAwake() => _toggle(
    save: (controller, settings) =>
        controller.setKeepScreenOn(!settings.keepScreenOn),
    notice: (attempt) => _keepAwakeNotice = attempt,
  );

  /// Cambia "Bloquear zoom" (spec 017), con las mismas reglas.
  Future<void> _toggleLockZoom() => _toggle(
    save: (controller, settings) => controller.setLockZoom(!settings.lockZoom),
    notice: (attempt) => _lockZoomNotice = attempt,
  );

  /// El guardado de un interruptor. Si sale bien, quita el aviso de **esa** fila
  /// (y el de enlace) pero no el de la otra (P-017-1); si falla, lo pone con un
  /// intento nuevo; si se ignoró (ya se guardaba esa fila), no hace nada.
  Future<void> _toggle({
    required Future<SaveResult> Function(SettingsController, AppSettings) save,
    required void Function(int? attempt) notice,
  }) async {
    final result = await save(
      ref.read(settingsProvider.notifier),
      ref.read(settingsProvider),
    );
    if (!mounted) return;
    switch (result) {
      case SaveResult.saved:
        setState(() => notice(null));
        _session.clearLinkNotice();
      case SaveResult.failed:
        setState(() => notice(++_noticeSeq));
      case SaveResult.unchanged:
        // Otro guardado de esta fila en curso: este toque se ignoró.
        break;
    }
  }

  Future<void> _openLanguage() async {
    if (_openingLanguage) return;
    _openingLanguage = true;
    // Al salir del nivel, los avisos ya no valen (CA-015-12).
    _session.clearNotice(); // Quita los avisos de guardado y el de enlace.
    try {
      await openLanguagePage(
        context,
        focus: _language.node,
        semantics: _language.key,
      );
    } finally {
      _openingLanguage = false;
    }
  }

  void _openWeb(ExternalLink kind) => unawaited(
    openExternalPage(
      context,
      ref,
      kind,
      session: _session,
      links: widget.links,
    ),
  );

  /// El valor de la fila "Idioma" y, con "Español" o "English", su etiqueta del
  /// lector con el idioma propio de ese nombre (CA-015-11).
  (String, AttributedString?) _languageValue(
    AppLocalizations l10n,
    LocaleChoice choice,
  ) {
    final (value, locale) = switch (choice) {
      LocaleChoice.system => (l10n.settingsLanguageSystem, null),
      LocaleChoice.es => (l10n.languageSpanish, const Locale('es')),
      LocaleChoice.en => (l10n.languageEnglish, const Locale('en')),
    };
    return (
      value,
      locale == null
          ? null
          : labelWithOwnLanguage(l10n.settingsLanguage, value, locale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final (languageValue, languageLabel) = _languageValue(
      l10n,
      settings.locale,
    );
    const noticePadding = EdgeInsets.only(
      top: UnaSpace.m,
      left: UnaSpace.xs,
      right: UnaSpace.xs,
    );
    // El de "Pantalla siempre activa" queda justo sobre la línea de 1 px de la
    // fila siguiente: un respiro debajo para que no la toque.
    final saveNoticePadding = noticePadding.copyWith(bottom: UnaSpace.s);
    return SettingsPage(
      title: l10n.settingsTitle,
      root: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bloque 1: Idioma (Notificaciones irá debajo, spec 019).
            _Block(
              top: UnaSpace.m + UnaSpace.xxs,
              children: [
                SettingsRow(
                  icon: UnaIcons.globe,
                  label: l10n.settingsLanguage,
                  value: languageValue,
                  attributedLabel: languageLabel,
                  trailing: SettingsRowTrailing.chevron,
                  focusNode: _language.node,
                  semanticsKey: _language.key,
                  onTap: () => unawaited(_openLanguage()),
                ),
              ],
            ),
            const _BlockSeparator(),
            // Bloque 2: Pantalla siempre activa y Bloquear zoom (spec 017), cada
            // una con su aviso de guardado justo debajo. Los avisos son huecos
            // siempre presentes del mismo tipo ([_SaveNoticeSlot]): ni un `if`
            // ni un hueco `SizedBox` bastan, porque al pasar de `LiveNotice`
            // (con clave) a otro tipo, Flutter no casa la fila sin clave de en
            // medio y la recrea con el foco encima (se perdería el anillo y el
            // nodo del lector).
            _Block(
              children: [
                UnaSwitchRow(
                  icon: UnaIcons.phone,
                  label: l10n.settingsKeepAwake,
                  subtitle: l10n.settingsKeepAwakeHint,
                  value: settings.keepScreenOn,
                  onToggle: () => unawaited(_toggleKeepAwake()),
                ),
                _SaveNoticeSlot(
                  attempt: _keepAwakeNotice,
                  padding: saveNoticePadding,
                ),
                UnaSwitchRow(
                  icon: UnaIcons.magnifierMinus,
                  label: l10n.settingsLockZoom,
                  subtitle: l10n.settingsLockZoomHint,
                  value: settings.lockZoom,
                  divider: true,
                  onToggle: () => unawaited(_toggleLockZoom()),
                ),
                _SaveNoticeSlot(
                  attempt: _lockZoomNotice,
                  padding: saveNoticePadding,
                ),
              ],
            ),
            const _BlockSeparator(),
            // Bloque 3: información y ayuda (abren la web).
            _Block(
              bottom: UnaSpace.l + UnaSpace.s,
              children: [
                _InfoHeader(label: l10n.settingsInfo),
                SettingsRow(
                  icon: UnaIcons.lock,
                  label: l10n.settingsPrivacy,
                  opensWebHint: l10n.settingsOpensWebHint,
                  indent: true,
                  divider: true,
                  focusNode: _privacy.node,
                  semanticsKey: _privacy.key,
                  onTap: () => _openWeb(ExternalLink.privacy),
                ),
                SettingsRow(
                  icon: UnaIcons.licenseFile,
                  label: l10n.settingsThirdPartyLicenses,
                  opensWebHint: l10n.settingsOpensWebHint,
                  indent: true,
                  divider: true,
                  focusNode: _licenses.node,
                  semanticsKey: _licenses.key,
                  onTap: () => _openWeb(ExternalLink.licenses),
                ),
                SettingsRow(
                  icon: UnaIcons.help,
                  label: l10n.settingsHelp,
                  opensWebHint: l10n.settingsOpensWebHint,
                  divider: true,
                  focusNode: _help.node,
                  semanticsKey: _help.key,
                  onTap: () => _openWeb(ExternalLink.help),
                ),
                // Tras Ayuda; el lector lo lee ahí por geometría.
                ListenableBuilder(
                  listenable: _session,
                  builder: (context, _) => _session.noApp
                      ? LiveNotice(
                          text: l10n.errNoAppForLink,
                          attempt: _session.attempt,
                          padding: noticePadding,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El hueco del aviso de guardado de una fila: [LiveNotice] si hay intento
/// fallido ([attempt], la clave del aviso) o nada. Es siempre el mismo tipo de
/// widget: así la fila de interruptor que queda debajo conserva su `State` y su
/// foco cuando el aviso de arriba (o los dos) se quita.
class _SaveNoticeSlot extends StatelessWidget {
  const _SaveNoticeSlot({required this.attempt, required this.padding});

  final int? attempt;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final attempt = this.attempt;
    if (attempt == null) return const SizedBox.shrink();
    return LiveNotice(
      text: AppLocalizations.of(context).settingsSaveError,
      attempt: attempt,
      padding: padding,
    );
  }
}

/// Un bloque de filas con la sangría lateral del prototipo (24); los
/// separadores entre bloques van a sangre, fuera de él. `SettingsPage` reserva
/// el borde inferior del sistema.
class _Block extends StatelessWidget {
  const _Block({
    required this.children,
    this.top = UnaSpace.sm + UnaSpace.xxs,
    this.bottom = UnaSpace.sm + UnaSpace.xxs,
  });

  final List<Widget> children;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(UnaSpace.l, top, UnaSpace.l, bottom),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Separador de bloque: 4 px de borde a borde, decorativo (CA-015-01b).
class _BlockSeparator extends StatelessWidget {
  const _BlockSeparator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: UnaSizes.separatorBlock,
    child: ColoredBox(color: UnaColors.disabled),
  );
}

/// "Información": encabezado del bloque 3, no se puede pulsar (CA-015-01b y
/// 20e). Un solo nodo de encabezado; el icono es decorativo.
class _InfoHeader extends StatelessWidget {
  const _InfoHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    container: true,
    label: label,
    excludeSemantics: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: UnaSizes.settingsRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UnaSpace.xs),
        child: Row(
          children: [
            const UnaIcon(UnaIcons.info),
            const SizedBox(width: UnaSpace.m),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: UnaFonts.display,
                  fontSize: UnaFontSizes.bodyL,
                  fontWeight: UnaFontWeights.bold,
                  height: 1.15,
                  color: UnaColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
