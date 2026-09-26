import 'dart:async';

import 'package:flutter/widgets.dart';

/// Ignora toques y el cierre de la ruta durante [duration] tras montarse: el
/// segundo toque de un doble toque que abrió una hoja no debe activarla ni
/// cerrarla (spec 006, CL-006-5).
class EarlyTapGuard extends StatefulWidget {
  const EarlyTapGuard({super.key, required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  State<EarlyTapGuard> createState() => _EarlyTapGuardState();
}

class _EarlyTapGuardState extends State<EarlyTapGuard> {
  bool _guarding = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, () {
      if (mounted) setState(() => _guarding = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Tocar el fondo de la hoja intenta cerrarla: también se ignora.
    canPop: !_guarding,
    child: IgnorePointer(ignoring: _guarding, child: widget.child),
  );
}
