import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/license_package.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/focus_ring.dart';
import '../../ui/request_focus.dart';
import 'license_detail_screen.dart';
import 'license_names.dart';
import 'settings_page.dart';
import 'settings_route.dart';

/// Cuánto debe durar la carga para que se anuncie "Cargando licencias…": si la
/// lista llega antes, el lector no oye nada (plan §8, CA-012-15).
const licensesLoadingAnnounceDelay = Duration(milliseconds: 200);

/// Nivel 2 de la Configuración: la lista de licencias de código abierto (spec
/// 012, CA-012-03). Se lee solo al abrirla (CA-012-16). Mientras carga, dice
/// "Cargando licencias…"; si falla (o no hay ninguna), el error con
/// "Reintentar", que recibe el foco (CA-012-15).
class LicensesScreen extends ConsumerStatefulWidget {
  const LicensesScreen({super.key});

  @override
  ConsumerState<LicensesScreen> createState() => _LicensesScreenState();
}

class _LicensesScreenState extends ConsumerState<LicensesScreen> {
  final _titleFocus = FocusNode(debugLabel: 'licenses title');
  final _titleKey = GlobalKey();

  /// Cada intento tiene su propio estado de error: si vuelve a fallar, el
  /// botón vuelve a recibir el foco.
  int _attempt = 0;

  @override
  void dispose() {
    _titleFocus.dispose();
    super.dispose();
  }

  /// Vuelve a leer y lleva el foco al título: el botón desaparece al empezar a
  /// cargar (CA-012-15).
  void _retry() {
    setState(() => _attempt++);
    ref.invalidate(licensesProvider);
    _focusNextFrame(() => mounted, _titleFocus, _titleKey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final licenses = ref.watch(licensesProvider);
    return SettingsPage(
      title: l10n.licensesTitle,
      root: false,
      titleFocus: _titleFocus,
      titleKey: _titleKey,
      child: licenses.isLoading
          ? const _Loading()
          : licenses.hasError
          ? _LoadError(key: ValueKey(_attempt), onRetry: _retry)
          : _LicenseList(licenses.requireValue),
    );
  }
}

/// Lleva el foco (teclado y lector) a [node] al terminar el fotograma actual.
/// Sin espera: aquí no hay transición de vuelta (a diferencia de
/// `requestFocusAfter`), y así el orden entre "al título" y "a Reintentar" es el
/// de los fotogramas en que ocurren.
void _focusNextFrame(bool Function() isMounted, FocusNode node, GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isMounted()) return;
    node.requestFocus();
    key.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  });
}

/// El texto de estado bajo el título (cargando, error), en monoespaciada.
class _Status extends StatelessWidget {
  const _Status(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: UnaTheme.mono.copyWith(color: UnaColors.ink, height: 1.5),
    );
  }
}

/// Margen de los estados de carga y error; abajo suma el borde del sistema
/// (la página no lo reserva).
EdgeInsets _statusPadding(BuildContext context) => EdgeInsets.fromLTRB(
  UnaSpace.l,
  UnaSpace.m,
  UnaSpace.l,
  UnaSpace.l + MediaQuery.paddingOf(context).bottom,
);

/// "Cargando licencias…", que se anuncia solo si la carga dura más que el
/// umbral y no se anuncia si la pantalla ya se ha cerrado.
class _Loading extends StatefulWidget {
  const _Loading();

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(licensesLoadingAnnounceDelay, _announce);
  }

  void _announce() {
    // Si ya se está saliendo, la carga no se ve: no se anuncia.
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context).licensesLoading,
        Directionality.of(context),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _statusPadding(context),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: _Status(AppLocalizations.of(context).licensesLoading),
      ),
    );
  }
}

/// El error de lectura con "Reintentar". El botón recibe el foco nada más
/// aparecer y lleva el error como pista, para que el lector lo diga al llegar.
class _LoadError extends StatefulWidget {
  const _LoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<_LoadError> createState() => _LoadErrorState();
}

class _LoadErrorState extends State<_LoadError> {
  final _focus = FocusNode(debugLabel: 'licenses retry');
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focusNextFrame(() => mounted, _focus, _key);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: _statusPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Status(l10n.licensesError),
          const SizedBox(height: UnaSpace.l),
          BrutalButton(
            label: l10n.retry,
            hint: l10n.licensesError,
            focusNode: _focus,
            semanticsKey: _key,
            onPressed: widget.onRetry,
          ),
        ],
      ),
    );
  }
}

