import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.g.dart';
import '../../domain/entities/notification_settings.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/focus_ring.dart';
import '../../ui/live_notice.dart';
import '../../ui/live_region_announcer.dart';
import '../../ui/radio_row.dart';
import '../../ui/request_focus.dart';
import '../../ui/una_icons.dart';
import '../../ui/una_sheet.dart';
import '../../ui/una_switch_row.dart';
import 'notifications_state.dart';
import 'settings_controller.dart';

/// El bloque de Notificaciones de Ajustes (spec 019, tablero 16; CA-019-01 a
/// 04, 26 y 29): **un único widget** que va bajo "Idioma", en su mismo bloque.
/// De arriba abajo:
///
/// - la **fila** con la campana y el interruptor ([UnaSwitchRow]);
/// - la **línea de privacidad**, siempre a la vista (apagado, encendido o
///   bloqueado; CA-019-29): una parada del lector tras la fila, no del teclado;
/// - el **acordeón** con el grupo «Notificaciones al día» (tres botones propios
///   1·2·3, grupo de selección única) y la **ayuda con las horas**, solo con el
///   interruptor encendido. Plegado no se construye (nada de `Offstage`) y
///   durante el repliegue no se ve para el lector ni se alcanza con el teclado.
///
/// El interruptor se ve **encendido** solo si el ajuste guardado está
/// encendido **y** el sistema deja notificar (CA-019-02, 09): un valor guardado
/// que el sistema bloquea no se borra, pero tampoco se enseña como activo.
///
/// Los guardados los hace [onToggle] / [onPick] (la pantalla, que dibuja los
/// avisos); aquí no hay estado optimista: el interruptor y la marca cambian
/// cuando el controlador termina y cambia el ajuste.
///
/// La frase de la ayuda se anuncia **solo al cambiar de opción** (CA-019-04):
/// un [LiveRegionNode] de 1 × 1, nacido vacío, hermano del texto de la ayuda
/// (que es un `Text` normal, parada del lector pero no de Tab). Desplegar el
/// acordeón no anuncia nada.
///
/// Tras la ayuda, si [blocked], el **aviso de bloqueo** (CA-019-08 y 09): un
/// `Text` estático (no es una región viva: se anuncia por el mismo anunciador,
/// solo tras un intento rechazado, vía [NotificationsBlockState.announce]) con
/// un [UnaLinkButton] que abre los ajustes del sistema; si no hay a dónde ir,
/// [openError] pone el aviso «No se pudieron abrir los Ajustes del sistema.».
/// Al final, el aviso de error de guardado del bloque ([saveError], CA-019-06).
/// Cuando el aviso de bloqueo se quita con el foco en su botón, o se pliega la
/// opción que lo tenía, el foco pasa al interruptor.
class NotificationsBlock extends ConsumerStatefulWidget {
  const NotificationsBlock({
    super.key,
    required this.focusNode,
    required this.semanticsKey,
    required this.onToggle,
    required this.onPick,
    this.blocked = false,
    this.onOpenSystemSettings,
    this.openError,
    this.saveError,
  });

  /// La marca de selección de la opción elegida (para los tests).
  static const markKey = ValueKey<String>('notifications-option-mark');

  /// La opción [value] (para los tests): su zona táctil entera.
  static ValueKey<String> optionKey(NotificationsPerDay value) =>
      ValueKey<String>('notifications-option-${value.count}');

  /// Foco de teclado del interruptor y clave de su nodo accesible: la pantalla
  /// se los devuelve cuando un aviso o una opción que se pliega lo tenían.
  final FocusNode focusNode;
  final GlobalKey semanticsKey;

  /// Se llama al tocar la fila: **no** cambia nada por sí sola.
  final VoidCallback onToggle;

  /// Se llama al tocar una opción distinta de la marcada.
  final ValueChanged<NotificationsPerDay> onPick;

  /// ¿Se ve el aviso de bloqueo con su botón? (Lo decide la pantalla.)
  final bool blocked;

  /// Se llama al tocar «Abrir los ajustes de notificaciones».
  final VoidCallback? onOpenSystemSettings;

  /// El número del intento fallido de abrir los ajustes del sistema, o `null`
  /// si no hay aviso (es la clave del `LiveNotice`).
  final int? openError;

  /// El número del intento fallido de guardar, o `null` si no hay aviso.
  final int? saveError;

  @override
  ConsumerState<NotificationsBlock> createState() => NotificationsBlockState();
}

/// La sangría de lo que cuelga de la fila: debajo del nombre (icono + hueco +
/// la sangría lateral de la fila), como el acordeón del prototipo (42).
const _indent = UnaSpace.xs + UnaSizes.icon + UnaSpace.m;

