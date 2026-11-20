import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../domain/ports/accessibility_timeouts.dart';

/// [AccessibilityTimeouts] sobre el canal `una/a11y`
/// (`AccessibilityTimeouts.kt` y `A11y.swift`, spec 014, CA-014-06 y spec 028,
/// CA-028-14). El canal solo da los
/// hechos del sistema; la regla de la duración está en `UndoDuration`.
/// Ninguno de los tres valores se guarda ni se registra.
class ChannelAccessibilityTimeouts implements AccessibilityTimeouts {
  const ChannelAccessibilityTimeouts({this.web = kIsWeb});

  /// La web de pruebas no tiene canal: no se llama.
  final bool web;

  static const _channel = MethodChannel('una/a11y');

  static const _none = (
    recommendedMs: null,
    serviceEnabled: false,
    touchExploration: false,
  );

  /// Cualquier fallo del canal (sin lado nativo, como en la web de pruebas;
  /// error de plataforma; respuesta inesperada) es "nada que alargar" (4 s) y
  /// "sin lector". En iOS `recommendedMs` llega siempre nulo: no hay "Tiempo
  /// para actuar" (ADR-0031).
  @override
  Future<SystemTimeouts> read() async {
    if (web) return _none;
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('timeouts');
    } on MissingPluginException {
      return _none;
    } on PlatformException {
      return _none;
    }
    if (reply is! Map) return _none;
    return (
      recommendedMs: switch (reply['recommendedMs']) {
        final int ms => ms,
        _ => null,
      },
      serviceEnabled: reply['serviceEnabled'] == true,
      touchExploration: reply['touchExploration'] == true,
    );
  }
}
