import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spec 021, T-021-02 (plan §1.1, §5): el arranque y el fondo de la ventana son siempre `paper`.
/// Se lee `res/` tal cual (no hace falta dispositivo): un solo tema claro para claro y oscuro,
/// sin variantes `-night` ni `launch_background`, con el color de los tokens, el *splash* de
/// Android 12+ con el primer plano de la 018 y las barras del sistema por versión.
const _main = 'android/app/src/main';
const _res = '$_main/res';

const _transparent = '@android:color/transparent';
const _allowedLiterals = {
  '@color/paper',
  '@drawable/ic_launcher_foreground',
  _transparent,
  'true',
  'false',
};

/// Un `<style>`: su padre y sus `<item>` (valor y `tools:targetApi`, si lo lleva).
typedef Item = ({String value, String? targetApi});

class Style {
  Style(this.name, this.parent, this.items);
  final String name;
  final String? parent;
  final Map<String, Item> items;
}

String _read(String path) => File(path).readAsStringSync();

/// Carpetas `values*` de `res/` con sus archivos `.xml`.
Map<String, List<File>> _valueDirs() {
  final out = <String, List<File>>{};
  for (final d in Directory(_res).listSync().whereType<Directory>()) {
    final name = d.path.split('/').last;
    if (name == 'values' || name.startsWith('values-')) {
      out[name] = d
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.xml'))
          .toList();
    }
  }
  return out;
}

/// Los estilos de una carpeta `values*` (`styles.xml`).
Map<String, Style> _styles(String dir) {
  final file = File('$_res/$dir/styles.xml');
  if (!file.existsSync()) return {};
  final xml = file.readAsStringSync().replaceAll(
    RegExp(r'<!--[\s\S]*?-->'),
    '',
  );
  final styles = <String, Style>{};
  final style = RegExp(r'<style\s+([^>]*?)(?:/>|>([\s\S]*?)</style>)');
  String? attr(String attrs, String name) =>
      RegExp('$name="([^"]*)"').firstMatch(attrs)?.group(1);
  for (final m in style.allMatches(xml)) {
    final attrs = m.group(1)!;
    final items = <String, Item>{};
    final itemRe = RegExp(r'<item\s+([^>]*?)>\s*([^<]*?)\s*</item>');
    for (final i in itemRe.allMatches(m.group(2) ?? '')) {
      items[attr(i.group(1)!, 'name')!] = (
        value: i.group(2)!,
        targetApi: attr(i.group(1)!, 'tools:targetApi'),
      );
    }
    final name = attr(attrs, 'name')!;
    styles[name] = Style(name, attr(attrs, 'parent'), items);
  }
  return styles;
}

/// Cadena de padres de [name] (el estilo y los suyos) hasta uno de la plataforma.
List<Style> _chain(String name, Map<String, Style> styles) {
  final out = <Style>[];
  String? current = name;
  while (current != null && styles.containsKey(current)) {
    final s = styles[current]!;
    out.add(s);
    current = s.parent;
  }
  return out;
}

/// El estilo de la plataforma del que acaba heredando [name].
String? _platformRoot(String name, Map<String, Style> styles) {
  final chain = _chain(name, styles);
  return chain.isEmpty ? name : chain.last.parent;
}

/// Valor efectivo de [attr] en [name] (el del propio estilo o el del primer padre que lo fije).
String? _effective(String name, String attr, Map<String, Style> styles) {
  for (final s in _chain(name, styles)) {
    final v = s.items[attr]?.value;
    if (v != null) return v;
  }
  return null;
}

String _paperToken() {
  final tokens =
      jsonDecode(_read('../design/tokens.json')) as Map<String, dynamic>;
  Object? find(Object? node) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey('paper')) return node['paper'];
      for (final v in node.values) {
        final r = find(v);
        if (r != null) return r;
      }
    }
    return null;
  }

  final paper = find(tokens)! as Map<String, dynamic>;
  return (paper[r'$value']! as String).toUpperCase();
}

