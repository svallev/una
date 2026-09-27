import 'package:flutter/services.dart';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/image_type.dart';
import '../../domain/ports/image_importer.dart';

/// Importador de imágenes sobre el canal nativo `una/images` (Android,
/// `ImageImport.kt`). No registra nada (CL-007-10).
class NativeImageImporter implements ImageImporter {
  NativeImageImporter({required this.heicSupported});

  static const _channel = MethodChannel('una/images');

  /// Sin canal (iOS aún no lo tiene, D17), HEIC no se admite y cada llamada
  /// falla como `unreadable`: el arranque no depende de ello.
  static Future<NativeImageImporter> open() async {
    try {
      final caps = await _channel.invokeMapMethod<String, Object?>(
        'capabilities',
      );
      return NativeImageImporter(heicSupported: caps?['heic'] == true);
    } on MissingPluginException {
      return NativeImageImporter(heicSupported: false);
    }
  }

  @override
  final bool heicSupported;

  @override
  Future<PickedImage?> pick(AttachmentOrigin origin, String id) => _guard(
    () async {
      final r = await _channel.invokeMapMethod<String, Object?>('pick', {
        'origin': origin.name,
        'id': id,
      });
      return r == null ? null : (token: r['token']! as String, origin: origin);
    },
  );

  @override
  Future<CopiedImage> copy(
    PickedImage picked,
    String id, {
    required int maxBytes,
  }) => _guard(() async {
    final r = (await _channel.invokeMapMethod<String, Object?>('copy', {
      'token': picked.token,
      'id': id,
      'maxBytes': maxBytes,
    }))!;
    return _copied(r);
  });

  /// Solo en builds de depuración: importa un archivo de `cache/fixtures/` (o
  /// un flujo sin fin, `/dev/zero`) para los tests de integración.
  Future<CopiedImage> debugCopyFile(
    String path,
    String id, {
    required int maxBytes,
  }) => _guard(() async {
    final r = (await _channel.invokeMapMethod<String, Object?>(
      'debugCopyFile',
      {'path': path, 'id': id, 'maxBytes': maxBytes},
    ))!;
    return _copied(r);
  });

  static CopiedImage _copied(Map<String, Object?> r) => (
    byteSize: (r['byteSize']! as num).toInt(),
    head: (r['head']! as Uint8List).toList(),
  );

  @override
  Future<StagedImage> sanitize(
    String id,
    ImageType type,
    AttachmentOrigin origin, {
    required int maxPixels,
    required int storedMaxPixels,
  }) => _guard(() async {
    final r = (await _channel.invokeMapMethod<String, Object?>('sanitize', {
      'id': id,
      'type': type.name,
      'maxPixels': maxPixels,
      'storedMaxPixels': storedMaxPixels,
    }))!;
    return (
      id: id,
      origin: origin,
      width: (r['width']! as num).toInt(),
      height: (r['height']! as num).toInt(),
      byteSize: (r['byteSize']! as num).toInt(),
    );
  });

  @override
  Future<void> regenerateDerived(Attachment attachment) => _guard(
    () => _channel.invokeMethod<void>('regenerate', {
      'id': attachment.id,
      'width': attachment.width,
      'height': attachment.height,
    }),
  );

  @override
  Future<void> cancel(String id) =>
      _channel.invokeMethod<void>('cancel', {'id': id});

  /// Traduce los códigos del canal a [ImageImportFailure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const ImageImportFailure(ImageImportError.unreadable);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'tooLarge' => const ImageImportFailure(ImageImportError.tooLarge),
        'tooManyPixels' => const ImageImportFailure(
          ImageImportError.tooManyPixels,
        ),
        'noCamera' => const ImageImportFailure(ImageImportError.noCamera),
        'noSpace' => const ImageImportFailure(ImageImportError.noSpace),
        'cancelled' => const ImageImportCancelled(),
        _ => const ImageImportFailure(ImageImportError.unreadable),
      };
    }
  }
}
