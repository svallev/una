import 'dart:convert';
import 'dart:io';

import 'package:app/app/theme/tokens.g.dart';
import 'package:app/l10n/generated/app_localizations_en.dart';
import 'package:app/l10n/generated/app_localizations_es.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String l) =>
    jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Claves **nuevas** sin plural de la tabla "Textos (ES / EN)" de la spec 016
/// (§7), copiadas tal cual, y las dos que **cambian** de texto.
const _spec016 = <String, (String, String)>{
  'attachPickImage': ('Subir imágenes', 'Upload images'),
  'attachPickImageHint': (
    'Una o varias · van arriba del todo',
    'One or more · go on top',
  ),
  'imagesLimitNotice': (
    'Solo se usarán las {max} primeras.',
    'Only the first {max} will be used.',
  ),
  'photoMissing': ('Foto no disponible', 'Photo unavailable'),
};

/// Claves con parámetros o plurales: ICU con `one` y `other`.
const _spec016Plural = <String, (String, String)>{
  'imagePreparingOf': (
    'Preparando foto {current} de {total}…',
    'Preparing photo {current} of {total}…',
  ),
  'photoCount': (
    '{count, plural, one{{count} foto} other{{count} fotos}}',
    '{count, plural, one{{count} photo} other{{count} photos}}',
  ),
  'a11yWithPhotos': (
    '{text}. {count, plural, one{{count} foto} other{{count} fotos}}',
    '{text}. {count, plural, one{{count} photo} other{{count} photos}}',
  ),
  'a11yPhotoStack': (
    'Vista previa: {count, plural, one{{count} foto} other{{count} fotos}}',
    'Preview: {count, plural, one{{count} photo} other{{count} photos}}',
  ),
  'a11yPhotoOf': ('Foto {index} de {total}', 'Photo {index} of {total}'),
  'a11yPhotoNext': ('Foto siguiente', 'Next photo'),
  'a11yPhotoPrevious': ('Foto anterior', 'Previous photo'),
  'a11yPhotosAdded': (
    '{count, plural, one{{count} foto añadida} other{{count} fotos añadidas}}',
    '{count, plural, one{{count} photo added} other{{count} photos added}}',
  ),
  'imagesSomeFailed': (
    '{count, plural, one{No se pudo añadir {count} foto.} '
        'other{No se pudieron añadir {count} fotos.}}',
    "{count, plural, one{{count} photo couldn't be added.} "
        "other{{count} photos couldn't be added.}}",
  ),
  'a11yPhotoMissing': (
    'Foto {index} de {total}. Foto no disponible',
    'Photo {index} of {total}. Photo unavailable',
  ),
};

/// Las 12 claves nuevas de la spec 016 (§7).
const _newKeys = [
  'imagePreparingOf',
  'photoCount',
  'a11yWithPhotos',
  'a11yPhotoStack',
  'a11yPhotoOf',
  'a11yPhotoNext',
  'a11yPhotoPrevious',
  'a11yPhotosAdded',
  'imagesLimitNotice',
  'imagesSomeFailed',
  'photoMissing',
  'a11yPhotoMissing',
];

