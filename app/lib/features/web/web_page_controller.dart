import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import '../../app/una_app.dart' show UnaApp;
import '../../data/web/web_data_janitor.dart';
import '../../domain/entities/web_load_failure.dart';
import '../../domain/ports/clock.dart';
import '../../domain/services/web_navigation.dart';
import 'web_page_driver.dart';

/// Qué se ve bajo la barra de una tarea web (plan §1, "Estado de la página").
enum WebPageStatus {
  /// Aún no ha empezado a verse la página: indicador de carga.
  loading,

  /// La página se ve (puede seguir cargando: [WebPageState.pageLoading]).
  shown,

  /// Sin conexión o 20 s sin que empiece a verse (CA-009-08).
  offline,

  /// El servidor no admite https (CA-009-09).
  insecure,

  /// Certificado no válido (CA-009-10).
  certificate,

  /// La dirección es un archivo, no una página (CL-009-4).
  notAPage,
}

/// Estado de la página de una tarea web.
@immutable
class WebPageState {
  const WebPageState({
    required this.status,
    required this.pageUrl,
    this.pageLoading = true,
    this.progress = 0,
    this.redirectNotice,
    this.viewGeneration = 0,
  });

  final WebPageStatus status;

  /// La dirección de la barra (CA-009-14): la de la página que se ve o, antes,
  /// la que se está cargando (la guardada, con `https://`).
  final Uri pageUrl;

  /// Si la página aún carga (hasta `onPageFinished`): la línea de carga.
  final bool pageLoading;

  /// Progreso de la carga, de 0 a 100.
  final int progress;

  /// El dominio del aviso `urlRedirected` (CL-009-1), una sola vez; null si no
  /// hay que avisar. Se quita con `WebPageController.redirectNoticeShown`.
  final String? redirectNotice;

  /// Cambia cada vez que se crea una WebView nueva (ADR-0017): la vista se
  /// monta con esta clave.
  final int viewGeneration;

  /// El aviso que tapa la página (spec 009 §5), o null.
  WebLoadFailure? get failure => switch (status) {
    WebPageStatus.offline => WebLoadFailure.offline,
    WebPageStatus.insecure => WebLoadFailure.insecure,
    WebPageStatus.certificate => WebLoadFailure.certificate,
    WebPageStatus.notAPage => WebLoadFailure.notAPage,
    WebPageStatus.loading || WebPageStatus.shown => null,
  };

  WebPageState copyWith({
    WebPageStatus? status,
    Uri? pageUrl,
    bool? pageLoading,
    int? progress,
    String? Function()? redirectNotice,
    int? viewGeneration,
  }) => WebPageState(
    status: status ?? this.status,
    pageUrl: pageUrl ?? this.pageUrl,
    pageLoading: pageLoading ?? this.pageLoading,
    progress: progress ?? this.progress,
    redirectNotice: redirectNotice == null
        ? this.redirectNotice
        : redirectNotice(),
    viewGeneration: viewGeneration ?? this.viewGeneration,
  );

  // Sin la dirección (CL-009-9).
  @override
  String toString() => 'WebPageState($status, $progress%)';
}