/// El hueco entre el encabezado, las opciones y la ayuda (prototipo: 10).
const _gap = UnaSpace.s + UnaSpace.xxs;

class NotificationsBlockState extends ConsumerState<NotificationsBlock> {
  /// Un foco por opción: viven con el bloque (no con el acordeón, que se
  /// desmonta plegado) para poder preguntar si una tenía el foco al plegarse.
  final _options = {
    for (final v in NotificationsPerDay.values)
      v: FocusNode(debugLabel: 'notifications per day ${v.count}'),
  };

  /// Lo que se anuncia: la ayuda al cambiar de opción (CA-019-04) y los avisos
  /// del permiso (CA-019-07 a 09). Región viva de 1 × 1, nacida vacía.
  final _announcer = LiveRegionAnnouncer();

  /// El foco y la clave del botón del aviso de bloqueo.
  final _openFocus = FocusNode(debugLabel: 'notifications open system');
  final _openKey = GlobalKey();

  /// ¿Estaban desplegadas las opciones en la última construcción? Para saber
  /// si una opción con el foco se pliega por el bloqueo.
  bool? _wasShownOn;

  /// Dice [message] (en el idioma de la app, al decirlo) con la región viva y
  /// la cadencia de los demás avisos: tras el antirrebote
  /// ([DebouncedAnnouncer.debounce], que es lo que se espera tras mover el
  /// foco, `UnaMotion.announceAfterFocus`), con la última frase si hay varias
  /// seguidas.
  void announce(String Function(AppLocalizations l10n) message) {
    _announcer.announce(
      () => mounted ? message(AppLocalizations.of(context)) : '',
    );
  }

  @override
  void didUpdateWidget(NotificationsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El aviso se quita con el foco en su botón: el botón desaparece y el foco
    // pasa al interruptor (CA-019-08). Se mira ahora, con el botón aún montado.
    if (oldWidget.blocked && !widget.blocked && _openFocus.hasFocus) {
      _focusSwitch();
    }
  }

  void _focusSwitch() => requestFocusAfter(
    after: Duration.zero,
    isMounted: () => mounted,
    node: widget.focusNode,
    semantics: widget.semanticsKey,
  );

  @override
  void dispose() {
    _announcer.dispose();
    _openFocus.dispose();
    for (final node in _options.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _help(AppLocalizations l10n, NotificationsPerDay value) {
    final t = [for (final time in value.times) time.label];
    return switch (value) {
      NotificationsPerDay.one => l10n.settingsNotificationsHelp1(t[0]),
      NotificationsPerDay.two => l10n.settingsNotificationsHelp2(t[0], t[1]),
      NotificationsPerDay.three => l10n.settingsNotificationsHelp3(
        t[0],
        t[1],
        t[2],
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(settingsProvider.select((s) => s.notificationsOn));
    final perDay = ref.watch(
      settingsProvider.select((s) => s.notificationsPerDay),
    );
    // `null` = aún sin leer: se ve el valor guardado (CA-019-09).
    final systemAllows = ref.watch(systemAllowsNotificationsProvider);
    final shownOn = on && systemAllows != false;
    // Una opción con el foco se pliega porque el sistema bloquea: el foco pasa
    // al interruptor (se mira antes de que el acordeón se pliegue).
    if (_wasShownOn == true &&
        !shownOn &&
        _options.values.any((node) => node.hasFocus)) {
      _focusSwitch();
    }
    _wasShownOn = shownOn;
    // Cambiar de opción anuncia la ayuda nueva, una sola vez y con el último
    // cambio si hay varios seguidos. Desplegar no cambia la cantidad: no dice
    // nada.
    ref.listen(settingsProvider.select((s) => s.notificationsPerDay), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _announcer.announce(
        () => mounted
            ? _help(
                AppLocalizations.of(context),
                ref.read(settingsProvider).notificationsPerDay,
              )
            : '',
      );
    });
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UnaSwitchRow(
              icon: UnaIcons.bell,
              label: l10n.settingsNotifications,
              value: shownOn,
              divider: true,
              focusNode: widget.focusNode,
              semanticsKey: widget.semanticsKey,
              onToggle: widget.onToggle,
            ),
            // La línea de privacidad: siempre, también apagado (CA-019-29).
            Padding(
              padding: const EdgeInsets.only(
                left: _indent,
                right: UnaSpace.xs,
                top: UnaSpace.xs,
                bottom: UnaSpace.sm,
              ),
              child: Text(l10n.settingsNotificationsPrivacy, style: _smallText),
            ),
            _Accordion(
              open: shownOn,
              builder: (context) => Padding(
                padding: const EdgeInsets.only(
                  left: _indent,
                  right: UnaSpace.xs,
                  top: UnaSpace.xxs,
                  bottom: UnaSpace.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Visible, pero no se lee aparte: es el nombre del grupo.
                    ExcludeSemantics(
                      child: Text(
                        l10n.settingsNotificationsPerDay.toUpperCase(),
                        style: _groupLabel,
                      ),
                    ),
                    const SizedBox(height: _gap),
                    UnaRadioGroup(
                      label: l10n.settingsNotificationsPerDay,
                      child: _PerDayOptions(
                        selected: perDay,
                        nodes: _options,
                        onPick: widget.onPick,
                      ),
                    ),
                    const SizedBox(height: _gap),
                    Text(_help(l10n, perDay), style: _smallText),
                  ],
                ),
              ),
            ),
            // Los dos avisos son huecos siempre presentes del mismo tipo: al
            // ponerse o quitarse no recrean las filas de debajo ni su foco.
            _BlockedSlot(
              blocked: widget.blocked,
              focusNode: _openFocus,
              semanticsKey: _openKey,
              onOpen: widget.onOpenSystemSettings ?? () {},
              openError: widget.openError,
            ),
            _ErrorSlot(attempt: widget.saveError),
          ],
        ),
        // 1 × 1 en la esquina: no ocupa sitio ni es parada de foco.
        Positioned(
          left: 0,
          bottom: 0,
          child: LiveRegionNode(announcer: _announcer),
        ),
      ],
    );
  }
}

