import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Giro de la tarea actual con imagen o con PDF (CA-008-11), las únicas
/// pantallas que giran: el resto de la app queda en vertical. En Android, la
/// parte nativa lee el acelerómetro y fija la orientación, porque el sensor del
/// sistema de HyperOS no avisa hasta el siguiente toque; respeta el bloqueo de
/// rotación. Las orientaciones permitidas se piden además con `SystemChrome`.
abstract final class AttachmentRotation {
  static const _channel = MethodChannel('una/screen');

  /// Pantallas que ahora quieren girar. Al pasar de una tarea con adjunto a
  /// otra, la nueva se monta antes de que se desmonte la anterior: se cuenta
  /// y se decide al final, para que no gane el "no" de la que se va.
  static int _requests = 0;
  static bool? _sent;
  static bool _scheduled = false;

  /// Una pantalla empieza ([on] = true) o deja de querer girar.
  static void request({required bool on}) {
    _requests += on ? 1 : -1;
    assert(_requests >= 0);
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      final want = _requests > 0;
      if (want == _sent) return;
      _sent = want;
      unawaited(_follow(want));
    });
  }

  static Future<void> _follow(bool on) async {
    // La web de pruebas no gira (CL-008-12): ni se pide la orientación, que en
    // un navegador móvil la bloquearía.
    if (kIsWeb) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      if (on) ...[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ]);
    await _invoke('rotateWithAttachment', on);
  }

  static Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Plataforma sin el canal (iOS aún, D17): basta `SystemChrome`.
    } on PlatformException {
      // Sin el sensor, gira como lo decida el sistema.
    }
  }
}
