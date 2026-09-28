import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/services/public_suffix.dart';

/// Ruta del asset de la *Public Suffix List* (fijada en `tools/psl.lock`).
const pslAssetPath = 'assets/psl/public_suffix_list.dat';

/// Aviso de licencia de la lista (su cabecera, tal cual): va en la pantalla de
/// licencias (`bundled_licenses.dart`).
const pslLicenseNotice =
    'This Source Code Form is subject to the terms of the Mozilla Public\n'
    'License, v. 2.0. If a copy of the MPL was not distributed with this\n'
    'file, You can obtain one at https://mozilla.org/MPL/2.0/.';

/// Carga la PSL del asset la primera vez que se pide (al mostrar una tarea web,
/// nunca en el arranque: P2) y la reutiliza. Se interpreta fuera del hilo de la
/// interfaz (~335 KB de texto).
class PublicSuffixListLoader {
  PublicSuffixListLoader([AssetBundle? bundle])
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<PublicSuffixList>? _list;

  Future<PublicSuffixList> load() => _list ??= _read().catchError((Object e) {
    _list = null; // Si falla, el siguiente intento vuelve a leerla.
    throw e;
  });

  Future<PublicSuffixList> _read() async =>
      compute(PublicSuffixList.parse, await _bundle.loadString(pslAssetPath));
}
