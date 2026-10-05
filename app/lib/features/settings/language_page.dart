import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/locale_resolution.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/locale_choice.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/live_notice.dart';
import '../../ui/radio_row.dart';
import '../../ui/request_focus.dart';
import 'language_label.dart';
import 'settings_controller.dart';
import 'settings_page.dart';
import 'settings_route.dart';

/// Abre la página de Idioma (nivel 2 de Ajustes) y, al volver, **una sola vez**
/// devuelve el foco (teclado y lector) a la fila que la abrió, [focus] y
/// [semantics] (CA-015-08 paso 4, tabla de niveles de la spec). El foco se pide
/// cuando la página ya se fue (el fundido de 160 ms, o 0 con reducir
/// movimiento), con la fila ya en el idioma nuevo.
Future<void> openLanguagePage(
  BuildContext context, {
  required FocusNode focus,
  required GlobalKey semantics,
}) async {
  final back = settingsTransition(context);
  await Navigator.of(context)
      .push(settingsRoute<void>(context, (_) => const LanguagePage()));
  if (!context.mounted) return;
  requestFocusAfter(
    after: back,
    isMounted: () => context.mounted,
    node: focus,
    semantics: semantics,
  );
}

/// Nivel 2 de Ajustes: la página de Idioma (spec 015, CA-015-07 y 08; sin
/// diseño en el prototipo, DEV-52). Tres opciones en un grupo de selección
/// única: "Como el sistema" (con el idioma que resulta debajo), "Español" y
/// "English".
///
/// Elegir una opción distinta, **en este orden** (CA-015-08): se guarda; solo si
/// se guardó, la página se **congela en el idioma anterior** (texto y marca de
/// idioma del lector) y sube, y en la **misma llamada** se aplica el idioma: así
/// Ajustes (debajo) ya sale en el idioma nuevo y la página que se desvanece no
/// se repinta en él (ningún fotograma mezclado). La misma opción solo sube, sin
/// guardar. Si falla el guardado, la página se queda con la opción anterior y el
/// aviso, sin cambiar nada ni mover el foco (CA-015-25).
class LanguagePage extends ConsumerStatefulWidget {
  const LanguagePage({super.key});

  @override
  ConsumerState<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends ConsumerState<LanguagePage>
    with WidgetsBindingObserver {
  /// Hay un guardado en curso: los demás toques se ignoran (CL-015-1).
  bool _saving = false;

  /// La página ya está subiendo: ni otro toque ni otro guardado.
  bool _leaving = false;

  bool _failed = false;

  /// Número del intento fallido (clave de `LiveNotice`: se anuncia una vez por
  /// intento, también con el mismo texto).
  int _attempt = 0;

  /// El idioma anterior y la opción elegida, **congelados** al subir: la página
  /// que se desvanece no se repinta en el idioma nuevo.
  Locale? _frozenLocale;
  LocaleChoice? _frozenChoice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// El idioma del sistema cambió con la página abierta: la línea de "Como el
  /// sistema" muestra el que resulta ahora (CL-015-13).
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
  }

