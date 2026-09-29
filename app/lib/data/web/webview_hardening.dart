import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';

import 'web_data_janitor.dart';

/// Aviso de lo nativo sobre una WebView (su `webViewIdentifier`).
@immutable
sealed class WebViewNativeEvent {
  const WebViewNativeEvent(this.webViewId);

  final int webViewId;
}

/// Murió el proceso de la página (ADR-0017): la app sigue viva, pero esa
/// WebView ya no sirve; hay que destruirla y crear otra. [crashed] es `false`
/// si lo mató el sistema (memoria).
final class WebRenderProcessGone extends WebViewNativeEvent {
  const WebRenderProcessGone(super.webViewId, {required this.crashed});

  final bool crashed;

  @override
  bool operator ==(Object other) =>
      other is WebRenderProcessGone &&
      other.webViewId == webViewId &&
      other.crashed == crashed;

  @override
  int get hashCode => Object.hash(webViewId, crashed);
}

/// La dirección es un archivo, no una página: no se ha descargado nada
/// (CL-009-4). Sin la dirección (CL-009-9).
final class WebDownloadBlocked extends WebViewNativeEvent {
  const WebDownloadBlocked(super.webViewId);

  @override
  bool operator ==(Object other) =>
      other is WebDownloadBlocked && other.webViewId == webViewId;

  @override
  int get hashCode => webViewId.hashCode;
}

/// Canal `una/webview` (`WebViewHardening.kt`, spec 009, plan §1): el
/// endurecimiento nativo de la WebView de la tarea web y el borrado de sus
/// datos. El identificador es `AndroidWebViewController.webViewIdentifier`.
///
/// Orden (ADR-0017): [harden] **después** de `setNavigationDelegate`, y nunca
/// otro `setNavigationDelegate` sobre esa WebView (quitaría el envoltorio del
/// cliente y el bloqueo de descargas). Si [harden] devuelve `false`, la página
/// no se carga.
///
/// Sin canal (tests, iOS aún) o con un error nativo, nada lanza: se da por no
/// endurecida y por no borrada.
class ChannelWebViewHardening implements WebDataCleaner {
  const ChannelWebViewHardening();

  static const _channel = MethodChannel('una/webview');

  static final _events = StreamController<WebViewNativeEvent>.broadcast(
    onListen: () => _channel.setMethodCallHandler(_onNativeCall),
  );

  /// Por WebView, si la última petición del marco principal que avisó lo
  /// nativo era una redirección del servidor ([takeServerRedirect]).
  static final _serverRedirects = <int, bool>{};

  // Sin `await` antes de apuntarlo: el aviso de lo nativo llega justo antes
  // que la petición de navegación del paquete, y cuando esta llega ya tiene
  // que estar apuntado.
  static Future<void> _onNativeCall(MethodCall call) async {
    final args = call.arguments;
    if (args is! Map || args['id'] is! int) return;
    final id = args['id'] as int;
    switch (call.method) {
      case 'mainFrameRequest':
        _serverRedirects[id] = args['redirect'] == true;
      case 'renderProcessGone':
        _events.add(WebRenderProcessGone(id, crashed: args['crashed'] == true));
      case 'downloadBlocked':
        _events.add(WebDownloadBlocked(id));
    }
  }

  /// Avisos de lo nativo (fallo del proceso de la página, descarga bloqueada).
  /// Mientras haya alguien escuchando, también se apunta lo que dice
  /// [takeServerRedirect].
  Stream<WebViewNativeEvent> get events => _events.stream;

  /// Si la petición del marco principal que acaba de llegar a
  /// `onNavigationRequest` en la WebView [webViewId] es una **redirección del
  /// servidor** (`WebResourceRequest.isRedirect`) y no una navegación de la
  /// propia página (enlace, JavaScript, `meta refresh`): el envoltorio del
  /// cliente lo avisa justo antes de pasársela al paquete, que no lo da
  /// (T-009-12, CL-009-1). Se consulta una vez; sin aviso, `false` (no se
  /// sigue). Sin la dirección (CL-009-9).
  bool takeServerRedirect(int webViewId) =>
      _serverRedirects.remove(webViewId) ?? false;

  /// Ajustes (sin archivos ni contenido, sin datos de formularios, sin
  /// contenido mixto, Safe Browsing, sin ventanas nuevas), descargas
  /// bloqueadas, sin depuración en *release* y el envoltorio del cliente con
  /// `onRenderProcessGone`. `true` solo si todo se ha leído de vuelta como debe.
  Future<bool> harden(int webViewId) async =>
      await _invoke<bool>('harden', {'id': webViewId}) ?? false;

  /// Los ajustes de [harden] leídos de vuelta y si el envoltorio sigue puesto
  /// (`wrapped`). `null` si no hay esa WebView.
  Future<Map<String, bool>?> state(int webViewId) async {
    final state = await _invoke<Map<Object?, Object?>>('state', {
      'id': webViewId,
    });
    return state?.map((k, v) => MapEntry(k! as String, v == true));
  }

  /// Destruye la WebView tras el fallo de su proceso (ADR-0017).
  Future<void> destroy(int webViewId) {
    _serverRedirects.remove(webViewId);
    return _invoke<void>('destroy', {'id': webViewId});
  }

  @override
  Future<bool> clearWebData({int? webViewId}) async =>
      await _invoke<bool>('clearData', {'id': ?webViewId}) ?? false;

  Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      // Sin registrar nada (CL-009-9).
      return null;
    }
  }
}