/// El respiro de un aviso de error bajo el bloque (como los de las demás
/// filas de Ajustes).
const _noticePadding = EdgeInsets.only(
  top: UnaSpace.m,
  left: UnaSpace.xs,
  right: UnaSpace.xs,
  bottom: UnaSpace.s,
);

/// El hueco del aviso de bloqueo: nada, o el texto estático, el botón que abre
/// los ajustes del sistema y, si no hay a dónde ir, su aviso de error.
class _BlockedSlot extends StatelessWidget {
  const _BlockedSlot({
    required this.blocked,
    required this.focusNode,
    required this.semanticsKey,
    required this.onOpen,
    required this.openError,
  });

  final bool blocked;
  final FocusNode focusNode;
  final GlobalKey semanticsKey;
  final VoidCallback onOpen;
  final int? openError;

  @override
  Widget build(BuildContext context) {
    if (!blocked) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final openError = this.openError;
    return Padding(
      padding: const EdgeInsets.only(
        left: _indent,
        right: UnaSpace.xs,
        bottom: UnaSpace.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Texto estático: lo anuncia el anunciador tras un intento
          // rechazado, no al aparecer (CA-019-09).
          Text(l10n.settingsNotificationsBlocked, style: _smallText),
          UnaLinkButton(
            label: l10n.settingsNotificationsOpenSystem,
            onPressed: onOpen,
            focusNode: focusNode,
            semanticsKey: semanticsKey,
          ),
          if (openError != null)
            LiveNotice(
              text: l10n.settingsNotificationsOpenError,
              attempt: openError,
              padding: const EdgeInsets.only(top: UnaSpace.xs),
            ),
        ],
      ),
    );
  }
}

/// El hueco del aviso de error de guardado del bloque (CA-019-06).
class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.attempt});

  final int? attempt;

  @override
  Widget build(BuildContext context) {
    final attempt = this.attempt;
    if (attempt == null) return const SizedBox.shrink();
    return LiveNotice(
      text: AppLocalizations.of(context).settingsSaveError,
      attempt: attempt,
      padding: _noticePadding,
    );
  }
}

/// La línea de privacidad y la ayuda (prototipo: monoespaciada de 12, `#55534E`).
const _smallText = TextStyle(
  fontFamily: UnaFonts.mono,
  fontSize: UnaFontSizes.tag,
  fontWeight: UnaFontWeights.regular,
  height: 1.45,
  color: UnaColors.textMuted,
);

/// «NOTIFICACIONES AL DÍA» (prototipo: monoespaciada de 12, negrita, 0,06 em).
const _groupLabel = TextStyle(
  fontFamily: UnaFonts.mono,
  fontSize: UnaFontSizes.tag,
  fontWeight: UnaFontWeights.bold,
  letterSpacing: UnaFontSizes.tag * UnaLetterSpacing.groupLabel,
  height: 1.3,
  color: UnaColors.ink,
);

/// El acordeón: lo que cuelga del interruptor se **construye solo abierto** (ni
/// `Offstage` ni alto cero) y, mientras se pliega, **no se ve para el lector ni
/// se alcanza con el teclado ni con el toque** desde el primer fotograma. Con
/// "reducir movimiento" aparece y desaparece sin ninguna animación, ni de alto
/// ni de opacidad (CA-019-03).
class _Accordion extends StatefulWidget {
  const _Accordion({required this.open, required this.builder});

