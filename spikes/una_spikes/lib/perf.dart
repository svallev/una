// SPIKE — medición de arranque (S1) y de fotogramas (S2). Código desechable.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const _perf = MethodChannel('spike/perf');

final Stopwatch startup = Stopwatch();

Future<void> reportFullyDrawn(Map<String, Object?> marks) async {
  // ignore: avoid_print
  print('SPIKE_S1 ${jsonEncode(marks)}');
  try {
    await _perf.invokeMethod('reportFullyDrawn');
  } on MissingPluginException {
    // web: no hay reportFullyDrawn
  }
}

/// Recoge FrameTiming entre start() y stop(); devuelve estadísticas.
class FrameRecorder {
  final List<FrameTiming> _frames = [];
  bool _on = false;

  void start() {
    _frames.clear();
    if (!_on) SchedulerBinding.instance.addTimingsCallback(_cb);
    _on = true;
  }

  void _cb(List<FrameTiming> t) => _frames.addAll(t);

  /// Flutter entrega FrameTiming por lotes (≈1 s en release): esperar antes de cerrar.
  Future<FrameStats> stopAfterFlush(String label) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return stop(label);
  }

  FrameStats stop(String label) {
    if (_on) SchedulerBinding.instance.removeTimingsCallback(_cb);
    _on = false;
    final totals = _frames.map((f) => f.totalSpan.inMicroseconds / 1000).toList()..sort();
    final raster = _frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()..sort();
    final build = _frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()..sort();
    double pct(List<double> l, double p) => l.isEmpty ? 0 : l[((l.length - 1) * p).round()];
    final s = FrameStats(
      label: label,
      frames: totals.length,
      jank16: totals.where((v) => v > 16.7).length,
      jank32: totals.where((v) => v > 32).length,
      p50: pct(totals, .5),
      p90: pct(totals, .9),
      p99: pct(totals, .99),
      rasterP90: pct(raster, .9),
      buildP90: pct(build, .9),
    );
    // ignore: avoid_print
    print('SPIKE_S2 ${jsonEncode(s.toJson())}');
    return s;
  }
}

class FrameStats {
  FrameStats({required this.label, required this.frames, required this.jank16, required this.jank32, required this.p50, required this.p90, required this.p99, required this.rasterP90, required this.buildP90});
  final String label;
  final int frames, jank16, jank32;
  final double p50, p90, p99, rasterP90, buildP90;

  Map<String, Object> toJson() => {
        'label': label, 'frames': frames, 'jank>16.7ms': jank16, 'jank>32ms': jank32,
        'p50': p50, 'p90': p90, 'p99': p99, 'rasterP90': rasterP90, 'buildP90': buildP90,
      };

  @override
  String toString() =>
      '$label · $frames fot. · >16,7 ms: $jank16 · >32 ms: $jank32\n'
      'p50 ${p50.toStringAsFixed(1)} · p90 ${p90.toStringAsFixed(1)} · p99 ${p99.toStringAsFixed(1)} ms\n'
      'raster p90 ${rasterP90.toStringAsFixed(1)} · build p90 ${buildP90.toStringAsFixed(1)} ms';
}
