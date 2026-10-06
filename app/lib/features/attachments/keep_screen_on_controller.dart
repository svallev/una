import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/platform/screen_awake.dart';
import '../settings/settings_controller.dart';

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const ChannelScreenAwake(),
);

/// Pantalla siempre activa (CA-015-04, D10 enmendada; CA-007-12, CA-008-13,
/// CA-009-16): mientras se ve la tarea actual con imagen, PDF o web (en
/// vertical o en horizontal), con el ajuste encendido en Ajustes y la app en
/// primer plano, **sin límite de tiempo** (ya no hay los 10 minutos sin tocar
/// ni cuentan los toques). El estado es si está encendida.
final keepScreenOnProvider = NotifierProvider<KeepScreenOnController, bool>(
  KeepScreenOnController.new,
);

class KeepScreenOnController extends Notifier<bool> {
  final Set<Object> _showing = {};
  bool _enabled = false;
  bool _foreground = true;
  bool _on = false;
  AppLifecycleListener? _lifecycle;

  @override
  bool build() {
    // El ajuste de Ajustes (apagado por defecto). Se lee y se escucha, no se
    // observa: observarlo reconstruiría el controlador y soltaría la petición.
    _enabled = ref.read(settingsProvider).keepScreenOn;
    ref.listen(settingsProvider.select((s) => s.keepScreenOn), (_, value) {
      _enabled = value;
      _apply();
    });
    final awake = ref.read(screenAwakeProvider);
    _lifecycle = AppLifecycleListener(
      // Cualquier estado distinto de `resumed` (`inactive`, `hidden`,
      // `paused`) retira la petición (CA-015-04d).
      onStateChange: (s) => _setForeground(s == AppLifecycleState.resumed),
    );
    ref.onDispose(() {
      _lifecycle?.dispose();
      if (_on) unawaited(awake.keepOn(false));
    });
    return false;
  }

  /// [owner] (la tarea actual con imagen, PDF o web) se ve o deja de verse.
  void showing(Object owner, {required bool visible}) {
    if (!ref.mounted) return;
    if (visible) {
      _showing.add(owner);
    } else {
      _showing.remove(owner);
    }
    _apply();
  }

  void _setForeground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    _apply();
  }

  void _apply() {
    final on = _enabled && _foreground && _showing.isNotEmpty;
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

  /// False para una tarea sin adjunto o con "Adjunto no disponible".
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