  final bool open;
  final WidgetBuilder builder;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: UnaMotion.accordion,
    value: widget.open ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: UnaMotion.sheetCurve,
  );

  @override
  void didUpdateWidget(_Accordion old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.open ? 1 : 0;
    } else if (widget.open) {
      unawaited(_controller.forward());
    } else {
      unawaited(_controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (!widget.open && _controller.isDismissed) {
        return const SizedBox.shrink();
      }
      final folding = !widget.open;
      return FadeTransition(
        opacity: _curve,
        child: SizeTransition(
          sizeFactor: _curve,
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            ignoring: folding,
            child: ExcludeSemantics(
              excluding: folding,
              child: ExcludeFocus(
                excluding: folding,
                child: widget.builder(context),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Los tres botones 1 · 2 · 3 de igual ancho (prototipo: caja de 44 con borde de
/// 3 y esquinas de 8). Cada uno tiene una **zona táctil de 48** (la caja visible
/// de 44, o más con el texto grande, queda dentro, 2 arriba y 2 abajo) y, en
/// el lector, es un botón de radio de un grupo de selección única.
///
/// Tres botones propios (patrón de [UnaRadioRow]), no `Radio`, `SegmentedButton`
/// ni `ToggleButtons`: esos seleccionan al mover el foco con las flechas y aquí
/// las flechas solo mueven el foco; Intro y Espacio seleccionan (CA-019-26).
class _PerDayOptions extends StatelessWidget {
  const _PerDayOptions({
    required this.selected,
    required this.nodes,
    required this.onPick,
  });

  final NotificationsPerDay selected;
  final Map<NotificationsPerDay, FocusNode> nodes;
  final ValueChanged<NotificationsPerDay> onPick;

  static const _values = NotificationsPerDay.values;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
    child: Stack(
      children: [
        // La caja visible: relleno, separadores y borde (solo para la vista).
        Positioned.fill(
          top: (kMinInteractiveDimension - UnaSizes.minTouchTarget) / 2,
          bottom: (kMinInteractiveDimension - UnaSizes.minTouchTarget) / 2,
          child: ExcludeSemantics(
            child: IgnorePointer(child: _Frame(selected: selected)),
          ),
        ),
        // Las zonas táctiles, encima, sobre las mismas columnas que la caja
        // (dentro de su borde).
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: UnaBorders.strongWidth,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final value in _values)
                  Expanded(
                    child: _Option(
                      key: NotificationsBlock.optionKey(value),
                      value: value,
                      selected: value == selected,
                      focusNode: nodes[value]!,
                      onTap: () {
                        if (value != selected) onPick(value);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// La caja de las opciones: borde de tinta de 3 con esquinas de 8, y en cada
/// columna el relleno amarillo si es la marcada y, entre columnas, la línea de
/// tinta de 3.
class _Frame extends StatelessWidget {
  const _Frame({required this.selected});

  final NotificationsPerDay selected;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: const Border.fromBorderSide(
        BorderSide(color: UnaColors.ink, width: UnaBorders.strongWidth),
      ),
      borderRadius: BorderRadius.circular(UnaBorders.optionGroupRadius),
    ),
    child: Row(
      children: [
        for (final (i, value) in NotificationsPerDay.values.indexed)
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: value == selected ? UnaColors.switchOn : null,
                border: i == 0
                    ? null
                    : const Border(
                        left: BorderSide(
                          color: UnaColors.ink,
                          width: UnaBorders.strongWidth,
                        ),
                      ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    ),
  );
}

/// Un botón de la cantidad: el número, y en la marcada la **marca de selección**
/// (la misma de la página de Idioma). La marca y el peso 900 son lo que la
/// distingue sin depender del color (WCAG 1.4.1); el hueco de la marca está
/// siempre reservado, así que el número no se mueve al elegir.
class _Option extends StatefulWidget {
  const _Option({
    super.key,
    required this.value,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });

  final NotificationsPerDay value;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      checked: widget.selected,
      inMutuallyExclusiveGroup: true,
      focusable: true,
      focused: _focused,
      // El nombre contiene el número visible (WCAG 2.5.3).
      label: l10n.settingsNotificationsOption(widget.value.count),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          highlightColor: UnaColors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: FocusRing(
            inside: true,
            visible: _focused && showsFocusHighlight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.value.count}',
                      style: TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.option,
                        fontWeight: widget.selected
                            ? UnaFontWeights.black
                            : UnaFontWeights.semibold,
                        height: 1.15,
                        color: UnaColors.ink,
                      ),
                    ),
                    const SizedBox(width: UnaSpace.s),
                    SizedBox.square(
                      dimension: UnaSizes.icon,
                      child: widget.selected
                          ? const UnaIcon(
                              UnaIcons.check,
                              key: NotificationsBlock.markKey,
                              strokeWidth: UnaSizes.iconStrokeBold,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
