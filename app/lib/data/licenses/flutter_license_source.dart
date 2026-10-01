import 'package:flutter/foundation.dart';

import '../../domain/entities/license_package.dart';
import '../../domain/ports/license_source.dart';

/// [LicenseSource] sobre el registro de licencias de Flutter (`LicenseRegistry`:
/// `NOTICES` del motor y los paquetes, más lo que añade `registerBundledLicenses`).
///
/// Agrupa por nombre de elemento, sin repetir un mismo texto, en orden
/// alfabético sin distinguir mayúsculas (CA-012-03). Solo se lee al llamar a
/// [load], nunca antes del primer fotograma (CA-012-16).
class FlutterLicenseSource implements LicenseSource {
  /// [entries] es solo para los tests; por defecto, `LicenseRegistry.licenses`.
  FlutterLicenseSource({Stream<LicenseEntry> Function()? entries})
    : _entries = entries ?? (() => LicenseRegistry.licenses);

  final Stream<LicenseEntry> Function() _entries;

  @override
  Future<List<LicensePackage>> load() async {
    final byName = <String, List<LicenseText>>{};
    await for (final entry in _entries()) {
      // Una licencia puede ser de varios elementos: se trocea una sola vez.
      final text = LicenseText([
        for (final p in entry.paragraphs) (text: p.text, indent: p.indent),
      ]);
      for (final raw in entry.packages) {
        final name = raw.trim();
        if (name.isEmpty) continue;
        final texts = byName.putIfAbsent(name, () => []);
        if (!texts.contains(text)) texts.add(text);
      }
    }
    final names = byName.keys.toList()..sort(compareLicenseNames);
    return [for (final n in names) LicensePackage(name: n, texts: byName[n]!)];
  }
}
