import 'dart:convert';
import 'dart:io';

import 'package:app/data/import/native_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/ports/image_importer.dart';

import '../fixtures/image_fixtures.g.dart';

/// Selector de pruebas: el canal nativo de verdad, salvo `pick`, que devuelve
/// el fichero de prueba [next].
class FixtureImporter implements ImageImporter {
  FixtureImporter(this.native, this.cache);

  final NativeImageImporter native;
  final Directory cache;
  String next = 'photo_gps.jpg';

  @override
  bool get heicSupported => native.heicSupported;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) async =>
      (token: next, origin: origin);

  @override
  Future<PickedImages?> pickMany({required int max}) =>
      native.pickMany(max: max);

  @override
  Future<int?> freeSpace() => native.freeSpace();

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) {
    final file = File('${cache.path}/fixtures/${picked.token}')
      ..createSync(recursive: true)
      ..writeAsBytesSync(base64.decode(imageFixtures[picked.token]!));
    return native.debugCopyFile(file.path, id, maxBytes: maxBytes);
  }

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) => native.sanitize(
    id,
    type,
    origin,
    maxPixels: maxPixels,
    storedMaxPixels: storedMaxPixels,
  );

  @override
  Future<void> cancel(String id) => native.cancel(id);

  @override
  Future<void> regenerateDerived(Attachment attachment) =>
      native.regenerateDerived(attachment);
}
