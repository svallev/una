import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/link_target.dart';
import '../../domain/entities/web_load_failure.dart';
import '../../domain/services/host_display.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../ui/una_sheet.dart';
import 'web_bar.dart';
import 'web_page_controller.dart';
import 'web_page_driver_factory.dart';
import 'web_preview_card.dart';

/// Si la tarea web (por el id de su adjunto) muestra un aviso en lugar de la
/// página (spec 009 §5). Con aviso no gira, como con "Adjunto no disponible"
/// (CA-009-15).
final webNoticeProvider = NotifierProvider.autoDispose
    .family<WebNoticeShown, bool, String>(WebNoticeShown.new);

class WebNoticeShown extends Notifier<bool> {
  WebNoticeShown(this.attachmentId);

  final String attachmentId;

  @override
  bool build() => false;

  void report(bool shown) => state = shown;
}

/// La zona de la tarea web en la pantalla principal (CA-009-06): borde negro
/// arriba y abajo, la barra del dominio (que es el nodo de la tarea para el
/// lector, [taskNode]) y debajo la página en vivo, con la línea de carga, o
/// el aviso que la sustituye (spec 009 §5).
///
/// - **Primer fotograma sin WebView** (P2, plan §6): la barra se pinta con
///   Flutter; la WebView se crea tras el primer fotograma y empieza a cargar
///   cuando su vista ya está en pantalla.
/// - **Otra pantalla encima** (el editor, el listado): se quita la página y se
///   borran sus datos; al volver, se carga desde cero (CA-009-07, CA-009-13).
///   Una hoja (el menú, una confirmación, "Cargar URL") no tapa la tarea y no
///   recarga nada. Se sabe porque la ruta de la tarea queda fuera del
///   escenario (`TickerMode`) solo bajo una pantalla opaca.
/// - Al desmontarse (completar, eliminar, otra tarea, otra dirección) suelta
///   la página: deja de cargar y borra sus datos (CL-009-11).
///
/// Sin [live] (las caras de completar y eliminar, CA-009-17), solo la barra y
/// la zona en blanco, sin WebView. Si deja de estar en vivo (se empieza a
/// guardar la tarea completada), suelta la página en ese momento (CL-009-11);
/// si vuelve a estarlo (no se pudo guardar), la carga otra vez.
///
/// En horizontal ([landscapeLogo], CA-009-15), la página a sangre, sin barra
/// ni bordes, con el logotipo encima, que pasa a ser el nodo de la tarea. La
/// WebView es la misma: al girar no se vuelve a crear ni se recarga.
class TaskWeb extends ConsumerStatefulWidget {
  const TaskWeb({
    super.key,
    required this.attachmentId,
    required this.address,
    required this.taskNode,
    this.live = true,
    this.showBar = true,
    this.landscapeLogo,
  });

  /// El adjunto: con él se avisa de si hay un aviso ([webNoticeProvider]).
  final String attachmentId;

  /// La dirección guardada.
  final String address;

  /// Envuelve la barra en el nodo de la tarea con la lectura de [host]
  /// (CA-009-18).
  final Widget Function(Widget bar, String host) taskNode;

  /// Con la página en vivo (no en las caras de completar y eliminar, ni
  /// mientras se completa).
  final bool live;

  /// Sin la barra (lo que queda encima mientras se arruga).
  final bool showBar;

  /// En horizontal: el logotipo, ya colocado, que va encima de la página, con
  /// el nodo de la tarea para el dominio que se ve.
  final Widget Function(String host)? landscapeLogo;

  @override
  ConsumerState<TaskWeb> createState() => _TaskWebState();
}

class _TaskWebState extends ConsumerState<TaskWeb> {
  WebPageController? _page;

  /// Lo último que se vio de la página soltada: la barra no cambia al dejar
  /// de estar en vivo.
  WebPageState? _released;
  bool _started = false;
  bool _covered = false;
  ValueListenable<TickerModeData>? _onStage;
  WebLoadFailure? _announced;
  bool _noticeReported = false;

