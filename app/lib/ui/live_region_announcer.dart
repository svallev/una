import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Anuncia un texto con un **antirrebote** y un contador de generación: con
/// varios avisos seguidos solo se dice el del **último** (spec 016, CA-016-20;
/// spec 019, CA-019-04). Lo comparten el carrusel de fotos y el bloque de
/// Notificaciones de Ajustes.
abstract class DebouncedAnnouncer {
  /// [busy] dice si algo se está moviendo (arrastre o transición): mientras sea
  /// así no se dice nada, para que el último de varios cambios seguidos no
  /// compita con la transición que aún corre (280 ms frente a 300 ms).
  DebouncedAnnouncer({this._busy});

  /// Espera tras el último aviso antes de decir nada.
  static const debounce = Duration(milliseconds: 300);

  final bool Function()? _busy;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Pide anunciar lo que dé [message] cuando pase el antirrebote. Se calcula
  /// al decirlo (no al pedirlo): con el último aviso, el idioma y el estado de
  /// ese momento. Un texto vacío no dice nada.
  void announce(String Function() message) {
    if (_disposed) return;
    _arm(message, ++_generation);
  }

  void _arm(String Function() message, int generation) {
    _timer?.cancel();
    _timer = Timer(debounce, () {
      if (_disposed || generation != _generation) return;
      if (_busy?.call() ?? false) return _arm(message, generation);
      final text = message();
      if (text.isNotEmpty) deliver(text);
    });
  }

  /// Dice [message] con el mecanismo concreto.
  @protected
  void deliver(String message);

  @mustCallSuper
  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

/// (B) El texto de la región viva, que [LiveRegionNode] dibuja.
class LiveRegionAnnouncer extends DebouncedAnnouncer {
  LiveRegionAnnouncer({super.busy});

  /// Tras decirlo, el texto se vacía: así una misma frase vuelve a anunciarse
  /// la próxima vez y el nodo no se queda como un texto suelto que leer.
  static const clearAfter = Duration(seconds: 2);

  /// Lo que dice ahora la región; nace vacío.
  final message = ValueNotifier<String>('');
  Timer? _clear;

  @override
  void deliver(String text) {
    _clear?.cancel();
    message.value = text;
    _clear = Timer(clearAfter, () => message.value = '');
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
    message.dispose();
  }
}

/// (A) Anuncio del sistema con la vista y la dirección del texto de [context].
class SendAnnouncementAnnouncer extends DebouncedAnnouncer {
  SendAnnouncementAnnouncer(this._send, {super.busy});

  final void Function(String message) _send;

  @override
  void deliver(String message) => _send(message);
}

/// El nodo de la región viva de un [LiveRegionAnnouncer]: **no es una parada de
/// foco** (sin `focusable`), **nace vacío** (ni al crearse ni al recrearse
/// anuncia nada) y mide 1 × 1 (el árbol semántico poda lo que no tiene área).
/// La marca del idioma de la app la pone `appFrame` sobre todo el contenido:
/// la frase se lee con la voz de ese idioma, sin anuncio explícito (R-22,
/// ADR-0020).
class LiveRegionNode extends StatelessWidget {
  const LiveRegionNode({super.key, required this.announcer});

  final LiveRegionAnnouncer announcer;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: announcer.message,
    builder: (context, message, _) => Semantics(
      liveRegion: true,
      container: true,
      accessibilityFocusBlockType: AccessibilityFocusBlockType.blockNode,
      label: message,
      child: const SizedBox.square(dimension: 1),
    ),
  );
}
