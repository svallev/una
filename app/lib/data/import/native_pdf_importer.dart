import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

import '../../domain/entities/attachment.dart';
import '../../domain/entities/pdf_position.dart';
import '../../domain/ports/image_importer.dart'
    show CopiedImage, ImageImportCancelled;
import '../../domain/ports/pdf_importer.dart';
import 'pdf_engine.dart';

/// Importador de PDF (spec 008): el selector, la copia acotada y el JPEG por el
/// canal nativo `una/images` (`ImageImport.kt`); abrir, contar páginas y dibujar,
/// con PDFium ([PdfEngine]). No registra nada (CL-008-11).
class NativePdfImporter implements PdfImporter {
  NativePdfImporter({
    required this.stagingFile,
    required this.storedFile,
    int Function()? screenWidthPx,
  }) : screenWidthPx = screenWidthPx ?? _physicalScreenWidth;

  static const _channel = MethodChannel('una/images');

  /// Archivo `name` de la preparación `id` (`FileAttachmentStore.stagingFile`).
  final File Function(String id, String name) stagingFile;

  /// Archivo de un adjunto guardado (`FileAttachmentStore.file`).
  final File Function(String relPath) storedFile;

  /// Ancho físico de la pantalla en vertical: la versión de pantalla se dibuja
  /// a ese ancho, nunca más (I-2).
  final int Function() screenWidthPx;

  static int _physicalScreenWidth() {
    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return 1080;
    final size = views.first.physicalSize;
    final short = size.shortestSide.round();
    return short > 0 ? short : 1080;
  }

  @override
  Future<PickedPdf?> pick(String id) => _guard(() async {
    final r = await _channel.invokeMapMethod<String, Object?>('pick', {
      'origin': 'file',
      'id': id,
    });
    return r == null
        ? null
        : (token: r['token']! as String, name: r['name'] as String?);
  });

  @override
  Future<CopiedImage> copy(
    PickedPdf picked,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) => _guard(() async {
    final r = (await _channel.invokeMapMethod<String, Object?>('copy', {
      'token': picked.token,
      'id': id,
      'maxBytes': maxBytes,
      'headBytes': headBytes,
    }))!;
    return _copied(r);
  });

  /// Solo en builds de depuración: importa un archivo de `cache/fixtures/`
  /// para los tests de integración (como `NativeImageImporter`).
  Future<CopiedImage> debugCopyFile(
    String path,
    String id, {
    required int maxBytes,
    required int headBytes,
  }) => _guard(() async {
    final r = (await _channel.invokeMapMethod<String, Object?>(
      'debugCopyFile',
      {'path': path, 'id': id, 'maxBytes': maxBytes, 'headBytes': headBytes},
    ))!;
    return _copied(r);
  });

  static CopiedImage _copied(Map<String, Object?> r) => (
    byteSize: (r['byteSize']! as num).toInt(),
    head: (r['head']! as Uint8List).toList(),
  );

  @override
  Future<PdfInfo> inspect(String id, {required int maxPages}) async {
    final source = stagingFile(id, 'source');
    final (info, page) = await PdfEngine.inspect(
      PdfEngine.file(source.path),
      maxPages: maxPages,
      renderWidth: screenWidthPx(),
    );
    await source.rename(stagingFile(id, 'document.pdf').path);
    await _encode(id, 'staging', page);
    return info;
  }

  @override
  Future<void> renderScreen(Attachment attachment, PdfPosition position) async {
    final file = storedFile(attachment.documentPath);
    if (!file.existsSync()) return;
    final count = attachment.pageCount ?? 1;
    final page = await PdfEngine.renderPage(
      PdfEngine.file(file.path),
      position.clampTo(count).page,
      width: screenWidthPx(),
    );
    await _encode(attachment.id, 'stored', page);
  }

  Future<void> _encode(String id, String target, RenderedPage page) => _guard(
    () => _channel.invokeMethod<void>('encodeJpeg', {
      'id': id,
      'target': target,
      'width': page.width,
      'height': page.height,
      'bgra': true,
      'pixels': page.bgra,
    }),
  );

  @override
  Future<void> cancel(String id) =>
      _channel.invokeMethod<void>('cancel', {'id': id});

  /// Traduce los códigos del canal a [PdfImportFailure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on MissingPluginException {
      throw const PdfImportFailure(PdfImportError.unreadable);
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'tooLarge' => const PdfImportFailure(PdfImportError.tooLarge),
        'noSpace' => const PdfImportFailure(PdfImportError.noSpace),
        'cancelled' => const ImageImportCancelled(),
        _ => const PdfImportFailure(PdfImportError.unreadable),
      };
    }
  }
}
