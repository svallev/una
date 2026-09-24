// Comprueba la licencia de todos los paquetes de pub.dev de `pubspec.lock`
// (threat-model §5: MIT/BSD/Apache/OFL/zlib; nada de GPL). Compensa que la
// revisión de dependencias de GitHub no entienda las licencias de pub.dev.
//
//   dart run tool/check_licenses.dart   (tras `flutter pub get`)
//
// Lee el archivo LICENSE de cada paquete en la caché de pub y lo clasifica por
// su texto. Falla ante una licencia prohibida o desconocida.
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Textos que identifican cada licencia permitida (se exigen todos).
const _allowed = <String, List<String>>{
  'MIT': ['permission is hereby granted, free of charge'],
  'BSD-3-Clause': [
    'redistribution and use in source and binary forms',
    'neither the name',
  ],
  'BSD-2-Clause': ['redistribution and use in source and binary forms'],
  'Apache-2.0': ['apache license', 'version 2.0'],
  'Zlib': ["this software is provided 'as-is'"],
  'OFL-1.1': ['sil open font license'],
};

/// Licencias prohibidas en la app (se buscan antes que las permitidas).
const _denied = [
  'gnu general public license',
  'gnu lesser general public license',
  'gnu affero general public license',
  'server side public license',
];

const _licenseFiles = ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING'];

void main() {
  final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final roots = {
    for (final p in (config['packages'] as List).cast<Map<String, dynamic>>())
      p['name'] as String: Uri.parse(p['rootUri'] as String),
  };
  final configDir = File('.dart_tool/package_config.json').absolute.parent.uri;

  final problems = <String>[];
  final summary = <String, int>{};
  final packages = (lock['packages'] as YamlMap).cast<String, YamlMap>();
  for (final MapEntry(key: name, value: info) in packages.entries) {
    if (info['source'] != 'hosted') continue; // SDK de Flutter: BSD-3
    final root = roots[name];
    if (root == null) {
      problems.add('$name: no está en package_config.json (¿falta pub get?)');
      continue;
    }
    final dir = Directory.fromUri(configDir.resolveUri(root));
    final file = _licenseFiles
        .map((f) => File('${dir.path}/$f'))
        .where((f) => f.existsSync())
        .firstOrNull;
    if (file == null) {
      problems.add('$name ${info['version']}: sin archivo de licencia');
      continue;
    }
    final text = file.readAsStringSync().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final denied = _denied.where(text.contains).firstOrNull;
    if (denied != null) {
      problems.add('$name ${info['version']}: licencia prohibida ($denied)');
      continue;
    }
    final license = _allowed.entries
        .where((e) => e.value.every(text.contains))
        .map((e) => e.key)
        .firstOrNull;
    if (license == null) {
      problems.add('$name ${info['version']}: licencia no reconocida');
      continue;
    }
    summary.update(license, (n) => n + 1, ifAbsent: () => 1);
  }

  stdout.writeln(
    'Licencias: ${summary.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
  );
  if (problems.isNotEmpty) {
    stderr.writeln(
      'Dependencias fuera de la política (threat-model §5):\n - ${problems.join('\n - ')}',
    );
    exit(1);
  }
}