/// La página de la tarea web que se ve (spec 009, plan §1). Lo crea y lo
/// suelta la pantalla de la tarea (T-009-11): vive mientras se ve la tarea.
///
/// - **Se carga cada vez** ([start], [comeBack]): la dirección guardada
///   [address], `http://` como `https://` (CA-009-07, CA-009-09), con la marca
///   de datos escrita antes (CA-009-13).
/// - **20 s** sin `onPageStarted` → sin conexión (CA-009-08, CL-009-7).
/// - Los errores se clasifican con `classifyLoadError`; un certificado no
///   válido o una descarga solo cuentan mientras no se ve la página (después
///   son de un recurso o de la página: no hacen nada).
/// - **Sin navegación** (ADR-0018): `decideWebNavigation` con la página que se
///   ve (la del primer `onPageStarted`); en la carga inicial se siguen solo
///   las redirecciones **del servidor** (una navegación de la página que llega
///   antes de `onPageStarted` no) y, si acaba en otro dominio, se avisa una
///   vez (CL-009-1). Excepción: con la dirección guardada `http://`, si la
///   página intenta ir a otra `http://` antes de terminar la carga inicial,
///   aviso "no segura" (CA-009-09, CA-009-11).
/// - **Formularios POST** (Android no los pasa por `onNavigationRequest`): si,
///   vista la página, el marco principal empieza a cargar otra (su
///   `onPageStarted` o su error), se vuelve a cargar la dirección guardada; la
///   barra nunca muestra el dominio de esa otra (CA-009-11; propietario,
///   2026-09-29).
/// - "Reintentar" ([retry]); al volver a la app con un aviso se reintenta
///   solo; de segundo plano en menos de 10 minutos se conserva y, con 10 o
///   más, se carga desde cero (CA-009-07).
/// - Fuera de la tarea ([leave]) y al soltarlo ([dispose], también al
///   completar o eliminar, CL-009-11): se deja de cargar y se borran los datos
///   de la WebView.
/// - **Fallo del proceso de la página** (ADR-0017): **solo tras el aviso** se
///   crea una WebView nueva (antes, Android cerraría la app: T-009-09); la
///   vieja se destruye cuando ya no está en pantalla y se vuelve a cargar la
///   dirección guardada.
class WebPageController extends ValueNotifier<WebPageState> {
  WebPageController({
    required this.address,
    required WebPageDriverFactory createDriver,
    required WebDataJanitor janitor,
    required Clock clock,
    Future<void> Function()? afterFrame,
    Duration timeout = webLoadTimeout,
  }) : _createDriver = createDriver,
       _cleanup = janitor,
       _time = clock,
       _afterFrame = afterFrame ?? _endOfFrame,
       _loadTimeout = timeout,
       super(
         WebPageState(status: WebPageStatus.loading, pageUrl: _first(address)),
       ) {
    _driver = createDriver();
    _lifecycle = AppLifecycleListener(
      onHide: _onAppHidden,
      onShow: _onAppShown,
    );
  }

  /// La dirección guardada.
  final Uri address;

  final WebPageDriverFactory _createDriver;
  final WebDataJanitor _cleanup;
  final Clock _time;
  final Future<void> Function() _afterFrame;
  final Duration _loadTimeout;
  late final AppLifecycleListener _lifecycle;

  late WebPageDriver _driver;
  bool _attached = false;
  bool _active = false;
  bool _disposed = false;
  Timer? _timer;
  DateTime? _hiddenAt;

  /// La página que se ve: la del primer `onPageStarted` de la carga; null
  /// durante la carga inicial (ADR-0018).
  Uri? _shownPage;

  /// Si en esta carga se ha pedido `https://` en lugar de `http://`.
  bool _upgradedFromHttp = false;

  /// Si ya se ha avisado de la redirección (CL-009-1: una vez).
  bool _redirectNoticed = false;

  /// La otra página (de otra dirección) que empezó a cargarse ya vista la
  /// página (un formulario POST) y por la que se ha vuelto a cargar la
  /// dirección guardada: lo que llegue de ella después no cuenta.
  Uri? _detour;

  /// Aumenta con cada carga: lo que quede de una anterior no cuenta.
  int _load = 0;

  static Future<void> _endOfFrame() => SchedulerBinding.instance.endOfFrame;

  static Uri _first(Uri address) => httpsVersion(address);

  /// La WebView actual (cambia tras el fallo de su proceso: ADR-0017).
  WebPageDriver get driver => _driver;

  /// Primera carga. Se llama con la vista ya en pantalla.
  Future<void> start() async {
    if (_disposed || _active) return;
    _active = true;
    await _attachAndLoad();
  }

  /// "Reintentar": vuelve a cargar la dirección guardada (CA-009-08).
  Future<void> retry() async {
    if (_disposed || !_active) return;
    await _attachAndLoad();
  }

