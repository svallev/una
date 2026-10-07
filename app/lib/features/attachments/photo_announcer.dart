import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'photo_carousel.dart';

/// Cómo se dice "Foto {i} de {n}" al cambiar de foto (plan 016 §6, CA-016-20 y
/// 21). Dos mecanismos intercambiables con el mismo antirrebote; el que se
/// queda lo decide la prueba con TalkBack en el emulador (T-016-17 y 21).
enum PhotoAnnouncerMode {
  /// (B) Región viva en un nodo propio, hermano del de la tarea, con el idioma
  /// de la app (R-22, ADR-0020): da la voz del idioma de la app.
  liveRegion,

  /// (A) `SemanticsService.sendAnnouncement`: voz del sistema (excepción ya
  /// aceptada del ADR-0020), sin idioma y sin poder cancelarse.
  announcement;

  /// El de compilación: `--dart-define=UNA_PHOTO_ANNOUNCER=announcement` cambia
  /// a (A) para compararlos en el dispositivo. Sin definirlo, (B).
  static PhotoAnnouncerMode get fromEnvironment =>
      const String.fromEnvironment('UNA_PHOTO_ANNOUNCER') == 'announcement'
      ? PhotoAnnouncerMode.announcement
      : PhotoAnnouncerMode.liveRegion;
}

/// El mecanismo de anuncio de la foto actual. Los tests lo cambian con un
/// `override`.
final photoAnnouncerModeProvider = Provider<PhotoAnnouncerMode>(
  (ref) => PhotoAnnouncerMode.fromEnvironment,
);

/// Anuncia el estado de la foto con un **antirrebote** y un contador de
/// generación: con varios cambios seguidos solo se dice el estado del
/// **último** (CA-016-20).
abstract class PhotoAnnouncer {
  /// [busy] dice si una foto se está moviendo (arrastre o transición): mientras
  /// sea así no se dice nada, para que el último de varios cambios seguidos no
  /// compita con la transición que aún corre (280 ms frente a 300 ms).
  PhotoAnnouncer({this._busy});

  /// Espera tras el último cambio antes de decir nada.
  static const debounce = Duration(milliseconds: 300);

  final bool Function()? _busy;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Pide anunciar lo que dé [message] cuando pase el antirrebote. Se calcula
  /// al decirlo (no al pedirlo): con el último cambio, el idioma, la foto y el
  /// estado de ese momento.
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

/// (B) El texto de la región viva, que [PhotoAnnouncements] dibuja.
class LiveRegionAnnouncer extends PhotoAnnouncer {
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
class SendAnnouncementAnnouncer extends PhotoAnnouncer {
  SendAnnouncementAnnouncer(this._send, {super.busy});

  final void Function(String message) _send;

  @override
  void deliver(String message) => _send(message);
}

/// Anuncia "Foto {i} de {n}" cada vez que el carrusel cambia de foto, por
/// cualquier vía (swipe, acción, tecla…): el mismo resultado y el mismo
/// anuncio (CA-016-09, CA-016-20).
///
/// Con la región viva (B) dibuja su nodo: **no es una parada de foco** (sin
/// `focusable`), **nace vacío** (ni al crearse ni al recrearse al girar
/// anuncia nada) y mide 1 × 1 dentro de la pantalla (el árbol semántico poda
/// lo que cae fuera o no tiene área). Va como hermano de la tarea, en un
/// `Stack` de la pantalla.
class PhotoAnnouncements extends ConsumerStatefulWidget {
  const PhotoAnnouncements({
    super.key,
    required this.carousel,
    required this.message,
  });

  final PhotoCarouselController carousel;

  /// El estado de la foto que se ve ahora (`photoState`), con el idioma y la
  /// salud del momento.
  final String Function() message;

  @override
  ConsumerState<PhotoAnnouncements> createState() => _PhotoAnnouncementsState();
}

class _PhotoAnnouncementsState extends ConsumerState<PhotoAnnouncements> {
  late final PhotoAnnouncer _announcer;
  late int _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.carousel.index;
    _announcer = switch (ref.read(photoAnnouncerModeProvider)) {
      PhotoAnnouncerMode.liveRegion => LiveRegionAnnouncer(busy: _busy),
      PhotoAnnouncerMode.announcement => SendAnnouncementAnnouncer(
        _send,
        busy: _busy,
      ),
    };
    widget.carousel.addListener(_onChange);
  }

  bool _busy() => widget.carousel.isMoving;

  void _send(String message) {
    if (!mounted) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
  }

  void _onChange() {
    final index = widget.carousel.index;
    if (index == _shown) return;
    _shown = index;
    _announcer.announce(() => mounted ? widget.message() : '');
  }

  @override
  void didUpdateWidget(PhotoAnnouncements old) {
    super.didUpdateWidget(old);
    if (old.carousel != widget.carousel) {
      old.carousel.removeListener(_onChange);
      widget.carousel.addListener(_onChange);
      _shown = widget.carousel.index;
    }
  }

  @override
  void dispose() {
    widget.carousel.removeListener(_onChange);
    _announcer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcer = _announcer;
    if (announcer is! LiveRegionAnnouncer) return const SizedBox.shrink();
    return ValueListenableBuilder<String>(
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
}
