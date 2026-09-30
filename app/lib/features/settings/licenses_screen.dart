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

class _LicenseList extends StatelessWidget {
  const _LicenseList(this.packages);

  final List<LicensePackage> packages;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        UnaSpace.l,
        UnaSpace.s,
        UnaSpace.l,
        UnaSpace.xl + bottom,
      ),
      itemCount: packages.length,
      itemBuilder: (context, i) =>
          _LicenseRow(packages[i], divider: i > 0, key: ValueKey(i)),
    );
  }
}

/// Una fila de la lista: el nombre y, debajo, cuántas licencias tiene. Botón
/// para el lector ("nombre, N licencias"); con el teclado, anillo de foco. Al
/// volver del nivel 3, recupera el foco (tabla de niveles de la spec).
class _LicenseRow extends StatefulWidget {
  const _LicenseRow(this.package, {super.key, required this.divider});

  final LicensePackage package;
  final bool divider;

  @override
  State<_LicenseRow> createState() => _LicenseRowState();
}

class _LicenseRowState extends State<_LicenseRow> {
  final _focus = FocusNode(debugLabel: 'license row');
  final _key = GlobalKey();
  bool _focused = false;

  /// Se está abriendo: un segundo toque no hace nada (CL-012-2).
  bool _busy = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy) return;
    _busy = true;
    final back = settingsTransition(context);
    await Navigator.of(context).push(
      settingsRoute<void>(
        context,
        (_) => LicenseDetailScreen(package: widget.package),
      ),
    );
    if (!mounted) return;
    requestFocusAfter(
      after: back,
      isMounted: () => mounted,
      node: _focus,
      semantics: _key,
    );
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = widget.package.name;
    // Sin texto legible sale igualmente "1 licencia" (CL-012-10).
    final count = l10n.licensesCount(
      widget.package.licenseCount < 1 ? 1 : widget.package.licenseCount,
    );
    return Semantics(
      key: _key,
      button: true,
      label: '$name, $count',
      excludeSemantics: true,
      onTap: _open,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _open,
          focusNode: _focus,
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