  /// La tarea deja de verse (otra pantalla encima): se quita la página y se
  /// borran sus datos (CA-009-13).
  void leave() {
    if (_disposed || !_active) return;
    _active = false;
    _abandon();
    final driver = _driver;
    unawaited(_stopAndClear(driver));
  }

  /// La tarea vuelve a verse: se carga desde cero (CA-009-07).
  Future<void> comeBack() async {
    if (_disposed) return;
    _active = true;
    await _attachAndLoad();
  }

  /// La pantalla ya ha avisado de la redirección.
  void redirectNoticeShown() {
    if (value.redirectNotice == null) return;
    _set(value.copyWith(redirectNotice: () => null));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;
    _abandon();
    _lifecycle.dispose();
    final driver = _driver;
    unawaited(_stopAndClear(driver).whenComplete(driver.dispose));
    super.dispose();
  }

  // Carga.

  Future<void> _attachAndLoad() async {
    final driver = _driver;
    final load = _begin();
    if (!_attached) {
      final hardened = await _safe(
        () => driver.attach(_DriverListener(this, driver)),
        false,
      );
      if (!_isCurrent(driver, load)) return;
      if (!hardened) {
        // Sin endurecer no se carga nada (ADR-0017); con "Reintentar" se
        // vuelve a intentar.
        _fail(WebLoadFailure.offline);
        return;
      }
      _attached = true;
    }
    await _cleanup.markUsed();
    if (!_isCurrent(driver, load)) return;
    await _safe(() => driver.load(_first(address)), null);
  }

  /// Empieza una carga: "cargando", con los 20 s en marcha.
  int _begin() {
    _abandon();
    final load = ++_load;
    _shownPage = null;
    _detour = null;
    _upgradedFromHttp = address.scheme.toLowerCase() == 'http';
    _set(
      value.copyWith(
        status: WebPageStatus.loading,
        pageUrl: _first(address),
        pageLoading: true,
        progress: 0,
      ),
    );
    _timer = Timer(_loadTimeout, () {
      if (!_isCurrent(_driver, load) || value.status != WebPageStatus.loading) {
        return;
      }
      _fail(WebLoadFailure.offline);
      unawaited(_safe(_driver.stop, null));
    });
    return load;
  }

  /// Lo que quede de la carga en curso ya no cuenta.
  void _abandon() {
    _timer?.cancel();
    _timer = null;
    _load++;
  }

  bool _isCurrent(WebPageDriver driver, int load) =>
      !_disposed && _active && identical(driver, _driver) && load == _load;

  bool _isLive(WebPageDriver driver) =>
      !_disposed && _active && identical(driver, _driver);

  bool get _loadingOrShown =>
      value.status == WebPageStatus.loading ||
      value.status == WebPageStatus.shown;

  void _fail(WebLoadFailure failure) {
    _timer?.cancel();
    _timer = null;
    _set(
      value.copyWith(
        status: switch (failure) {
          WebLoadFailure.offline => WebPageStatus.offline,
          WebLoadFailure.insecure => WebPageStatus.insecure,
          WebLoadFailure.certificate => WebPageStatus.certificate,
          WebLoadFailure.notAPage => WebPageStatus.notAPage,
        },
        pageLoading: false,
      ),
    );
  }

  Future<void> _stopAndClear(WebPageDriver driver) async {
    await _safe(driver.stop, null);
    await _cleanup.clearOnLeave(webViewId: driver.nativeId);
  }

  void _set(WebPageState state) {
    if (!_disposed) value = state;
  }

  /// Nada de la WebView lanza hacia la pantalla ni se registra (CL-009-9).
  static Future<T> _safe<T>(Future<T> Function() f, T fallback) async {
    try {
      return await f();
    } on Object {
      return fallback;
    }
  }

  // Segundo plano (CA-009-07, CA-009-08).

  void _onAppHidden() => _hiddenAt = _time.now();

