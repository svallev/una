import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.g.dart';
import '../../domain/entities/attachment.dart';
import 'attachment_health.dart';
import 'group_health.dart';
import 'photo_missing_box.dart';
import 'photo_swipe.dart';
import 'zoomable_photo.dart';

/// Controlador de desplazamiento de **una** foto del carrusel: al dejar de
/// verse, recuerda dónde estaba y, si vuelve, empieza ahí (CA-016-10: cada foto
/// conserva su desplazamiento mientras la tarea siga a la vista). El zoom, en
/// cambio, no se conserva nunca ([ZoomablePhoto] lo suelta al levantar los
/// dedos).
class PhotoScrollController extends ScrollController {
  double _saved = 0;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => ScrollPositionWithSingleContext(
    physics: physics,
    context: context,
    initialPixels: _saved,
    oldPosition: oldPosition,
    debugLabel: debugLabel,
  );

  @override
  void detach(ScrollPosition position) {
    if (position.hasPixels) _saved = position.pixels;
    super.detach(position);
  }
}

/// Lo que la pantalla principal necesita del carrusel (spec 016): qué foto se
/// ve, el desplazamiento de **esa** foto (para las acciones del lector y el
/// teclado, [ImageScroll.controller]) y cambiar de foto sin gesto (las acciones
/// "Foto siguiente" y "Foto anterior", CA-016-20). Avisa al cambiar de foto.
class PhotoCarouselController extends ChangeNotifier {
  int _index = 0;
  List<Attachment> _photos = const [];
  _PhotoCarouselState? _state;
  final _scrolls = <String, PhotoScrollController>{};
  ScrollController? _idle;

  /// Posición de la foto que se ve (0 es la primera).
  int get index => _index;

  /// Desplazamiento de la foto que se ve. Antes de montar el carrusel, uno
  /// inerte (sin posición): nada que desplazar.
  ScrollController get scroll => _index < _photos.length
      ? scrollOf(_photos[_index].id)
      : (_idle ??= ScrollController());

  /// Desplazamiento de la foto [id]: uno por foto vista.
  ScrollController scrollOf(String id) =>
      _scrolls.putIfAbsent(id, PhotoScrollController.new);

  /// La foto siguiente (con la última, la primera), como el swipe a la
  /// izquierda. Instantáneo con reducir movimiento.
  void next() => _state?._go(1);

  /// La foto anterior (con la primera, la última).
  void previous() => _state?._go(-1);

  void _attach(_PhotoCarouselState state) => _state = state;

  void _detach(_PhotoCarouselState state) {
    if (_state == state) _state = null;
  }

  void _setPhotos(List<Attachment> photos) {
    _photos = photos;
    final ids = {for (final a in photos) a.id};
    _scrolls.removeWhere((id, c) {
      if (ids.contains(id)) return false;
      c.dispose();
      return true;
    });
  }

  void _changed() => notifyListeners();

  @override
  void dispose() {
    for (final c in _scrolls.values) {
      c.dispose();
    }
    _scrolls.clear();
    _idle?.dispose();
    super.dispose();
  }
}

/// Carrusel de las fotos de una tarea (spec 016, CA-016-08 a 10, 22 y 23):
/// **infinito** (tras la última, la primera; también con 2), con la foto actual
/// y solo la vecina hacia la que se arrastra montadas, transición de 280 ms con
/// la curva del token (instantánea con reducir movimiento), un desplazamiento
/// por foto vista y las contiguas calentadas en la caché de imágenes (como
/// mucho 3 versiones de pantalla decodificadas). Una foto que falta ocupa su
/// sitio como "Foto no disponible" y se lo dice a la salud del grupo.
///
/// Es solo la zona de las fotos: el pie, los puntos y la lectura los pone la
/// pantalla principal. Con una sola foto no hay swipe ni vecina.
class PhotoCarousel extends ConsumerStatefulWidget {
  const PhotoCarousel({super.key, required this.photos, this.controller});

  /// Las fotos, en su orden (1 a 10).
  final List<Attachment> photos;

  /// Si no se da, el carrusel lleva el suyo.
  final PhotoCarouselController? controller;

