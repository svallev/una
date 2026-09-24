// SPIKE S3 (PDF y visor del sistema), S4 (URL: captura y WebView endurecida),
// S5 (importación). Código desechable.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'importer.dart';

const _native = MethodChannel('spike/native');

void _log(String tag, Object data) {
  // ignore: avoid_print
  print('$tag ${jsonEncode(data)}');
}

class Lab extends StatefulWidget {
  const Lab({super.key});
  @override
  State<Lab> createState() => _LabState();
}

class _LabState extends State<Lab> {
  final List<ImportResult> _results = [];
  final _url = TextEditingController(text: 'https://es.wikipedia.org/wiki/Nota_adhesiva');
  bool _busy = false;
  String _status = '';

  int get _screenPx => (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();

  Future<void> _import(File f) async {
    final r = await importFile(f, screenPx: _screenPx);
    _log('SPIKE_S5', r.toJson());
    setState(() => _results.insert(0, r));
  }

  Future<void> _importSamples() async {
    setState(() => _busy = true);
    try {
      // Muestras copiadas con adb a la carpeta externa propia de la app.
      final dir = (await getExternalStorageDirectory())!;
      final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
      _log('SPIKE_S5', {'samplesDir': dir.path, 'count': files.length});
      for (final f in files) {
        setState(() => _status = 'Importando ${f.uri.pathSegments.last}…');
        try {
          await _import(f);
        } catch (e) {
          _log('SPIKE_S5', {'name': f.uri.pathSegments.last, 'kind': 'error', 'reason': '$e'});
        }
      }
      setState(() => _status = '${files.length} muestras procesadas');
    } catch (e) {
      _log('SPIKE_S5', {'fatal': '$e'});
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, requestFullMetadata: false);
    if (x != null) await _import(File(x.path));
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    final p = r.isEmpty ? null : r.first.path;
    if (p != null) await _import(File(p));
  }

  static const _battery = [
    'https://es.wikipedia.org/wiki/Post-it', // larga, texto + imágenes (la del prototipo)
    'https://flutter.dev', // mucho JS y animaciones
    'https://www.w3.org/', // corta
    'http://neverssl.com', // solo http: debe fallar (cleartext bloqueado)
    'https://expired.badssl.com', // certificado caducado: debe fallar
    'https://self-signed.badssl.com', // autofirmado: debe fallar
    'https://es.wikipedia.org/wiki/Esta_pagina_no_existe_una_spike', // 404: debe fallar
  ];

  Future<void> _snapshotBattery() async {
    for (final u in _battery) {
      _url.text = u;
      await _snapshot(show: false);
    }
  }

  Future<void> _snapshot({bool show = true}) async {
    setState(() {
      _busy = true;
      _status = 'Guardando una copia para verla sin conexión…';
    });
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/attachments/web${DateTime.now().millisecondsSinceEpoch}')..createSync(recursive: true);
    try {
      final r = await _native.invokeMapMethod<String, Object?>('snapshot', {'url': _url.text.trim(), 'out': '${dir.path}/snapshot.jpg'});
      _log('SPIKE_S4', {'url': _url.text.trim(), ...r!});
      // Solo spike: copia para revisarla desde el Mac con adb pull.
      final ext = (await getExternalStorageDirectory())!.path;
      final copy = '$ext/snap_${Uri.parse(_url.text.trim()).host}.jpg';
      await File(r['path']! as String).copy(copy);
      await Process.run('chmod', ['644', copy]);
      if (!mounted) return;
      setState(() => _status = 'Captura: ${r['width']}x${r['height']} px (página ${r['fullHeight']} px${r['partial'] == true ? ', PARCIAL' : ''}), ${((r['bytes'] as int) / 1024).round()} KB, ${r['ms']} ms');
      if (show) await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ImageViewer(path: r['path']! as String, banner: 'Copia del ${DateTime.now().day}/${DateTime.now().month} · ${Uri.parse(r['finalUrl']! as String).host}')));
    } on PlatformException catch (e) {
      _log('SPIKE_S4', {'url': _url.text.trim(), 'error': e.code});
      setState(() => _status = 'Error de captura: ${e.code}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _open(ImportResult r) {
    final page = switch (r.detection.kind) {
      Kind.image => _ImageViewer(path: r.files['display'] ?? r.files['original']!, banner: r.name),
      Kind.pdf when r.info['protected'] == true => _DocCard(r: r, note: 'PDF protegido'),
      Kind.pdf => _PdfPage(r: r),
      _ => _DocCard(r: r),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('S3 · S4 · S5')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(onPressed: _busy ? null : _importSamples, child: const Text('S5 · Importar muestras')),
          OutlinedButton(onPressed: () => _pickImage(ImageSource.gallery), child: const Text('Galería')),
          OutlinedButton(onPressed: () => _pickImage(ImageSource.camera), child: const Text('Cámara')),
          OutlinedButton(onPressed: _pickFile, child: const Text('Archivo')),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _url, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(labelText: 'URL (S4)')),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: _busy ? null : _snapshot, child: const Text('S4 · Capturar página')),
          FilledButton.tonal(onPressed: _busy ? null : _snapshotBattery, child: const Text('S4 · Batería de webs')),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _LiveWeb(url: _url.text.trim()))),
            child: const Text('S4 · En vivo'),
          ),
        ]),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_status)),
        const Divider(),
        for (final r in _results)
          ListTile(
            dense: true,
            leading: Icon(r.accepted ? Icons.check_circle : Icons.block, color: r.accepted ? Colors.green : Colors.red),
            title: Text('${r.name} · ${r.detection.kind.name}'),
            subtitle: Text(r.accepted ? '${r.info} · ${r.ms}' : r.detection.reason, style: const TextStyle(fontSize: 11)),
            onTap: r.accepted ? () => _open(r) : null,
          ),
      ]),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.path, required this.banner});
  final String path;
  final String banner;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(banner, style: const TextStyle(fontSize: 14))),
      body: InteractiveViewer(maxScale: 8, constrained: false, child: Image.file(File(path), width: MediaQuery.sizeOf(context).width, fit: BoxFit.fitWidth)),
    );
  }
}