  late final Uri _address = Uri.parse(widget.address);

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _create());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onStage = TickerMode.getValuesNotifier(context);
    if (!identical(onStage, _onStage)) {
      _onStage?.removeListener(_onStageChanged);
      _onStage = onStage..addListener(_onStageChanged);
      _onStageChanged();
    }
  }

  /// Tras el primer fotograma: la WebView y su estado. Carga en el siguiente,
  /// con la vista ya puesta.
  void _create() {
    if (!mounted || !widget.live || _page != null) return;
    // La web de pruebas no tiene WebView (CL-009-5).
    if (ref.read(webPreviewProvider)) return;
    final page = WebPageController(
      address: _address,
      createDriver: ref.read(webPageDriverFactoryProvider),
      janitor: ref.read(webDataJanitorProvider),
      clock: ref.read(clockProvider),
    )..addListener(_onPage);
    setState(() => _page = page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(page, _page) || _covered) return;
      _started = true;
      unawaited(page.start());
    });
  }

  void _onStageChanged() {
    final covered = !(_onStage?.value.enabled ?? true);
    if (covered == _covered) return;
    _covered = covered;
    final page = _page;
    if (page == null) return;
    if (covered) {
      page.leave();
    } else if (_started) {
      unawaited(page.comeBack());
    } else {
      _started = true;
      unawaited(page.start());
    }
  }

  /// Cada aviso nuevo se anuncia una vez (CA-009-19), y la redirección de la
  /// carga inicial a otro dominio se avisa una vez (CL-009-1).
  void _onPage() {
    _showRedirectNotice();
    final failure = _page?.value.failure;
    _reportNotice(failure != null);
    if (failure == _announced) return;
    _announced = failure;
    if (failure == null || !mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _failureText(AppLocalizations.of(context), failure),
        Directionality.of(context),
      ),
    );
  }

  /// Con aviso, la pantalla principal no gira (CA-009-15). El controlador
  /// puede cambiar mientras se construye (al quedar tapada): entonces, al
  /// acabar el fotograma.
  void _reportNotice(bool shown) {
    if (shown == _noticeReported) return;
    _noticeReported = shown;
    void report() {
      if (!mounted) return;
      ref.read(webNoticeProvider(widget.attachmentId).notifier).report(shown);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report());
    } else {
      report();
    }
  }

  /// "Esta dirección te ha llevado a {host}." como los demás avisos
  /// pasajeros de la app (un `SnackBar`, que se anuncia solo).
  void _showRedirectNotice() {
    final page = _page;
    final host = page?.value.redirectNotice;
    if (page == null || host == null || !mounted) return;
    page.redirectNoticeShown();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).urlRedirected(host))),
    );
  }

  @override
  void didUpdateWidget(TaskWeb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live == widget.live) return;
    if (widget.live) {
      _released = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _create());
    } else {
      _release();
    }
  }

  /// Deja de cargar y borra los datos de la página (CL-009-11), con la zona
  /// en blanco y la barra como estaba.
  void _release() {
    final page = _page;
    if (page == null) return;
    _released = page.value;
    _page = null;
    _started = false;
    _announced = null;
    page
      ..removeListener(_onPage)
      ..dispose();
    _reportNotice(false);
  }

  @override
  void dispose() {
    _onStage?.removeListener(_onStageChanged);
    _page
      ?..removeListener(_onPage)
      ..dispose();
    super.dispose();
  }

  /// "Reintentar": vuelve a cargar la dirección guardada y lo anuncia.
  void _retry() {
    final page = _page;
    if (page == null) return;
    unawaited(page.retry());
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context).urlLoadingA11y,
        Directionality.of(context),
      ),
    );
  }

  /// "Abrir en el navegador": la dirección guardada, sin confirmar (spec 009
  /// §5). Si no hay navegador, no pasa nada (la tarea web ya no reutiliza el
  /// aviso de los enlaces del PDF, §7).
  void _openInBrowser(String host) {
    unawaited(ref.read(linkOpenerProvider).open(WebLink(_address, host)));
  }

  /// "Abrir página ↗" de la web de pruebas: la dirección guardada en una
  /// pestaña nueva (CL-009-5).
  void _openInNewTab() => ref.read(newTabOpenerProvider)(_address);

  /// El dominio de la barra: el de la página que se ve (o se carga).
  String _host(AppLocalizations l10n, Uri? pageUrl) {
    final shown = pageUrl == null || pageUrl.host.isEmpty
        ? ''
        : displayHost(pageUrl.host, dropWww: true);
    if (shown.isNotEmpty) return shown;
    return webAddressHost(widget.address) ?? l10n.attachmentWeb;
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    if (page == null) return _zone(context, null);
    return ListenableBuilder(
      listenable: page,
      builder: (context, _) => _zone(context, page),
    );
  }

  Widget _zone(BuildContext context, WebPageController? page) {
    final l10n = AppLocalizations.of(context);
    final state = page?.value;
    final shown = state ?? _released;
    final host = _host(l10n, shown?.pageUrl);
    // Soltada la página, sin aviso: la zona en blanco.
    final failure = state?.failure;
    // La web de pruebas, sin WebView: la tarjeta del prototipo (CL-009-5).
    final preview = widget.live && ref.watch(webPreviewProvider);
    // Antes de crear la WebView ya se está cargando.
    final loading =
        widget.live && !preview && (state == null || state.pageLoading);
    final logo = widget.landscapeLogo;
    // En horizontal, a sangre: sin bordes ni barra (CA-009-15). Mismo árbol en
    // las dos orientaciones, para no volver a crear la WebView.
    final landscape = logo != null;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: landscape
          ? const BoxDecoration()
          : const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: UnaColors.ink,
                  width: UnaBorders.strongWidth,
                ),
              ),
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: landscape ? 0 : UnaBorders.strongWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showBar && !landscape)
              widget.taskNode(
                WebBar(
                  host: host,
                  badge: l10n.attachmentWeb,
                  // Sin candado con el aviso de conexión no segura
                  // (propietario, 2026-09-29).
                  secure: shown?.failure != WebLoadFailure.insecure,
                ),
                host,
              ),
            Expanded(
              key: const ValueKey('web-page'),
              child: ColoredBox(
                color: UnaColors.surface,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (preview)
                      WebPreviewCard(
                        key: const ValueKey('web-preview-card'),
                        host: host,
                        address: widget.address,
                        onOpen: _openInNewTab,
                      ),
                    if (page != null && state != null)
                      // Bajo un aviso, la página no se ve ni la lee el lector.
                      Offstage(
                        offstage: failure != null,
                        child: page.driver.buildView(
                          key: ValueKey('web-view-${state.viewGeneration}'),
                        ),
                      ),
                    if (failure != null)
                      _Notice(
                        text: _failureText(l10n, failure),
                        failure: failure,
                        onRetry: _retry,
                        onOpenInBrowser: () => _openInBrowser(host),
                      )
                    else if (loading)
                      Align(
                        alignment: Alignment.topCenter,
                        child: _LoadingLine(progress: state?.progress ?? 0),
                      ),
                    // El logotipo, encima de la página.
                    if (logo != null)
                      KeyedSubtree(
                        key: const ValueKey('web-logo'),
                        child: logo(host),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _failureText(
  AppLocalizations l10n,
  WebLoadFailure failure,
) => switch (failure) {
  WebLoadFailure.offline => l10n.urlNeedsConnection,
  WebLoadFailure.insecure => l10n.urlInsecure,
  WebLoadFailure.certificate => l10n.urlLoadFailed(l10n.urlReasonCertificate),
  WebLoadFailure.notAPage => l10n.urlNotAPage,
  WebLoadFailure.keepsLeaving => l10n.urlLoadFailed(l10n.urlReasonKeepsLeaving),
};

/// Línea de carga a todo el ancho bajo la barra (CA-009-06): avanza con el
/// progreso de la página; con reducir movimiento, salta (CA-009-20). Para el
/// lector, "Cargando página" (CA-009-18).
class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.progress});

  /// De 0 a 100.
  final int progress;

  /// Lo mínimo que se ve nada más empezar, antes del primer progreso.
  static const _minFraction = 0.1;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: const ValueKey('web-loading'),
      container: true,
      label: AppLocalizations.of(context).urlLoadingA11y,
      child: SizedBox(
        height: UnaSizes.webLoadingHeight,
        width: double.infinity,
        child: AnimatedFractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          duration: reduced ? Duration.zero : UnaMotion.webLoadingProgress,
          widthFactor: math.max(progress / 100, _minFraction),
          child: const ColoredBox(color: UnaColors.ink),
        ),
      ),
    );
  }
}