  @override
  ConsumerState<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends ConsumerState<PhotoCarousel>
    with SingleTickerProviderStateMixin {
  late PhotoCarouselController _ctl;
  bool _ownsController = false;

  /// Desplazamiento horizontal (dp) de la foto actual: negativo a la izquierda.
  final _drag = ValueNotifier<double>(0);

  /// Lado de la vecina montada: 1 a la derecha (la siguiente), -1 a la
  /// izquierda (la anterior), 0 ninguna.
  int _side = 0;
  double _width = 0;
  bool _dragging = false;

  late final _anim = AnimationController(
    vsync: this,
    duration: UnaMotion.photoSwipe,
    // El tiempo de la transición no se acorta solo: con reducir movimiento no
    // se anima y punto (CA-016-22).
    animationBehavior: AnimationBehavior.preserve,
  );
  double _from = 0;
  double _to = 0;
  PhotoSwipeChange? _pending;

  final _healthSubs = <String, ProviderSubscription<AttachmentHealthState>>{};
  int _warmGeneration = 0;

  List<Attachment> get _photos => widget.photos;
  int get _count => _photos.length;
  int _wrap(int i) => _count == 0 ? 0 : (i % _count + _count) % _count;

  @override
  void initState() {
    super.initState();
    _bindController();
    _anim
      ..addListener(() {
        _drag.value =
            _from +
            (_to - _from) * UnaMotion.photoSwipeCurve.transform(_anim.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _complete(_pending);
      });
    _syncHealth();
    // Las contiguas se calientan tras el primer fotograma: este no espera a
    // ninguna otra foto (CA-016-08).
    WidgetsBinding.instance.addPostFrameCallback((_) => _warm());
  }

  void _bindController() {
    final given = widget.controller;
    _ownsController = given == null;
    _ctl = given ?? PhotoCarouselController();
    _ctl
      .._attach(this)
      .._setPhotos(_photos);
    if (_ctl._index >= _count) _ctl._index = math.max(0, _count - 1);
  }

  @override
  void didUpdateWidget(PhotoCarousel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _ctl._detach(this);
      if (_ownsController) _ctl.dispose();
      _bindController();
    }
    final sameIds =
        old.photos.length == _count &&
        [for (final a in old.photos) a.id].toString() ==
            [for (final a in _photos) a.id].toString();
    if (!sameIds) {
      final id = _ctl._index < old.photos.length
          ? old.photos[_ctl._index].id
          : null;
      final kept = _photos.indexWhere((a) => a.id == id);
      _ctl._setPhotos(_photos);
      final index = kept >= 0 ? kept : math.min(_ctl._index, _count - 1);
      if (index != _ctl._index) {
        _ctl._index = math.max(0, index);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _ctl._changed();
        });
      }
      _syncHealth();
      _warm();
    }
  }

  @override
  void dispose() {
    _warmGeneration++;
    for (final s in _healthSubs.values) {
      s.close();
    }
    _healthSubs.clear();
    _anim.dispose();
    _drag.dispose();
    _ctl._detach(this);
    if (_ownsController) _ctl.dispose();
    super.dispose();
  }

  // --- Gesto y transición ---------------------------------------------------

  void _setSide(int side) {
    if (_side != side) setState(() => _side = side);
  }

  void _onStart() {
    // Un swipe nuevo con la transición en marcha: la anterior termina ya.
    if (_anim.isAnimating) _complete(_pending);
    _dragging = true;
  }

  void _onUpdate(double dx) {
    if (!_dragging) return;
    _drag.value = dx;
    if (dx != 0) _setSide(dx < 0 ? 1 : -1);
  }

  void _onEnd(PhotoSwipeChange? change, double velocity) {
    _dragging = false;
    _settle(change);
    _warm();
  }

  void _onCancel() {
    _dragging = false;
    _settle(null);
  }

  /// Lleva la foto hasta su sitio: a la vecina ([change]) o de vuelta a la
  /// actual (`null`). Instantáneo con reducir movimiento.
  void _settle(PhotoSwipeChange? change) {
    final target = switch (change) {
      PhotoSwipeChange.next => -_width,
      PhotoSwipeChange.previous => _width,
      null => 0.0,
    };
    final from = _drag.value;
    if (MediaQuery.disableAnimationsOf(context) ||
        _width <= 0 ||
        from == target) {
      _complete(change);
      return;
    }
    if (change != null) _setSide(change == PhotoSwipeChange.next ? 1 : -1);
    _from = from;
    _to = target;
    _pending = change;
    _anim.forward(from: 0);
  }

  /// La foto ya está en su sitio: si hubo cambio, la vecina pasa a ser la
  /// actual y el desplazamiento vuelve a 0 (un solo `setState`).
  void _complete(PhotoSwipeChange? change) {
    _anim.stop();
    _pending = null;
    _drag.value = 0;
    final delta = switch (change) {
      PhotoSwipeChange.next => 1,
      PhotoSwipeChange.previous => -1,
      null => 0,
    };
    setState(() {
      _side = 0;
      if (delta != 0) _ctl._index = _wrap(_ctl._index + delta);
    });
    if (delta != 0) {
      _ctl._changed();
      _syncHealth();
    }
    _warm();
  }

  /// "Foto siguiente" / "Foto anterior" sin gesto (CA-016-20).
  void _go(int direction) {
    if (_count < 2 || _dragging) return;
    if (_anim.isAnimating) _complete(_pending);
    _settle(direction > 0 ? PhotoSwipeChange.next : PhotoSwipeChange.previous);
  }

  // --- Salud y caché de las contiguas ---------------------------------------

  /// Índices de la foto actual y sus contiguas (en un grupo, también la última
  /// junto a la primera).
  Set<int> get _triple => {
    for (final d in const [-1, 0, 1])
      if (_count > 0) _wrap(_ctl._index + d),
  };

  /// Vigila la salud de la foto a la vista y las contiguas: regenera sus
  /// derivadas de una en una y, si una no se puede ni regenerar, se lo dice a
  /// la salud del grupo (`reportMissing`, T-016-13).
  void _syncHealth() {
    final want = {for (final i in _triple) _photos[i].id: _photos[i]};
    for (final id in _healthSubs.keys.toList()) {
      if (!want.containsKey(id)) _healthSubs.remove(id)!.close();
    }
    for (final a in want.values) {
      _healthSubs.putIfAbsent(
        a.id,
        () => ref.listenManual(attachmentHealthProvider(a), (_, next) {
          if (next.health == AttachmentHealth.missing) _reportMissing(a.id);
        }),
      );
    }
  }

  void _reportMissing(String id) {
    if (!mounted) return;
    ref
        .read(groupHealthProvider(AttachmentGroupKey(_photos)).notifier)
        .reportMissing(id);
  }

  /// Calienta en la caché la versión de pantalla de las dos contiguas, de una
  /// en una, y suelta las demás: como mucho 3 decodificadas (CA-016-23).
  Future<void> _warm() async {
    if (!mounted || _count < 2) return;
    final generation = ++_warmGeneration;
    final images = ref.read(attachmentImagesProvider);
    final keep = _triple;
    for (var i = 0; i < _count; i++) {
      if (!keep.contains(i)) {
        unawaited(images.stored(_photos[i].screenPath).evict());
      }
    }
    for (final i in keep) {
      if (i == _ctl._index) continue;
      if (!mounted || generation != _warmGeneration) return;
      final photo = _photos[i];
      await precacheImage(
        images.stored(photo.screenPath),
        context,
        onError: (_, _) {
          // No se puede decodificar: se regenera desde la completa.
          if (mounted) {
            ref.read(attachmentHealthProvider(photo).notifier).reportBroken();
          }
        },
      );
    }
  }

  // --- Dibujo ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    if (photos.isEmpty) return const SizedBox.shrink();
    final missing = ref.watch(
      groupHealthProvider(AttachmentGroupKey(photos))
          .select((state) => state.missingIds),
    );
    final index = _ctl._index;
    final slides = <(int, int)>[
      (index, 0),
      if (_side != 0 && _count >= 2) (_wrap(index + _side), _side),
    ];
    Widget carousel = LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final (i, side) in slides)
              Positioned.fill(
                key: ValueKey(photos[i].id),
                child: _Slide(
                  drag: _drag,
                  offsetSides: side,
                  width: constraints.maxWidth,
                  child: RepaintBoundary(
                    child: _PhotoPage(
                      attachment: photos[i],
                      scroll: _ctl.scrollOf(photos[i].id),
                      missing: missing.contains(photos[i].id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (_count >= 2) {
      carousel = PhotoSwipeDetector(
        onStart: _onStart,
        onUpdate: _onUpdate,
        onEnd: _onEnd,
        onCancel: _onCancel,
        child: carousel,
      );
    }
    return carousel;
  }
}

/// Coloca una foto: la actual sigue al dedo y la vecina viene detrás de ella,
/// a un ancho de distancia.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.drag,
    required this.offsetSides,
    required this.width,
    required this.child,
  });

  final ValueListenable<double> drag;
  final int offsetSides;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: drag,
    child: child,
    builder: (_, dx, child) => Transform.translate(
      offset: Offset(dx + offsetSides * width, 0),
      child: child,
    ),
  );
}

/// Una foto del carrusel, o "Foto no disponible" si falta (en su sitio, con la
/// proporción de la foto para no ocupar más de lo que ocuparía ella).
class _PhotoPage extends ConsumerWidget {
  const _PhotoPage({
    required this.attachment,
    required this.scroll,
    required this.missing,
  });

  final Attachment attachment;
  final ScrollController scroll;
  final bool missing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broken =
        ref.watch(attachmentHealthProvider(attachment)).health ==
        AttachmentHealth.missing;
    if (!missing && !broken) {
      return ZoomablePhoto(attachment: attachment, scroll: scroll);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxWidth *
            attachment.height /
            math.max(1, attachment.width);
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(UnaSpace.l),
            child: SizedBox(
              height: math.min(
                math.max(height, 160),
                math.max(0, constraints.maxHeight - 2 * UnaSpace.l),
              ),
              child: const PhotoMissingBox(),
            ),
          ),
        );
      },
    );
  }
}
