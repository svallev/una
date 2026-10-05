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
/// Notificaciones ni Bloquear zoom: llegan con las specs 019 y 017 y la
/// estructura de bloques las admite (CA-015-01c).
///
/// Las tres filas de web usan la misma función, [openExternalPage]; los avisos
/// son regiones vivas ([LiveNotice]) y se quitan con la siguiente acción con
/// éxito sobre cualquier control o al salir del nivel (CA-015-12).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.links = const SettingsLinks()});

  /// Las tres direcciones (CA-015-13a). Solo se cambian en los tests: la app
  /// usa siempre las de la identidad.
  final SettingsLinks links;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// Una fila a la que se le devuelve el foco (teclado y lector).
class _RowFocus {
  _RowFocus(String name) : node = FocusNode(debugLabel: 'settings $name');
  final FocusNode node;
  final key = GlobalKey();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final ExternalPageSession _session = ExternalPageSession(
    onActionSucceeded: _clearSaveNotice,
  );

  final _language = _RowFocus('language');
  final _privacy = _RowFocus('privacy');
  final _licenses = _RowFocus('licenses');
  final _help = _RowFocus('help');

  /// "No se pudo guardar el ajuste." bajo el interruptor (CA-015-25) y el
  /// número del intento fallido (clave de `LiveNotice`).
  bool _saveFailed = false;
  int _saveAttempt = 0;

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

  void _clearSaveNotice() {
    if (_saveFailed && mounted) setState(() => _saveFailed = false);
  }

  /// Cambia "Pantalla siempre activa": guarda primero y el interruptor se mueve
  /// solo si se guardó (CA-015-03). Un fallo da el aviso, sin mover el foco.
  Future<void> _toggleKeepAwake() async {
    final controller = ref.read(settingsProvider.notifier);
    final result = await controller.setKeepScreenOn(
      !ref.read(settingsProvider).keepScreenOn,
    );
    if (!mounted) return;
    switch (result) {
      case SaveResult.saved:
        _session.clearNotice();
      case SaveResult.failed:
        setState(() {
          _saveFailed = true;
          _saveAttempt++;
        });
      case SaveResult.unchanged:
        // Otro guardado en curso: este toque se ignoró.
        break;
    }
  }

  Future<void> _openLanguage() async {
    if (_openingLanguage) return;
    _openingLanguage = true;
    // Al salir del nivel, los avisos ya no valen (CA-015-12).
    _clearSaveNotice();
    _session.clearNotice();
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

  void _openWeb(ExternalLink kind, _RowFocus row) => unawaited(
    openExternalPage(
      context,
      ref,
      kind,
      session: _session,
      focus: row.node,
      semantics: row.key,
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
            // Bloque 2: Pantalla siempre activa (Bloquear zoom irá debajo,
            // spec 017).
            _Block(
              children: [
                UnaSwitchRow(
                  icon: UnaIcons.phone,
                  label: l10n.settingsKeepAwake,
                  subtitle: l10n.settingsKeepAwakeHint,
                  value: settings.keepScreenOn,
                  onToggle: () => unawaited(_toggleKeepAwake()),
                ),
                if (_saveFailed)
                  LiveNotice(
                    text: l10n.settingsSaveError,
                    attempt: _saveAttempt,
                    padding: noticePadding,
                  ),
              ],
            ),
            const _BlockSeparator(),
            // Bloque 3: información y ayuda (abren la web).
            _Block(
              bottom: UnaSpace.l + UnaSpace.s,
              last: true,
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
                  onTap: () => _openWeb(ExternalLink.privacy, _privacy),
                ),
                SettingsRow(
                  icon: UnaIcons.licenseFile,
                  label: l10n.settingsThirdPartyLicenses,
                  opensWebHint: l10n.settingsOpensWebHint,
                  indent: true,
                  divider: true,
                  focusNode: _licenses.node,
                  semanticsKey: _licenses.key,
                  onTap: () => _openWeb(ExternalLink.licenses, _licenses),
                ),
                SettingsRow(
                  icon: UnaIcons.help,
                  label: l10n.settingsHelp,
                  opensWebHint: l10n.settingsOpensWebHint,
                  divider: true,
                  focusNode: _help.node,
                  semanticsKey: _help.key,
                  onTap: () => _openWeb(ExternalLink.help, _help),
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

/// Un bloque de filas con la sangría lateral del prototipo (24); los
/// separadores entre bloques van a sangre, fuera de él. El último ([last])
/// suma el borde inferior del sistema (`SettingsPage` no lo reserva).
class _Block extends StatelessWidget {
  const _Block({
    required this.children,
    this.top = UnaSpace.sm + UnaSpace.xxs,
    this.bottom = UnaSpace.sm + UnaSpace.xxs,
    this.last = false,
  });

  final List<Widget> children;
  final double top;
  final double bottom;

  /// El último bloque: suma el borde inferior del sistema.
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      UnaSpace.l,
      top,
      UnaSpace.l,
      bottom + (last ? MediaQuery.paddingOf(context).bottom : 0),
    ),
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
