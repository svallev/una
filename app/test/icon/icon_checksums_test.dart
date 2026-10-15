import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_package.dart' show sha256Hex;

/// CA-021-11 (spec 021): el cambio del arranque no toca ningún icono. Las sumas son las de
/// `main` antes de la 021 (iconos de la 018 y de la 019); si un icono cambia a propósito, se
/// actualizan aquí con su spec. `tool/gen_icons.dart --check` vigila el resto.
const _res = 'android/app/src/main/res';

const _sums = <String, String>{
  '$_res/drawable-nodpi/ic_launcher_foreground.png':
      'aee52fe9c3fd9a68c8fac0cef73d8f88c2be6110d0b8419937bdd7eddc2231c0',
  '$_res/values/ic_launcher_background.xml':
      'c2d97d95b458e94b6276c950a8cb80472c697846853d91acbfd8c82842bbe43c',
  '$_res/mipmap-anydpi/ic_launcher.xml':
      '8ee58af3ff099dab344edfc4cd5f15927124d3748b32469b147a1723b5b42316',
  '$_res/drawable-mdpi/ic_stat_una.png':
      '50446a67e7cbdbf3525a391708f4a55cf20f7d18b6e57e918a4aeef976f4a434',
  '$_res/drawable-hdpi/ic_stat_una.png':
      'b663017b9087c4ff81184db7f79c129ca61d46bce4dfd0c7c9e333b93da4bb2a',
  '$_res/drawable-xhdpi/ic_stat_una.png':
      'cb99459ca20e3ea091af06c888b581b43c915063b6dbfc460bdfceb669abf4cd',
  '$_res/drawable-xxhdpi/ic_stat_una.png':
      'be4f3e3f49697be2c561b29567cf9c368e51683deecfa00b57b237ea5f4c7318',
  '$_res/drawable-xxxhdpi/ic_stat_una.png':
      '4b78cdde5b02ad2eb98b457857504652062eced5644f187accc31051a7ee8683',
  '../store/google-play/icon-512.png':
      'ac95ab8441543d0c1f39cdc5197ddb97a42d2e034c866c93be4bc7eb417979b5',
};

void main() {
  test('CA-021-11: los iconos (lanzador, Play, monocromo y notificación) son idénticos byte a byte', () {
    expect(_sums, hasLength(9));
    for (final e in _sums.entries) {
      final file = File(e.key);
      expect(file.existsSync(), isTrue, reason: e.key);
      expect(sha256Hex(file.readAsBytesSync()), e.value, reason: e.key);
    }
  });

  test('CA-021-11: el arranque no añade imágenes propias a res/ (solo el primer plano de la 018)', () {
    final images =
        Directory(_res)
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .where(
              (p) =>
                  p.endsWith('.png') ||
                  p.endsWith('.webp') ||
                  p.endsWith('.jpg'),
            )
            .toList()
          ..sort();
    expect(images, [
      '$_res/drawable-hdpi/ic_stat_una.png',
      '$_res/drawable-mdpi/ic_stat_una.png',
      '$_res/drawable-nodpi/ic_launcher_foreground.png',
      '$_res/drawable-xhdpi/ic_stat_una.png',
      '$_res/drawable-xxhdpi/ic_stat_una.png',
      '$_res/drawable-xxxhdpi/ic_stat_una.png',
    ]);
  });
}