  void _onAppShown() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null || !_active || _disposed) return;
    final long = _time.now().difference(hiddenAt) >= UnaApp.resetAfter;
    if (!long && value.failure == null) return;
    // Tras el fotograma: con 10 minutos o más, la app vuelve a montar la
    // tarea (CA-001-12) y este controlador ya se habrá soltado.
    unawaited(
      _afterFrame().then((_) async {
        if (_disposed || !_active) return;
        if (long) {
          _abandon();
          await _cleanup.clearOnLeave(webViewId: _driver.nativeId);
        }
        await _attachAndLoad();
      }),
    );
  }

  // Eventos de la WebView.

  bool _onNavigationRequest(
    WebPageDriver driver,
    Uri? url, {
    required bool isMainFrame,
    required bool isServerRedirect,
  }) {
    if (url == null || !_isLive(driver) || !_loadingOrShown) return false;
    final decision = decideWebNavigation(
      url,
      shownPage: _shownPage,
      isMainFrame: isMainFrame,
      isServerRedirect: isServerRedirect,
    );
    switch (decision) {
      case BlockNavigation():
        if (isMainFrame && _leavesForHttpWhileLoading(url)) {
          // Una dirección http:// cuyo https solo manda a otra http://
          // (neverssl.com): sin el aviso se quedaría en blanco (CA-009-09,
          // excepción de CA-009-11; propietario, 2026-09-29).
          _fail(WebLoadFailure.insecure);
          unawaited(_safe(driver.stop, null));
        }
        return false;
      case StayInTask(:final upgraded?):
        // Redirección a `http://` en la carga inicial: se pide con https.
        _upgradedFromHttp = true;
        unawaited(_safe(() => driver.load(upgraded), null));
        return false;
      case StayInTask():
        return true;
    }
  }

  /// Si, con la dirección guardada `http://` (cargada como `https://`), la
  /// página intenta ir a [url] `http://` antes de terminar la carga inicial:
  /// ya vista o antes de su `onPageStarted` (un `location.href` en el
  /// `<head>` puede llegar antes, T-009-12). Una redirección del servidor no
  /// llega aquí: se sigue con `https://`.
  bool _leavesForHttpWhileLoading(Uri url) =>
      address.scheme.toLowerCase() == 'http' &&
      url.scheme.toLowerCase() == 'http' &&
      _loadingOrShown &&
      value.pageLoading;

  /// Ya vista la página, el marco principal empieza a cargar [other] (un
  /// formulario POST, que Android no pasa por `onNavigationRequest`): se
  /// vuelve a cargar la dirección guardada, y la barra vuelve a su dominio
  /// (CA-009-11). La marca de datos ya está escrita (CA-009-13).
  void _reloadSaved(WebPageDriver driver, Uri other) {
    final shown = _shownPage;
    _begin();
    if (shown != null && !isSamePage(other, shown)) _detour = other;
    unawaited(_safe(() => driver.load(_first(address)), null));
  }

  /// Si [url], que empieza a cargarse con la página ya vista, es otra carga
  /// y no un ancla de la misma página.
  bool _isAnotherLoad(Uri url) {
    final shown = _shownPage;
    if (shown == null) return false;
    final anchor = url.hasFragment && url != shown && isSamePage(url, shown);
    return !anchor;
  }

  void _onPageStarted(WebPageDriver driver, Uri url) {
    if (!_isLive(driver)) return;
    // El about:blank de una carga abandonada.
    if (url.scheme == 'about') return;
    if (value.status == WebPageStatus.shown) {
      if (_isAnotherLoad(url)) _reloadSaved(driver, url);
      return;
    }
    if (value.status != WebPageStatus.loading || url == _detour) return;
    _timer?.cancel();
    _timer = null;
    _shownPage = url;
    String? notice;
    if (!_redirectNoticed) {
      notice = redirectNoticeHost(saved: address, started: url);
      _redirectNoticed = notice != null;
    }
    _set(
      value.copyWith(
        status: WebPageStatus.shown,
        pageUrl: url,
        pageLoading: true,
        redirectNotice: notice == null ? null : () => notice,
      ),
    );
  }

  void _onPageFinished(WebPageDriver driver) {
    if (!_isLive(driver) || value.status != WebPageStatus.shown) return;
    _set(value.copyWith(pageLoading: false, progress: 100));
  }

  void _onProgress(WebPageDriver driver, int percent) {
    if (!_isLive(driver) || !_loadingOrShown || !value.pageLoading) return;
    _set(value.copyWith(progress: percent.clamp(0, 100)));
  }

  void _onLoadError(
    WebPageDriver driver,
    WebLoadError error, {
    required bool isMainFrame,
    Uri? url,
  }) {
    if (!_isLive(driver) || !_loadingOrShown) return;
    if (isMainFrame && url != null) {
      // El de la otra página por la que ya se ha vuelto a cargar.
      if (url == _detour) return;
      // Ya vista la página, el error de otra (un formulario POST que no
      // llega a cargarse) tampoco es un aviso: se vuelve a cargar la
      // dirección guardada.
      final shown = _shownPage;
      if (value.status == WebPageStatus.shown &&
          shown != null &&
          !isSamePage(url, shown)) {
        _reloadSaved(driver, url);
        return;
      }
    }
    final failure = classifyLoadError(
      error,
      isMainFrame: isMainFrame,
      upgradedFromHttp: _upgradedFromHttp,
    );
    if (failure != null) _fail(failure);
  }

  /// Certificado o descarga: solo cuentan si aún no se ve la página.
  void _onBeforePageFailure(WebPageDriver driver, WebLoadError error) {
    if (!_isLive(driver) || value.status != WebPageStatus.loading) return;
    _fail(
      classifyLoadError(error, isMainFrame: true, upgradedFromHttp: false)!,
    );
  }

  void _onProcessGone(WebPageDriver dead) {
    if (_disposed || !identical(dead, _driver)) return;
    // La WebView nueva se crea ahora, tras el aviso; nunca antes (T-009-09).
    _abandon();
    final fresh = _createDriver();
    _driver = fresh;
    _attached = false;
    _shownPage = null;
    _set(
      value.copyWith(
        status: WebPageStatus.loading,
        pageUrl: _first(address),
        pageLoading: true,
        progress: 0,
        viewGeneration: value.viewGeneration + 1,
      ),
    );
    unawaited(_replace(dead, fresh));
  }

  /// Destruye [dead] cuando su vista ya no está en pantalla y carga en
  /// [fresh] (ADR-0017).
  Future<void> _replace(WebPageDriver dead, WebPageDriver fresh) async {
    await _afterFrame();
    await _safe(dead.destroy, null);
    dead.dispose();
    if (_disposed || !_active || !identical(fresh, _driver)) return;
    await _attachAndLoad();
  }
}

