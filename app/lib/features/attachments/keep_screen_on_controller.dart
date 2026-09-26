import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/platform/screen_awake.dart';

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const ChannelScreenAwake(),
);

/// Pantalla encendida con adjuntos (CA-007-12): mientras se ve la tarea actual
/// con imagen o su visor, con el ajuste activo, la app en primer plano y
/// menos de 10 minutos sin tocar la pantalla. El estado es si está encendida.
final keepScreenOnProvider = NotifierProvider<KeepScreenOnController, bool>(
  KeepScreenOnController.new,
);

class KeepScreenOnController extends Notifier<bool> {
  /// Sin tocar la pantalla durante este tiempo, vuelven el apagado y el
  /// bloqueo normales.
  static const idleLimit = Duration(minutes: 10);

  final Set<Object> _showing = {};
  bool _enabled = true;
  bool _foreground = true;
  bool _idle = false;
  bool _on = false;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  bool build() {
    _enabled = ref.read(bootStateProvider).keepScreenOn;
    final awake = ref.read(screenAwakeProvider);
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _setForeground(s == AppLifecycleState.resumed),
    );
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      if (_on) unawaited(awake.keepOn(false));
    });
    return false;
  }

  /// [owner] (la tarea actual con imagen o el visor) se ve o deja de verse.
  void showing(Object owner, {required bool visible}) {
    if (!ref.mounted) return;
    final wasEmpty = _showing.isEmpty;
    if (visible) {
      _showing.add(owner);
    } else {
      _showing.remove(owner);
    }
    // Entrar en la pantalla cuenta como usarla.
    if (wasEmpty && _showing.isNotEmpty) _restart();
    _apply();
  }

  /// Un toque en cualquier parte reinicia los 10 minutos.
  void touched() {
    if (_showing.isEmpty) return;
    _restart();
    _apply();
  }

  /// El ajuste de la spec 010.
  void setEnabled(bool value) {
    _enabled = value;
    _apply();
  }

  void _setForeground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    if (value) _restart();
    _apply();
  }

  void _restart() {
    _idle = false;
    _timer?.cancel();
    _timer = Timer(idleLimit, () {
      _idle = true;
      _apply();
    });
  }

  void _apply() {
    final on = _enabled && _foreground && _showing.isNotEmpty && !_idle;
    if (on == _on || !ref.mounted) return;
    _on = state = on;
    unawaited(ref.read(screenAwakeProvider).keepOn(on));
  }
}

/// Mientras su ruta está delante (sin menú, editor ni listado encima), pide la
/// pantalla encendida.
class KeepScreenOnWhileVisible extends ConsumerStatefulWidget {
  const KeepScreenOnWhileVisible({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// False para una tarea sin imagen.
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<KeepScreenOnWhileVisible> createState() =>
      _KeepScreenOnWhileVisibleState();
}

class _KeepScreenOnWhileVisibleState
    extends ConsumerState<KeepScreenOnWhileVisible> {
  bool? _visible;
  late final KeepScreenOnController _controller = ref.read(
    keepScreenOnProvider.notifier,
  );

  void _update() {
    final visible = widget.enabled && (ModalRoute.isCurrentOf(context) ?? true);
    if (visible == _visible) return;
    _visible = visible;
    // Fuera de la construcción: cambia el estado de un proveedor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visible == visible) {
        _controller.showing(this, visible: visible);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void didUpdateWidget(KeepScreenOnWhileVisible old) {
    super.didUpdateWidget(old);
    _update();
  }

  @override
  void dispose() {
    final controller = _controller;
    final owner = this;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => controller.showing(owner, visible: false))
      ..scheduleFrame();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