/// Los `<color name="…">#…</color>` de todas las carpetas `values*`.
Map<String, Set<String>> _colors() {
  final out = <String, Set<String>>{};
  for (final files in _valueDirs().values) {
    for (final f in files) {
      final xml = f.readAsStringSync().replaceAll(
        RegExp(r'<!--[\s\S]*?-->'),
        '',
      );
      for (final m in RegExp(
        r'<color\s+name="([^"]+)">\s*([^<]*?)\s*</color>',
      ).allMatches(xml)) {
        out.putIfAbsent(m.group(1)!, () => {}).add(m.group(2)!.toUpperCase());
      }
    }
  }
  return out;
}

void main() {
  final styles = _styles('values');
  final stylesV27 = {...styles, ..._styles('values-v27')};

  group('CA-021-02, 03: un solo tema, sin variante oscura', () {
    test('CA-021-02: no existe ninguna carpeta -night en res/', () {
      final night = Directory(_res)
          .listSync()
          .map((e) => e.path.split('/').last)
          .where((n) => n.contains('night'));
      expect(night, isEmpty);
    });

    test('CA-021-03: ningún launch_background ni <bitmap> en res/ (el arranque es un color liso)', () {
      final files = Directory(_res).listSync(recursive: true).whereType<File>();
      expect(files.where((f) => f.path.contains('launch_background')), isEmpty);
      for (final f in files.where((f) => f.path.endsWith('.xml'))) {
        expect(
          f.readAsStringSync(),
          isNot(contains('<bitmap')),
          reason: f.path,
        );
        expect(
          f.readAsStringSync(),
          isNot(contains('launch_background')),
          reason: f.path,
        );
      }
    });

    test('CA-021-02: LaunchTheme y NormalTheme heredan de un tema claro (nunca Dark ni Black)', () {
      for (final all in [styles, stylesV27]) {
        for (final name in [
          'LaunchTheme',
          'NormalTheme',
          'UnaBars',
          'UnaWindow',
        ]) {
          expect(all, contains(name), reason: name);
          final root = _platformRoot(name, all);
          expect(root, '@android:style/Theme.Light.NoTitleBar', reason: name);
        }
      }
    });

    test('CA-021-02: LaunchTheme y NormalTheme cuelgan de UnaBars, que cuelga de UnaWindow', () {
      for (final all in [styles, stylesV27]) {
        expect(all['LaunchTheme']!.parent, 'UnaBars');
        expect(all['NormalTheme']!.parent, 'UnaBars');
        expect(all['UnaBars']!.parent, 'UnaWindow');
      }
    });

    test('CA-021-02: el manifiesto usa LaunchTheme y NormalTheme', () {
      final manifest = _read('$_main/AndroidManifest.xml');
      expect(manifest, contains('android:theme="@style/LaunchTheme"'));
      expect(
        manifest,
        matches(
          RegExp(
            r'io\.flutter\.embedding\.android\.NormalTheme"\s+android:resource="@style/NormalTheme"',
          ),
        ),
      );
    });
  });

  group('CA-021-04: todo el arranque es el color paper de los tokens', () {
    test('CA-021-04: res/values/colors.xml define paper = tokens.json', () {
      expect(File('$_res/values/colors.xml').existsSync(), isTrue);
      expect(_colors()['paper'], {_paperToken()});
    });

    test('CA-021-04: windowBackground resuelve a @color/paper (fondo liso, también el de la ventana)', () {
      for (final all in [styles, stylesV27]) {
        for (final name in ['LaunchTheme', 'NormalTheme']) {
          expect(
            _effective(name, 'android:windowBackground', all),
            '@color/paper',
            reason: name,
          );
        }
      }
    });

    test('CA-021-01: el splash de Android 12+ tiene fondo paper y la «u.» del primer plano de la 018', () {
      for (final all in [styles, stylesV27]) {
        for (final name in ['LaunchTheme', 'NormalTheme']) {
          expect(
            _effective(name, 'android:windowSplashScreenBackground', all),
            '@color/paper',
            reason: name,
          );
          expect(
            _effective(name, 'android:windowSplashScreenAnimatedIcon', all),
            '@drawable/ic_launcher_foreground',
            reason: name,
          );
          final iconBg = _effective(
            name,
            'android:windowSplashScreenIconBackgroundColor',
            all,
          );
          // Sin color detrás del icono (sin círculo) o, si lo hubiera, paper.
          expect(
            iconBg == null || iconBg == '@color/paper',
            isTrue,
            reason: name,
          );
        }
      }
      expect(
        File('$_res/drawable-nodpi/ic_launcher_foreground.png').existsSync(),
        isTrue,
      );
    });

    test(
      'CA-021-04: el splash no usa la animación ni el icono adaptable entero',
      () {
        for (final s in styles.values) {
          for (final v in s.items.values) {
            expect(v.value, isNot(contains('mipmap')));
          }
          expect(
            s.items.containsKey('android:windowSplashScreenAnimationDuration'),
            isFalse,
          );
        }
      },
    );

    test('CA-021-04: ningún otro color literal en los estilos (solo paper, el icono y transparent)', () {
      for (final dir in _valueDirs().keys) {
        for (final s in _styles(dir).values) {
          for (final e in s.items.entries) {
            expect(
              _allowedLiterals,
              contains(e.value.value),
              reason: '$dir/${s.name}/${e.key}',
            );
          }
        }
        final file = File('$_res/$dir/styles.xml');
        if (file.existsSync()) {
          expect(file.readAsStringSync(), isNot(contains('#')), reason: dir);
        }
      }
    });

    test('CA-021-04: el único color con el valor de paper es paper (sin copias sueltas)', () {
      final paper = _paperToken();
      final named = _colors().entries.where((e) => e.value.contains(paper));
      expect(named.map((e) => e.key), ['paper']);
    });

    test(
      'CA-021-04: los atributos de Android 10 y 12 llevan tools:targetApi',
      () {
        final window = styles['UnaWindow']!;
        for (final a in [
          'android:windowSplashScreenBackground',
          'android:windowSplashScreenAnimatedIcon',
        ]) {
          expect(window.items[a]?.targetApi, '31', reason: a);
        }
        for (final a in [
          'android:enforceStatusBarContrast',
          'android:enforceNavigationBarContrast',
          'android:forceDarkAllowed',
        ]) {
          expect(window.items[a]?.targetApi, '29', reason: a);
        }
      },
    );
  });

  group('CA-021-09: barras del sistema desde el arranque', () {
    test('CA-021-09: UnaWindow no pone velo en las barras (contraste forzado apagado)', () {
      final w = styles['UnaWindow']!;
      expect(w.items['android:enforceStatusBarContrast']?.value, 'false');
      expect(w.items['android:enforceNavigationBarContrast']?.value, 'false');
    });

    test('CA-021-05: la app no se deja oscurecer por el sistema (forceDarkAllowed = false)', () {
      for (final name in ['LaunchTheme', 'NormalTheme']) {
        for (final all in [styles, stylesV27]) {
          expect(_effective(name, 'android:forceDarkAllowed', all), 'false');
        }
      }
    });

    test('CA-021-09: API 26 (values/): barra de estado transparente con iconos oscuros y barra de navegación del sistema', () {
      final bars = styles['UnaBars']!;
      expect(bars.items['android:statusBarColor']?.value, _transparent);
      expect(bars.items['android:windowLightStatusBar']?.value, 'true');
      // Excepción de Android 8.0: no existe windowLightNavigationBar; la barra queda oscura.
      expect(bars.items.containsKey('android:navigationBarColor'), isFalse);
      expect(
        bars.items.containsKey('android:windowLightNavigationBar'),
        isFalse,
      );
    });

    test('CA-021-09: API 27+ (values-v27/): además, barra de navegación transparente con iconos oscuros', () {
      expect(File('$_res/values-v27/styles.xml').existsSync(), isTrue);
      final own = _styles('values-v27');
      // Solo redefine UnaBars, con el mismo padre.
      expect(own.keys, ['UnaBars']);
      final bars = own['UnaBars']!;
      expect(bars.parent, 'UnaWindow');
      expect(bars.items['android:statusBarColor']?.value, _transparent);
      expect(bars.items['android:windowLightStatusBar']?.value, 'true');
      expect(bars.items['android:navigationBarColor']?.value, _transparent);
      expect(bars.items['android:windowLightNavigationBar']?.value, 'true');
      for (final name in ['LaunchTheme', 'NormalTheme']) {
        expect(
          _effective(name, 'android:windowLightNavigationBar', stylesV27),
          'true',
        );
      }
    });
  });
}