/// La lista de filas. Guarda **por nombre** el `FocusNode` de cada fila, no las
/// filas: la lista es perezosa y, con el nivel 3 abierto, el nivel 2 no se
/// dibuja, así que una fila que cambia de sitio con el idioma puede destruirse y
/// reconstruirse lejos. Con el foco aquí, la fila nueva lo vuelve a adoptar y el
/// foco (teclado y lector) sigue en la misma entrada (CA-013-02, plan P-013-3).
///
/// La `GlobalKey` del nodo accesible **no** se guarda aquí: reutilizar una clave
/// global en una fila destruida y reconstruida hace saltar una aserción del
/// árbol semántico de Flutter (visto con texto al 200 %). Cada fila crea la
/// suya y se registra en [_rows] mientras existe.
class _LicenseList extends StatefulWidget {
  const _LicenseList(this.packages);

  final List<LicensePackage> packages;

  @override
  State<_LicenseList> createState() => _LicenseListState();
}

class _LicenseListState extends State<_LicenseList> {
  final _scroll = ScrollController();
  final _focusNodes = <String, FocusNode>{};
  final _rows = <String, _LicenseRowState>{};

  /// Orden y posición de cada nombre: se recalculan solo si cambian la lista o
  /// el idioma.
  List<LicensePackage> _sorted = const [];
  Map<String, int> _indexOf = const {};
  List<LicensePackage>? _sortedFrom;
  Locale? _sortedLocale;

  /// El idioma visto por última vez en `didChangeDependencies` (`didUpdateWidget`
  /// llega antes y no debe ocultar el cambio).
  Locale? _seenLocale;

  /// La fila cuyo nivel 3 está abierto (un segundo toque no hace nada,
  /// CL-012-2).
  String? _openName;

  FocusNode _focusOf(String name) =>
      _focusNodes.putIfAbsent(name, () => FocusNode(debugLabel: 'license row'));

  /// El nombre de la fila que tiene el foco de teclado, si alguna.
  String? _focusedName() {
    for (final MapEntry(:key, :value) in _focusNodes.entries) {
      if (value.hasFocus) return key;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo cuenta un cambio de idioma: un giro de pantalla (otro `MediaQuery`)
    // no debe mover el desplazamiento.
    final locale = Localizations.localeOf(context);
    final changed = _seenLocale != null && _seenLocale != locale;
    _seenLocale = locale;
    _resort(locale);
    if (!changed || _openName != null) return;
    // Con el nivel 3 abierto no se hace nada: `_open` coloca la fila al volver.
    final name = _focusedName();
    if (name != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(name, then: () => _focusRow(name));
      });
    }
  }

  @override
  void didUpdateWidget(_LicenseList old) {
    super.didUpdateWidget(old);
    _resort(Localizations.localeOf(context));
  }

  void _resort(Locale locale) {
    if (identical(_sortedFrom, widget.packages) && _sortedLocale == locale) {
      return;
    }
    _sortedFrom = widget.packages;
    _sortedLocale = locale;
    _sorted = sortedForDisplay(AppLocalizations.of(context), widget.packages);
    _indexOf = {for (final (i, p) in _sorted.indexed) p.name: i};
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Lleva la fila de [name] a la vista (sin animación, como "reducir
  /// movimiento") y llama a [then]. Si no está construida, salta a su posición
  /// estimada y lo vuelve a intentar con ella ya construida.
  void _reveal(String name, {required VoidCallback then}) {
    void ensureVisible() {
      final context = _rows[name]?.context;
      if (context == null) return;
      // Cada política solo desplaza en un sentido (hacia delante, la una; hacia
      // atrás, la otra) y no hace nada si la fila ya se ve: juntas cubren una
      // fila que baja (bajo la ventana) y una que sube (sobre ella, F-2).
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(
          context,
          duration: Duration.zero,
          alignmentPolicy: policy,
        );
      }
    }

    if (_rows[name] != null) {
      ensureVisible();
      then();
      return;
    }
    final index = _indexOf[name];
    if (index == null || !_scroll.hasClients) return then();
    final position = _scroll.position;
    if (!position.hasContentDimensions) return then();
    final extent =
        (position.maxScrollExtent + position.viewportDimension) /
        _sorted.length;
    _scroll.jumpTo(
      (index * extent - (position.viewportDimension - extent) / 2).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ensureVisible();
      then();
    });
  }

  /// El foco de teclado y el del lector, en la fila de [name].
  void _focusRow(String name) {
    _focusOf(name).requestFocus();
    _rows[name]?.announceFocus();
  }

  Future<void> _open(LicensePackage package) async {
    final name = package.name;
    if (_openName != null) return;
    _openName = name;
    final back = settingsTransition(context);
    await Navigator.of(context).push(
      settingsRoute<void>(
        context,
        (_) => LicenseDetailScreen(package: package),
      ),
    );
    if (!mounted) return;
    // Al volver, la fila (que pudo moverse con el idioma) recupera el foco.
    Timer(back, () {
      if (!mounted) return;
      _reveal(
        name,
        then: () => requestFocusAfter(
          after: Duration.zero,
          isMounted: () => mounted,
          node: _focusOf(name),
          semantics: _rows[name]?.semanticsKey,
        ),
      );
    });
    _openName = null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        UnaSpace.l,
        UnaSpace.s,
        UnaSpace.l,
        UnaSpace.xl + bottom,
      ),
      itemCount: _sorted.length,
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? _indexOf[key.value] : null,
      itemBuilder: (context, i) {
        final package = _sorted[i];
        return _LicenseRow(
          package,
          divider: i > 0,
          key: ValueKey(package.name),
          focusNode: _focusOf(package.name),
          rows: _rows,
          onOpen: () => _open(package),
        );
      },
    );
  }
}

