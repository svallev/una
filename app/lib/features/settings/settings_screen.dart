import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show AttributedString;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/locale_choice.dart';
import '../../domain/entities/notification_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/live_notice.dart';
import '../../ui/settings_row.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_switch_row.dart';
import 'external_page.dart';
import 'language_label.dart';
import 'language_page.dart';
import 'notifications_block.dart';
import 'notifications_state.dart';
import 'settings_controller.dart';
import 'settings_page.dart';
import 'settings_route.dart';

/// Abre el nivel 1 de Ajustes (spec 015, CA-015-01a): sube desde abajo a
/// pantalla completa. Termina al cerrarse.
Future<void> openSettings(BuildContext context) =>
    Navigator.of(context)
        .push(settingsSheetRoute<void>(context, (_) => const SettingsScreen()));

/// Nivel 1: Ajustes (spec 015, tablero 16 del prototipo). De arriba abajo:
/// **Idioma** · **Notificaciones** (spec 019: solo en Android y con el
/// indicador encendido, con su línea de privacidad y sus opciones; en el mismo
/// bloque que Idioma) · separador · **Pantalla siempre activa** (con su aviso
/// de guardado) · separador · **Información** (encabezado), Política de
/// privacidad y Licencias de terceros · **Ayuda** (con el aviso de enlace).
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

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  late final ExternalPageSession _session = ExternalPageSession(
    onActionSucceeded: _clearSaveNotices,
  );

  final _language = _RowFocus('language');
  final _notifications = _RowFocus('notifications');
  final _privacy = _RowFocus('privacy');
  final _licenses = _RowFocus('licenses');
  final _help = _RowFocus('help');

  /// El bloque de Notificaciones, para decirle qué anunciar.
  final _notificationsBlock = GlobalKey<NotificationsBlockState>();

  /// Lo que permite el sistema (se olvida al salir).
  late final SystemAllowsNotifications _system;

  /// "No se pudo guardar el ajuste." bajo cada interruptor (CA-015-25,
  /// CA-017-04): el número del intento fallido de cada fila, o `null` si no hay
  /// aviso. El número es la clave de `LiveNotice` y sale de **un único
  /// contador** ([_noticeSeq]): los dos avisos son hermanos en la misma columna
  /// y, con un contador por fila, dos primeros fallos repetirían la clave.
  int? _keepAwakeNotice;
  int? _lockZoomNotice;
  int _noticeSeq = 0;

  /// El bloque de Notificaciones cuenta como una fila de la cola (CA-019-06):
  /// un solo aviso de error, aparte del de bloqueo.
  int? _notificationsNotice;

  /// Un intento de encender rechazado por el sistema (CA-019-08): el aviso de
  /// bloqueo se ve hasta salir de Ajustes, encender con éxito o volver con las
  /// notificaciones permitidas. (Con el ajuste guardado encendido, el aviso
  /// sale solo del reflejo del sistema, CA-019-09.)
  bool _blockedAttempt = false;

  /// El aviso de que no se pudieron abrir los ajustes del sistema.
  int? _openSystemError;
  bool _openingSystem = false;

  /// La página de Idioma se está abriendo: otro toque no hace nada (CL-015-1).
  bool _openingLanguage = false;

  @override
  void initState() {
    super.initState();
    _system = ref.read(systemAllowsNotificationsProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    // Lo que permite el sistema se lee al abrir Ajustes y cada vez que la app
    // vuelve a primer plano con Ajustes abierto (CA-019-09); nunca antes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshSystem());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshSystem());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Al salir, lo leído ya no vale: la próxima apertura empieza sin leer.
    final system = _system;
    scheduleMicrotask(system.forget);
    _session.dispose();
    _language.node.dispose();
    _notifications.node.dispose();
    _privacy.node.dispose();
    _licenses.node.dispose();
    _help.node.dispose();
    super.dispose();
  }

  /// Quita los dos avisos de guardado (al salir del nivel o al abrir una web
  /// con éxito).
  void _clearSaveNotices() {
    if (!mounted ||
        (_keepAwakeNotice == null &&
            _lockZoomNotice == null &&
            _notificationsNotice == null)) {
      return;
    }
    setState(() {
      _keepAwakeNotice = null;
      _lockZoomNotice = null;
      _notificationsNotice = null;
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
      case SaveResult.blocked:
        // Otro guardado de esta fila en curso: este toque se ignoró. (`blocked`
        // es solo de Notificaciones, que tiene su propio bloque.)
        break;
    }
  }

  /// ¿Se ve el aviso de bloqueo? Tras un intento rechazado, o con el ajuste
  /// guardado encendido y el sistema bloqueando (CA-019-08, 09).
  bool _blockedVisible() =>
      _blockedAttempt ||
      (ref.read(settingsProvider).notificationsOn &&
          ref.read(systemAllowsNotificationsProvider) == false);

  /// Quita el aviso de bloqueo y el de que no se pudo abrir el sistema.
  void _clearBlocked() {
    _blockedAttempt = false;
    _openSystemError = null;
  }

  /// Enciende o apaga "Notificaciones" (spec 019): el interruptor se ve
  /// encendido solo con el ajuste guardado **y** el sistema permitiéndolo
  /// (CA-019-02, 09), así que tocarlo apaga lo que se ve encendido y en
  /// cualquier otro caso intenta encender. Todo lo demás (permiso, guardado,
  /// marcha atrás) lo hace el controlador; el interruptor se mueve cuando
  /// termina. Aquí se dibuja el resultado:
  ///
  /// - **bloqueado** (CA-019-08): aviso con su botón, que se anuncia (cada
  ///   intento);
  /// - **guardado**: quita los avisos (el de bloqueo, el de error y el de
  ///   enlace); si el sistema mostró su diálogo se anuncia «Notificaciones
  ///   activadas.» (el lector no habría dicho el cambio, CA-019-07);
  /// - **fallo**: el aviso de error del bloque (CA-019-06).
  Future<void> _toggleNotifications() async {
    final shownOn =
        ref.read(settingsProvider).notificationsOn &&
        ref.read(systemAllowsNotificationsProvider) != false;
    final (result, :dialogShown) = await ref
        .read(settingsProvider.notifier)
        .setNotificationsOn(!shownOn);
    if (!mounted) return;
    switch (result) {
      case SaveResult.saved:
        setState(() {
          _clearBlocked();
          _notificationsNotice = null;
        });
        _session.clearLinkNotice();
        if (!shownOn && dialogShown) {
          _notificationsBlock.currentState?.announce(
            (l10n) => l10n.settingsNotificationsEnabledAnnounce,
          );
        }
      case SaveResult.failed:
        setState(() {
          // Si ahora el sistema deja notificar, el aviso de bloqueo ya no es
          // verdad.
          if (ref.read(systemAllowsNotificationsProvider) == true) {
            _clearBlocked();
          }
          _notificationsNotice = ++_noticeSeq;
        });
      case SaveResult.blocked:
        setState(() => _blockedAttempt = true);
        _notificationsBlock.currentState?.announce(
          (l10n) => l10n.settingsNotificationsBlocked,
        );
      case SaveResult.unchanged:
        // Otro guardado de esta fila en curso: este toque se ignoró.
        break;
    }
  }

  /// Cambia cuántas notificaciones al día (CA-019-03); gana la última si hay
  /// varios toques seguidos. Un fallo pone el aviso de error del bloque; un
  /// guardado correcto lo quita.
  Future<void> _pickNotificationsPerDay(NotificationsPerDay value) async {
    final result = await ref
        .read(settingsProvider.notifier)
        .setNotificationsPerDay(value);
    if (!mounted) return;
    switch (result) {
      case SaveResult.saved:
        setState(() => _notificationsNotice = null);
        _session.clearLinkNotice();
      case SaveResult.failed:
        setState(() => _notificationsNotice = ++_noticeSeq);
      case SaveResult.unchanged:
      case SaveResult.blocked:
        break;
    }
  }

  /// Lee lo que permite el sistema (al abrir y al volver a primer plano). Si el
  /// aviso de bloqueo se veía y ahora las notificaciones están permitidas, se
  /// quita y se anuncia «permitidas» (o «permitidas y activadas» si el ajuste
  /// guardado está encendido y vuelve a verse encendido); el foco pasa al
  /// interruptor si lo tenía el botón (lo hace el bloque). La primera lectura
  /// y las de una petición de permiso en curso no anuncian (CA-019-09).
  Future<void> _refreshSystem() async {
    if (!ref.read(notificationsAvailableProvider)) return;
    final announce = await _system.refresh();
    if (!mounted || !announce) return;
    final on = ref.read(settingsProvider).notificationsOn;
    // La transición «bloqueadas → permitidas» solo se anuncia con el aviso a
    // la vista: tras un intento rechazado o con el ajuste guardado encendido.
    if (!_blockedAttempt && !on) return;
    setState(_clearBlocked);
    _notificationsBlock.currentState?.announce(
      (l10n) => on
          ? l10n.settingsNotificationsAllowedOnAnnounce
          : l10n.settingsNotificationsAllowedAnnounce,
    );
  }

  /// Abre los ajustes de notificaciones de esta app en el sistema (una petición
  /// por toque); si no hay a dónde ir, avisa (CA-019-08).
  Future<void> _openSystemSettings() async {
    if (_openingSystem) return;
    _openingSystem = true;
    var opened = false;
    try {
      opened = await ref.read(notificationGatewayProvider).openSystemSettings();
    } on Object {
      // Sin texto del error (CA-019-23).
    } finally {
      _openingSystem = false;
    }
    if (!mounted) return;
    setState(() => _openSystemError = opened ? null : ++_noticeSeq);
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
    // Para que el aviso de bloqueo siga lo que permite el sistema.
    ref.watch(systemAllowsNotificationsProvider);
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
            // Bloque 1: Idioma y, debajo, Notificaciones (spec 019). Sin la
            // fila (web, iOS o indicador apagado) el bloque queda como en la
            // 017: ni separador ni hueco de más.
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
                if (ref.watch(notificationsAvailableProvider))
                  NotificationsBlock(
                    key: _notificationsBlock,
                    focusNode: _notifications.node,
                    semanticsKey: _notifications.key,
                    onToggle: () => unawaited(_toggleNotifications()),
                    onPick: (value) =>
                        unawaited(_pickNotificationsPerDay(value)),
                    blocked: _blockedVisible(),
                    onOpenSystemSettings: () =>
                        unawaited(_openSystemSettings()),
                    openError: _openSystemError,
                    saveError: _notificationsNotice,
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