  Future<void> _choose(LocaleChoice choice) async {
    if (_saving || _leaving) return;
    final controller = ref.read(settingsProvider.notifier);
    if (choice == ref.read(settingsProvider).locale) {
      // La misma opción: solo se vuelve, sin guardar de nuevo.
      _leaving = true;
      Navigator.of(context).pop();
      return;
    }
    _saving = true;
    final SaveResult result;
    try {
      result = await controller.saveLocale(choice);
    } finally {
      _saving = false;
    }
    if (!mounted) {
      // Se salió con Volver mientras se guardaba: lo guardado se aplica igual,
      // para que la app y lo persistido no discrepen.
      if (result == SaveResult.saved) controller.applyLocale(choice);
      return;
    }
    switch (result) {
      case SaveResult.saved:
        // Una sola llamada síncrona: congelar, subir y aplicar caen en el mismo
        // fotograma.
        _leaving = true;
        setState(() {
          _frozenLocale = Localizations.localeOf(context);
          _frozenChoice = choice;
        });
        Navigator.of(context).pop();
        controller.applyLocale(choice);
      case SaveResult.failed:
        setState(() {
          _failed = true;
          _attempt++;
        });
      case SaveResult.unchanged:
        // Otro guardado en curso: este toque se ignoró, sin avisos ni vuelta.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Con el idioma ya guardado y la página subiendo, se queda en el idioma
    // anterior, en texto (`Localizations.override`) y en la marca de idioma del
    // lector (`localeForSubtree`). Antes de eso, los dos envoltorios no cambian
    // nada (mismo idioma que el de arriba) y no remontan el contenido. Los
    // textos se leen **debajo** del envoltorio (`_LanguageContent`), no aquí.
    return Semantics(
      localeForSubtree: _frozenLocale,
      child: Localizations.override(
        context: context,
        locale: _frozenLocale,
        child: _LanguageContent(
          frozenChoice: _frozenChoice,
          failed: _failed,
          attempt: _attempt,
          onChoose: (choice) => unawaited(_choose(choice)),
        ),
      ),
    );
  }
}

/// El marco y las tres opciones. Lee su idioma de **su** contexto (el del
/// `Localizations.override` de [_LanguagePageState], si la página está
/// congelada).
class _LanguageContent extends ConsumerWidget {
  const _LanguageContent({
    required this.frozenChoice,
    required this.failed,
    required this.attempt,
    required this.onChoose,
  });

  final LocaleChoice? frozenChoice;
  final bool failed;
  final int attempt;
  final ValueChanged<LocaleChoice> onChoose;

  String _name(AppLocalizations l10n, Locale locale) =>
      locale.languageCode == 'es' ? l10n.languageSpanish : l10n.languageEnglish;

  /// Etiqueta de [name] con [locale] sobre toda ella (CA-015-11: "Español" y
  /// "English" llevan su propio idioma).
  AttributedString _own(String name, Locale locale) => AttributedString(
    name,
    attributes: [
      LocaleStringAttribute(
        range: TextRange(start: 0, end: name.length),
        locale: locale,
      ),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final watched = ref.watch(settingsProvider.select((s) => s.locale));
    final selected = frozenChoice ?? watched;
    final system = resolveAppLocale(
      WidgetsBinding.instance.platformDispatcher.locales,
    );
    final systemName = _name(l10n, system);
    return SettingsPage(
      title: l10n.settingsLanguage,
      root: false,
      child: SingleChildScrollView(
        // `SettingsPage` no reserva el borde inferior: lo suma el contenido.
        padding: EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.m,
          UnaSpace.l,
          UnaSpace.l + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UnaRadioGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UnaRadioRow(
                    label: l10n.settingsLanguageSystem,
                    subtitle: systemName,
                    attributedLabel: labelWithOwnLanguage(
                      l10n.settingsLanguageSystem,
                      systemName,
                      system,
                    ),
                    selected: selected == LocaleChoice.system,
                    onTap: () => onChoose(LocaleChoice.system),
                  ),
                  UnaRadioRow(
                    label: l10n.languageSpanish,
                    attributedLabel: _own(
                      l10n.languageSpanish,
                      const Locale('es'),
                    ),
                    divider: true,
                    selected: selected == LocaleChoice.es,
                    onTap: () => onChoose(LocaleChoice.es),
                  ),
                  UnaRadioRow(
                    label: l10n.languageEnglish,
                    attributedLabel: _own(
                      l10n.languageEnglish,
                      const Locale('en'),
                    ),
                    divider: true,
                    selected: selected == LocaleChoice.en,
                    onTap: () => onChoose(LocaleChoice.en),
                  ),
                ],
              ),
            ),
            // Bajo las tres opciones; se lee tras ellas y no mueve el foco
            // (CA-015-25). Una sola clave de orden para todo el contenido.
            if (failed)
              LiveNotice(
                text: l10n.settingsSaveError,
                attempt: attempt,
                padding: const EdgeInsets.only(
                  top: UnaSpace.m,
                  left: UnaSpace.xs,
                  right: UnaSpace.xs,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