/// Una fila de la lista: el nombre y, debajo, cuántas licencias tiene. Botón
/// para el lector ("nombre, N licencias"); con el teclado, anillo de foco. El
/// foco y la apertura del nivel 3 son de la lista.
class _LicenseRow extends StatefulWidget {
  const _LicenseRow(
    this.package, {
    super.key,
    required this.divider,
    required this.focusNode,
    required this.rows,
    required this.onOpen,
  });

  final LicensePackage package;
  final bool divider;
  final FocusNode focusNode;
  final Map<String, _LicenseRowState> rows;
  final VoidCallback onOpen;

  @override
  State<_LicenseRow> createState() => _LicenseRowState();
}

class _LicenseRowState extends State<_LicenseRow> {
  late bool _focused = widget.focusNode.hasFocus;

  /// El nodo accesible de la fila (el del botón, no el de un antecesor).
  final semanticsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.rows[widget.package.name] = this;
  }

  @override
  void dispose() {
    if (identical(widget.rows[widget.package.name], this)) {
      widget.rows.remove(widget.package.name);
    }
    super.dispose();
  }

  /// Avisa al lector de que el foco está en esta fila.
  void announceFocus() {
    semanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = licenseDisplayName(l10n, widget.package);
    // Sin texto legible sale igualmente "1 licencia" (CL-012-10).
    final count = l10n.licensesCount(
      widget.package.licenseCount < 1 ? 1 : widget.package.licenseCount,
    );
    return Semantics(
      key: semanticsKey,
      button: true,
      label: '$name, $count',
      excludeSemantics: true,
      onTap: widget.onOpen,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onOpen,
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          highlightColor: UnaColors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: FocusRing(
            visible: _focused && showsFocusHighlight,
            child: Container(
              // Con texto grande, la fila crece.
              constraints: const BoxConstraints(
                minHeight: UnaSizes.sheetRowTall,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: UnaSpace.xs,
                vertical: UnaSpace.s,
              ),
              decoration: widget.divider
                  ? const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: UnaColors.disabled,
                          width: UnaBorders.hairlineWidth,
                        ),
                      ),
                    )
                  : null,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: UnaFonts.display,
                      fontSize: UnaFontSizes.bodyL,
                      fontWeight: UnaFontWeights.bold,
                      color: UnaColors.ink,
                    ),
                  ),
                  const SizedBox(height: UnaSpace.xxs),
                  Text(count, style: UnaTheme.mono),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
