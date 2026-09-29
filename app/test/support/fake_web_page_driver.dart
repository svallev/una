import 'package:app/domain/entities/web_load_failure.dart';
import 'package:app/features/web/web_page_driver.dart';
import 'package:flutter/widgets.dart';

/// WebView falsa de la tarea web (spec 009, plan §5): registra lo que le pide
/// el `WebPageController` y emite a mano los eventos del paquete.
class FakeWebPageDriver implements WebPageDriver {
  FakeWebPageDriver({this.nativeId, this.hardens = true, this.onLoad});

  @override
  final int? nativeId;

  /// Lo que devuelve [attach].
  bool hardens;

  /// Se llama en cada [load], antes de registrarla.
  void Function(Uri url)? onLoad;

  WebPageListener? listener;
  int attachCount = 0;
  final loads = <Uri>[];
  int stops = 0;
  bool destroyed = false;
  bool disposed = false;

  @override
  Future<bool> attach(WebPageListener listener) async {
    attachCount++;
    this.listener = listener;
    return hardens;
  }

  @override
  Future<void> load(Uri url) async {
    onLoad?.call(url);
    loads.add(url);
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> destroy() async => destroyed = true;

  @override
  void dispose() => disposed = true;

  @override
  Widget buildView({Key? key}) => SizedBox.expand(key: key);

  // Eventos del paquete.

  bool navigate(String url, {bool mainFrame = true}) =>
      listener!.onNavigationRequest(Uri.parse(url), isMainFrame: mainFrame);
  void started(String url) => listener!.onPageStarted(Uri.parse(url));
  void finished(String url) => listener!.onPageFinished(Uri.parse(url));
  void progress(int percent) => listener!.onProgress(percent);
  void error(WebLoadError error, {bool mainFrame = true}) =>
      listener!.onLoadError(error, isMainFrame: mainFrame);
  void certificate() => listener!.onCertificateError();
  void download() => listener!.onDownloadBlocked();
  void processGone({bool crashed = true}) =>
      listener!.onProcessGone(crashed: crashed);
}