/// Reenvía al controlador los eventos de **una** WebView: los de una que ya no
/// es la actual no cuentan.
class _DriverListener implements WebPageListener {
  _DriverListener(this._controller, this._driver);

  final WebPageController _controller;
  final WebPageDriver _driver;

  @override
  bool onNavigationRequest(
    Uri? url, {
    required bool isMainFrame,
    required bool isServerRedirect,
  }) => _controller._onNavigationRequest(
    _driver,
    url,
    isMainFrame: isMainFrame,
    isServerRedirect: isServerRedirect,
  );

  @override
  void onPageStarted(Uri url) => _controller._onPageStarted(_driver, url);

  @override
  void onPageFinished(Uri url) => _controller._onPageFinished(_driver);

  @override
  void onProgress(int percent) => _controller._onProgress(_driver, percent);

  @override
  void onLoadError(WebLoadError error, {required bool isMainFrame, Uri? url}) =>
      _controller._onLoadError(
        _driver,
        error,
        isMainFrame: isMainFrame,
        url: url,
      );

  @override
  void onCertificateError() =>
      _controller._onBeforePageFailure(_driver, WebLoadError.certificate);

  @override
  void onDownloadBlocked() =>
      _controller._onBeforePageFailure(_driver, WebLoadError.download);

  @override
  void onProcessGone({required bool crashed}) =>
      _controller._onProcessGone(_driver);
}
