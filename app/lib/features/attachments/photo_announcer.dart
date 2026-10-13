import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/live_region_announcer.dart';
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

/// Anuncia "Foto {i} de {n}" cada vez que el carrusel cambia de foto, por
/// cualquier vía (swipe, acción, tecla…): el mismo resultado y el mismo
/// anuncio (CA-016-09, CA-016-20).
///
/// Con la región viva (B) dibuja su nodo ([LiveRegionNode]): no es una parada
/// de foco, nace vacío (ni al crearse ni al recrearse al girar anuncia nada) y
/// mide 1 × 1 dentro de la pantalla. Va como hermano de la tarea, en un
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
  late final DebouncedAnnouncer _announcer;
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
    return LiveRegionNode(announcer: announcer);
  }
}
