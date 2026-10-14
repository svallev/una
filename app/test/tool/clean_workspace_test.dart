import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `tools/clean-workspace.sh` (skill `/post-merge`, sin spec): borra solo lo regenerable y sin
/// seguimiento, en simulación por defecto. Cada prueba arma un repositorio git de juguete y un
/// HOME falso, así nunca toca el repositorio real ni las cachés de la máquina.
final _script = File('../tools/clean-workspace.sh').absolute.path;

void main() {
  late Directory repo;
  late Directory home;

  void git(List<String> args) {
    final r = Process.runSync('git', args, workingDirectory: repo.path);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }

  File put(String rel, [String content = 'x']) => File('${repo.path}/$rel')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  bool exists(String rel) =>
      FileSystemEntity.typeSync('${repo.path}/$rel', followLinks: false) !=
      FileSystemEntityType.notFound;

  ProcessResult run(List<String> args) => Process.runSync(
    'bash',
    [_script, ...args],
    workingDirectory: repo.path,
    environment: {
      'HOME': home.path,
      'ANDROID_HOME': '${home.path}/sdk',
      'PATH': Platform.environment['PATH']!,
    },
    includeParentEnvironment: false,
  );

  setUp(() {
    final tmp = Directory.systemTemp.createTempSync('clean_ws_');
    repo = Directory('${tmp.path}/repo')..createSync();
    home = Directory('${tmp.path}/home')..createSync();
    git(['init', '-q']);
    put('app/lib/main.dart');
    put(
      'specs/020-x/spec.md',
      '# Spec\n\n- **Estado:** **Implementada parcialmente** (hoy)\n',
    );
    put(
      'specs/019-y/spec.md',
      '# Spec\n\n- **Estado:** **Implementada** (ayer)\n',
    );
    put(
      'app/android/gradle/wrapper/gradle-wrapper.properties',
      'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.8.0-all.zip\n',
    );
    git(['add', '.']);
    git(['-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'init']);
    put('app/build/app/outputs/a.apk');
    put('app/build/mastg-020/evidence.txt');
    put('app/build/mastg-019/evidence.txt');
    put('app/.dart_tool/hooks_runner/lib.dylib');
    put('app/android/.gradle/x.bin');
    put('spikes/s7/app/build/out.apk');
    put('spikes/s7/.gradle/x.bin');
    put('docs/.DS_Store');
  });

  tearDown(() => repo.parent.deleteSync(recursive: true));

  test('post-merge: sin --apply no borra nada y lista lo que borraría', () {
    final r = run([]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(r.stdout, contains('app/.dart_tool'));
    expect(r.stdout, contains('Nada borrado'));
    expect(exists('app/build/app/outputs/a.apk'), isTrue);
    expect(exists('app/.dart_tool/hooks_runner/lib.dylib'), isTrue);
  });

  test(
    'post-merge: --apply borra la compilación, los spikes y los .DS_Store',
    () {
      final r = run(['--apply']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      for (final gone in [
        'app/build/app',
        'app/.dart_tool',
        'app/android/.gradle',
        'spikes/s7/app/build',
        'spikes/s7/.gradle',
        'docs/.DS_Store',
      ]) {
        expect(exists(gone), isFalse, reason: gone);
      }
      expect(exists('app/lib/main.dart'), isTrue);
      expect(exists('specs/020-x/spec.md'), isTrue);
    },
  );

  test('post-merge: conserva la evidencia MASTG de una spec sin terminar', () {
    run(['--apply']);
    expect(exists('app/build/mastg-020/evidence.txt'), isTrue);
    expect(exists('app/build/mastg-019'), isFalse);
  });

  test('post-merge: nunca borra una ruta con archivos en git', () {
    put('app/build/tracked.txt');
    git(['add', '-f', 'app/build/tracked.txt']);
    final r = run(['--apply']);
    expect(exists('app/build/tracked.txt'), isTrue);
    expect(r.stderr, contains('tiene archivos en git'));
  });

  test('post-merge: no sigue enlaces simbólicos', () {
    final outside = Directory('${repo.parent.path}/outside')..createSync();
    File('${outside.path}/keep.txt').writeAsStringSync('x');
    Link('${repo.path}/app/build/link').createSync(outside.path);
    Directory('${repo.path}/app/.dart_tool').deleteSync(recursive: true);
    Link('${repo.path}/app/.dart_tool').createSync(outside.path);
    run(['--apply']);
    expect(File('${outside.path}/keep.txt').existsSync(), isTrue);
  });

  test('post-merge: --global borra solo las versiones de Gradle y las imágenes obsoletas', () {
    for (final d in [
      '.gradle/caches/9.7.1',
      '.gradle/caches/9.8.0',
      '.gradle/caches/modules-2',
      '.gradle/wrapper/dists/gradle-9.7.1-all',
      '.gradle/wrapper/dists/gradle-9.8.0-all',
      'sdk/system-images/android-37/google_apis/arm64-v8a',
      'sdk/system-images/android-36/google_apis/arm64-v8a',
    ]) {
      Directory('${home.path}/$d').createSync(recursive: true);
    }
    File('${home.path}/.android/avd/p.avd/config.ini')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'image.sysdir.1=system-images/android-37/google_apis/arm64-v8a/\n',
      );
    bool has(String d) => Directory('${home.path}/$d').existsSync();

    expect(run(['--global']).exitCode, 0);
    expect(has('.gradle/caches/9.7.1'), isTrue, reason: 'simulación');

    final r = run(['--global', '--apply']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(has('.gradle/caches/9.7.1'), isFalse);
    expect(has('.gradle/wrapper/dists/gradle-9.7.1-all'), isFalse);
    expect(has('sdk/system-images/android-36/google_apis/arm64-v8a'), isFalse);
    expect(has('.gradle/caches/9.8.0'), isTrue);
    expect(has('.gradle/caches/modules-2'), isTrue);
    expect(has('.gradle/wrapper/dists/gradle-9.8.0-all'), isTrue);
    expect(has('sdk/system-images/android-37/google_apis/arm64-v8a'), isTrue);
    // --global no toca el repositorio.
    expect(exists('app/.dart_tool/hooks_runner/lib.dylib'), isTrue);
  });

  test('post-merge: sin la versión del wrapper no toca la caché de Gradle', () {
    File('${repo.path}/app/android/gradle/wrapper/gradle-wrapper.properties')
        .writeAsStringSync('nada\n');
    Directory('${home.path}/.gradle/caches/9.7.1').createSync(recursive: true);
    final r = run(['--global', '--apply']);
    expect(Directory('${home.path}/.gradle/caches/9.7.1').existsSync(), isTrue);
    expect(r.stderr, contains('no se lee la versión de Gradle'));
  });

  test('post-merge: una opción desconocida es un error de uso', () {
    expect(run(['--borrar-todo']).exitCode, 2);
  });
}
