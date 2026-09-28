import 'dart:io';

import 'package:app/data/web/psl_asset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuenta las lecturas del asset para comprobar que se carga una sola vez.
class _CountingBundle extends CachingAssetBundle {
  int reads = 0;

  @override
  Future<ByteData> load(String key) {
    reads++;
    return rootBundle.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    reads++;
    return rootBundle.loadString(key, cache: cache);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'CA-009-11: la PSL empaquetada se carga del asset una sola vez',
    () async {
      final bundle = _CountingBundle();
      final loader = PublicSuffixListLoader(bundle);
      final first = await loader.load();
      final second = await loader.load();
      expect(identical(first, second), isTrue);
      expect(bundle.reads, 1);
      expect(first.registrableDomain('www.ejemplo.co.uk'), 'ejemplo.co.uk');
    },
  );

  test(
    'CA-009-11: el aviso de licencia es la cabecera MPL-2.0 de la lista',
    () {
      final header = File(pslAssetPath)
          .readAsLinesSync()
          .takeWhile((l) => l.startsWith('//'))
          .map((l) => l.substring(3))
          .join('\n');
      expect(header, pslLicenseNotice);
    },
  );
}
