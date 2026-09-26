import 'dart:convert';

import 'package:flutter/services.dart';

/// Carga las fuentes empaquetadas (FontManifest) para que los goldens usen
/// Archivo, Space Mono y los iconos reales en lugar de la fuente de pruebas.
///
/// Obligatoria en todo test que mida (anchos, desbordamientos, texto al
/// 200 %): con la fuente de pruebas cada letra mide 1 em y aparecen
/// desbordamientos falsos (CLAUDE.md, Convenciones).
Future<void> loadAppFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