class _PdfPage extends StatefulWidget {
  const _PdfPage({required this.r});
  final ImportResult r;
  @override
  State<_PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<_PdfPage> {
  final _sw = Stopwatch()..start();
  String _t = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.r.name} $_t', style: const TextStyle(fontSize: 14))),
      body: PdfViewer.file(
        widget.r.files['original']!,
        params: PdfViewerParams(
          onViewerReady: (doc, controller) {
            final ms = _sw.elapsedMilliseconds;
            _log('SPIKE_S3', {'name': widget.r.name, 'viewerReadyMs': ms, 'pages': doc.pages.length});
            setState(() => _t = '· listo en $ms ms · ${doc.pages.length} p.');
          },
          linkHandlerParams: PdfLinkHandlerParams(
            onLinkTap: (link) async {
              final url = link.url;
              if (url == null) return;
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  content: Text('¿Abrir ${url.host} en el navegador?'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Abrir'))],
                ),
              );
              _log('SPIKE_S3', {'linkTap': url.toString(), 'userAccepted': ok});
            },
          ),
        ),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.r, this.note});
  final ImportResult r;
  final String? note;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(note ?? 'Documento')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(r.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('${r.detection.mime}\n${((r.info['bytesIn'] as int) / 1024).toStringAsFixed(1)} KB', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final res = await _native.invokeMethod<String>('openFile', {'path': r.files['original'], 'mime': r.detection.mime});
              _log('SPIKE_S3', {'openFile': r.name, 'result': res});
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Resultado: $res')));
            },
            child: const Text('Abrir'),
          ),
        ]),
      ),
    );
  }
}

/// WebView en vivo endurecida (webview_flutter oficial).
class _LiveWeb extends StatefulWidget {
  const _LiveWeb({required this.url});
  final String url;
  @override
  State<_LiveWeb> createState() => _LiveWebState();
}

class _LiveWebState extends State<_LiveWeb> {
  late final WebViewController _c;
  String _checks = '';

  @override
  void initState() {
    super.initState();
    final host = Uri.parse(widget.url).host;
    String base(String h) => h.split('.').reversed.take(2).toList().reversed.join('.'); // aproximación al dominio registrable
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          final allowed = u != null && (u.scheme == 'https' || u.scheme == 'http') && base(u.host) == base(host);
          _log('SPIKE_S4', {'nav': req.url, 'mainFrame': req.isMainFrame, 'allowed': allowed});
          if (!allowed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bloqueado en la tarea: ${u?.scheme}://${u?.host} → se ofrecería abrir en el navegador')));
          }
          return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onPageFinished: (_) => _verify(),
      ));
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setAllowFileAccess(false);
      p.setMediaPlaybackRequiresUserGesture(true);
      p.setGeolocationPermissionsPromptCallbacks(onShowPrompt: (_) async => const GeolocationPermissionsResponse(allow: false, retain: false));
      p.setOnPlatformPermissionRequest((req) => req.deny());
    }
    _c.loadRequest(Uri.parse(widget.url));
  }

  Future<void> _verify() async {
    // Comprobaciones de aislamiento desde dentro de la página.
    final r = await _c.runJavaScriptReturningResult('''JSON.stringify({
      flutterGlobals: Object.keys(window).filter(k => /flutter|inappwebview|Android|webkit/i.test(k)),
      fileFetch: 'pending'
    })''');
    String fileFetch;
    try {
      await _c.runJavaScript("fetch('file:///data/data/dev.spike.onetask.una_spikes/app_flutter/una_spike.sqlite').then(()=>console.log('FILE_OK')).catch(e=>console.log('FILE_BLOCKED'))");
      fileFetch = 'lanzado (ver consola)';
    } catch (e) {
      fileFetch = 'error: $e';
    }
    final title = await _c.getTitle();
    _log('SPIKE_S4', {'live': widget.url, 'title': title, 'checks': r.toString(), 'fileFetch': fileFetch});
    if (mounted) setState(() => _checks = r.toString());
    if (_probed) return;
    _probed = true;
    for (final js in [
      "window.open('https://example.com/popup')",
      "location.href='tel:600000000'",
      "location.href='intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;end'",
      "location.href='https://example.com/otro-dominio'",
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _c.runJavaScript(js);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _log('SPIKE_S4', {'afterProbes': await _c.currentUrl()});
  }

  bool _probed = false;

  @override
  void dispose() {
    WebViewCookieManager().clearCookies();
    _c.clearLocalStorage();
    _c.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Uri.parse(widget.url).host, style: const TextStyle(fontSize: 14))),
      body: Column(children: [
        if (_checks.isNotEmpty) Text(_checks, style: const TextStyle(fontSize: 10)),
        Expanded(child: WebViewWidget(controller: _c)),
      ]),
    );
  }
}
