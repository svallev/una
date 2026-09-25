import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;
Set<String> _keys(Map<String, dynamic> m) =>
    m.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  test('P7: ES y EN tienen exactamente las mismas claves y ninguna vacía', () {
    final es = _arb('es'), en = _arb('en');
    expect(_keys(en), _keys(es));
    for (final m in [es, en]) {
      for (final k in _keys(m)) {
        expect((m[k] as String).trim(), isNotEmpty, reason: k);
      }
    }
  });

  test('P7: todas las claves de la plantilla tienen descripción', () {
    final es = _arb('es');
    for (final k in _keys(es)) {
      expect(es['@$k'], isA<Map<String, dynamic>>(), reason: '@$k');
    }
  });

  test('P7: el nombre de la app no aparece literal fuera de lo generado', () {
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      final generated =
          f.path.endsWith('.g.dart') || f.path.contains('/l10n/generated/');
      if (!f.path.endsWith('.dart') || generated) {
        continue;
      }
      if (RegExp(r"'[Uu]na\.'").hasMatch(f.readAsStringSync())) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