/// El aviso que sustituye a la página (spec 009 §5), con sus acciones: "Abrir
/// en el navegador" y, después, "Reintentar".
class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.failure,
    required this.onRetry,
    required this.onOpenInBrowser,
  });

  final String text;
  final WebLoadFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(UnaSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontFamily: UnaFonts.display,
                fontSize: UnaFontSizes.heading,
                fontWeight: UnaFontWeights.extrabold,
                height: 1.1,
                letterSpacing: UnaLetterSpacing.tight * UnaFontSizes.heading,
                color: UnaColors.ink,
              ),
            ),
            // Enlaces, no botones: el botón negro es de la tarea ("Completar").
            if (failure.canOpenInBrowser) ...[
              const SizedBox(height: UnaSpace.ml),
              Center(
                child: UnaLinkButton(
                  label: l10n.urlOpenInBrowser,
                  height: kMinInteractiveDimension,
                  onPressed: onOpenInBrowser,
                ),
              ),
            ],
            if (failure.canRetry) ...[
              SizedBox(
                height: failure.canOpenInBrowser ? UnaSpace.s : UnaSpace.ml,
              ),
              Center(
                child: UnaLinkButton(
                  label: l10n.retry,
                  height: kMinInteractiveDimension,
                  onPressed: onRetry,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