void main() {
  final es = _arb('es'), en = _arb('en');
  final l10nEs = AppLocalizationsEs(), l10nEn = AppLocalizationsEn();

  test('CA-016-01, CA-016-02, CA-016-18a: los textos sin plural de la spec 016 '
      'están tal cual en las ARB ES y EN, con descripción que cita su CA', () {
    for (final MapEntry(key: k, value: (esText, enText)) in _spec016.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
    }
  });

  test('CA-016-04, CA-016-06, CA-016-20, CA-016-21: los textos con parámetros '
      'y plurales ICU están tal cual en las dos ARB', () {
    for (final MapEntry(key: k, value: (esText, enText))
        in _spec016Plural.entries) {
      expect(es[k], esText, reason: 'ES $k');
      expect(en[k], enText, reason: 'EN $k');
    }
  });

  test('CA-016-01: las 12 claves nuevas existen en las dos ARB, con '
      'descripción que cita un CA-016 (y el cambio de attachPickImage)', () {
    for (final k in [..._newKeys, 'attachPickImage', 'attachPickImageHint']) {
      for (final (name, arb) in [('ES', es), ('EN', en)]) {
        expect(arb.containsKey(k), isTrue, reason: '$name $k');
        final meta = arb['@$k'] as Map<String, dynamic>?;
        expect(meta, isNotNull, reason: '$name @$k');
        expect(meta!['description'], contains('CA-016-'), reason: '$name @$k');
      }
    }
    expect(
      _newKeys.toSet(),
      {..._spec016Plural.keys, ..._spec016.keys}
        ..removeAll(['attachPickImage', 'attachPickImageHint']),
      reason: 'las 12 de la tabla son las que se prueban aquí',
    );
  });

  test('CA-016-06, CA-016-20: los plurales usan `one` y `other` (no `=1`) y '
      'los parámetros están declarados', () {
    for (final k in [
      'photoCount',
      'a11yWithPhotos',
      'a11yPhotoStack',
      'a11yPhotosAdded',
      'imagesSomeFailed',
    ]) {
      for (final arb in [es, en]) {
        final text = arb[k] as String;
        expect(text, contains('one{'), reason: k);
        expect(text, contains('other{'), reason: k);
        expect(text, isNot(contains('=1')), reason: k);
      }
      final placeholders =
          (es['@$k'] as Map<String, dynamic>)['placeholders']
              as Map<String, dynamic>;
      expect(placeholders.containsKey('count'), isTrue, reason: k);
      expect(
        (placeholders['count'] as Map<String, dynamic>)['type'],
        'int',
        reason: k,
      );
    }
    final failed =
        (es['@imagesLimitNotice'] as Map<String, dynamic>)['placeholders']
            as Map<String, dynamic>;
    expect((failed['max'] as Map<String, dynamic>)['type'], 'int');
  });

  test('CA-016-06, CA-016-20, CA-016-21: las clases generadas dan el texto de '
      'cada idioma, en singular y en plural', () {
    expect(l10nEs.attachPickImage, 'Subir imágenes');
    expect(l10nEn.attachPickImage, 'Upload images');
    expect(l10nEs.attachPickImageHint, 'Una o varias · van arriba del todo');
    expect(l10nEn.attachPickImageHint, 'One or more · go on top');

    expect(l10nEs.imagePreparingOf(2, 5), 'Preparando foto 2 de 5…');
    expect(l10nEn.imagePreparingOf(2, 5), 'Preparing photo 2 of 5…');

    expect(l10nEs.photoCount(1), '1 foto');
    expect(l10nEs.photoCount(3), '3 fotos');
    expect(l10nEn.photoCount(1), '1 photo');
    expect(l10nEn.photoCount(3), '3 photos');

    expect(l10nEs.a11yWithPhotos('Llamar', 1), 'Llamar. 1 foto');
    expect(l10nEs.a11yWithPhotos('Llamar', 4), 'Llamar. 4 fotos');
    expect(l10nEn.a11yWithPhotos('Call', 1), 'Call. 1 photo');
    expect(l10nEn.a11yWithPhotos('Call', 4), 'Call. 4 photos');

    expect(l10nEs.a11yPhotoStack(3), 'Vista previa: 3 fotos');
    expect(l10nEn.a11yPhotoStack(3), 'Preview: 3 photos');

    expect(l10nEs.a11yPhotoOf(3, 5), 'Foto 3 de 5');
    expect(l10nEn.a11yPhotoOf(3, 5), 'Photo 3 of 5');
    expect(l10nEs.a11yPhotoNext, 'Foto siguiente');
    expect(l10nEn.a11yPhotoNext, 'Next photo');
    expect(l10nEs.a11yPhotoPrevious, 'Foto anterior');
    expect(l10nEn.a11yPhotoPrevious, 'Previous photo');

    expect(l10nEs.a11yPhotosAdded(1), '1 foto añadida');
    expect(l10nEs.a11yPhotosAdded(2), '2 fotos añadidas');
    expect(l10nEn.a11yPhotosAdded(1), '1 photo added');
    expect(l10nEn.a11yPhotosAdded(2), '2 photos added');

    expect(l10nEs.imagesLimitNotice(10), 'Solo se usarán las 10 primeras.');
    expect(l10nEn.imagesLimitNotice(10), 'Only the first 10 will be used.');

    expect(l10nEs.imagesSomeFailed(1), 'No se pudo añadir 1 foto.');
    expect(l10nEs.imagesSomeFailed(2), 'No se pudieron añadir 2 fotos.');
    expect(l10nEn.imagesSomeFailed(1), "1 photo couldn't be added.");
    expect(l10nEn.imagesSomeFailed(2), "2 photos couldn't be added.");

    expect(l10nEs.photoMissing, 'Foto no disponible');
    expect(l10nEn.photoMissing, 'Photo unavailable');
    expect(l10nEs.a11yPhotoMissing(3, 5), 'Foto 3 de 5. Foto no disponible');
    expect(l10nEn.a11yPhotoMissing(3, 5), 'Photo 3 of 5. Photo unavailable');
  });

  test('CA-016-06, spec 016 §7: "foto" e "imagen" no se mezclan en una frase '
      'de los textos nuevos (ES) ni "photo" e "image" (EN)', () {
    final esTexts = [
      l10nEs.imagePreparingOf(2, 5),
      l10nEs.photoCount(1),
      l10nEs.photoCount(3),
      l10nEs.a11yWithPhotos('Llamar', 3),
      l10nEs.a11yPhotoStack(3),
      l10nEs.a11yPhotoOf(3, 5),
      l10nEs.a11yPhotoNext,
      l10nEs.a11yPhotoPrevious,
      l10nEs.a11yPhotosAdded(1),
      l10nEs.a11yPhotosAdded(2),
      l10nEs.imagesLimitNotice(10),
      l10nEs.imagesSomeFailed(1),
      l10nEs.imagesSomeFailed(2),
      l10nEs.photoMissing,
      l10nEs.a11yPhotoMissing(3, 5),
    ];
    final enTexts = [
      l10nEn.imagePreparingOf(2, 5),
      l10nEn.photoCount(1),
      l10nEn.photoCount(3),
      l10nEn.a11yWithPhotos('Call', 3),
      l10nEn.a11yPhotoStack(3),
      l10nEn.a11yPhotoOf(3, 5),
      l10nEn.a11yPhotoNext,
      l10nEn.a11yPhotoPrevious,
      l10nEn.a11yPhotosAdded(1),
      l10nEn.a11yPhotosAdded(2),
      l10nEn.imagesLimitNotice(10),
      l10nEn.imagesSomeFailed(1),
      l10nEn.imagesSomeFailed(2),
      l10nEn.photoMissing,
      l10nEn.a11yPhotoMissing(3, 5),
    ];
    for (final t in esTexts) {
      expect(t.toLowerCase(), isNot(contains('imagen')), reason: t);
    }
    for (final t in enTexts) {
      expect(t.toLowerCase(), isNot(contains('image')), reason: t);
    }
  });

  test('CA-016-01: la hoja Añadir mantiene los textos de las demás filas', () {
    expect(l10nEs.attachPickFile, 'Subir archivo');
    expect(l10nEs.attachPickFileHint, 'PDF · va arriba del todo');
    expect(l10nEn.attachPickFile, 'Upload file');
  });

  test('CA-016-09, CA-016-22: los tokens del carrusel, los puntos y la pila '
      'salen de tokens.json (plan §2, DEV-53)', () {
    // Transición del carrusel: 280 ms con cubic-bezier(.2, .8, .2, 1).
    expect(UnaMotion.photoSwipe, const Duration(milliseconds: 280));
    expect(UnaMotion.photoSwipeCurve, const Cubic(0.2, 0.8, 0.2, 1));
    // Puntos: 9 de lado, borde 2, separación 6 y halo blanco de 1,5.
    expect(UnaSizes.photoDot, 9);
    expect(UnaSizes.photoDotGap, 6);
    expect(UnaBorders.photoDotWidth, 2);
    expect(UnaBorders.photoDotHaloWidth, 1.5);
    expect(UnaColors.photoDotInk, const Color(0xFF111111));
    expect(UnaColors.photoDotLight, const Color(0xFFFFFFFF));
    expect(UnaColors.photoDotHalo, const Color(0xFFFFFFFF));
    // Pila: giros -1°/4°/-5°, desplazamientos del prototipo, 86 %, borde 3.
    expect(UnaMotion.photoStackTiltTop, -1);
    expect(UnaMotion.photoStackTiltMiddle, 4);
    expect(UnaMotion.photoStackTiltBack, -5);
    expect(UnaSizes.photoStackMiddleDx, 12);
    expect(UnaSizes.photoStackMiddleDy, 6);
    expect(UnaSizes.photoStackBackDx, -10);
    expect(UnaSizes.photoStackBackDy, -8);
    expect(UnaMotion.photoStackWidthFactor, 0.86);
    expect(UnaBorders.photoStackWidth, 3);
    expect(UnaShadows.photoStack.offset, const Offset(5, 5));
    expect(UnaShadows.photoStack.blurRadius, 0);
    expect(UnaShadows.photoStack.color, UnaColors.ink);
    // Etiqueta "{n} fotos": blanco sobre tinta, 12 px monoespaciada.
    expect(UnaFontSizes.photoCount, 12);
    expect(UnaColors.photoCountText, UnaColors.onInk);
    expect(UnaColors.photoCountFill, UnaColors.ink);
  });
}
