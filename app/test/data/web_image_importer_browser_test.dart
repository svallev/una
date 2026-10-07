@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/import/web_image_importer.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/ports/image_importer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sustituye `click()` de los `<input type=file>` por una elección simulada
/// de [count] archivos y cuenta cuántos se piden con `item()`. Se prueba con
/// `flutter test --platform chrome test/data/web_image_importer_browser_test.dart`
/// (no entra en `flutter test` de la VM).
@JS('eval')
external JSAny? _eval(String code);

void _install(int count) {
  _eval('''
    (function() {
      window.__itemCalls = 0;
      window.__multiple = null;
      HTMLInputElement.prototype.click = function() {
        const input = this;
        window.__multiple = input.multiple;
        const files = [];
        for (let i = 0; i < $count; i++) {
          files.push(new File([new Uint8Array([i % 256])], 'f' + i + '.jpg',
              {type: 'image/jpeg'}));
        }
        const fake = {
          length: files.length,
          item: function(i) { window.__itemCalls++; return files[i]; },
        };
        Object.defineProperty(input, 'files', {get: function() { return fake; }});
        setTimeout(function() { input.dispatchEvent(new Event('change')); }, 0);
      };
    })();
  ''');
}

int _itemCalls() => (_eval('window.__itemCalls')! as JSNumber).toDartInt;

bool _multiple() => (_eval('window.__multiple')! as JSBoolean).toDart;

void main() {
  test('CA-016-02: con 5000 archivos elegidos solo se leen 10 y el total '
      'se conserva', () async {
    _install(5000);
    final importer = WebImageImporter(MemoryAttachmentStore());
    final r = await importer.pickMany(max: 10);
    expect(r, isNotNull);
    expect(r!.items, hasLength(10));
    expect(r.total, 5000);
    expect(_itemCalls(), 10);
    expect(_multiple(), isTrue);
    expect(r.items.map((e) => e.token).toSet(), hasLength(10));
    expect(r.items.every((e) => e.origin == AttachmentOrigin.gallery), isTrue);
  });

  test(
    'CA-007-02: elegir una sola foto no activa `multiple` y lee una',
    () async {
      _install(3);
      final importer = WebImageImporter(MemoryAttachmentStore());
      final r = await importer.pick(AttachmentOrigin.gallery, 'x');
      expect(r, isNotNull);
      expect(_itemCalls(), 1);
      expect(_multiple(), isFalse);
    },
  );

  test('CA-016-15: una foto de un grupo pasa por la misma comprobación de '
      'tamaño (30 MB) y se suelta al leerla', () async {
    _install(2);
    final importer = WebImageImporter(MemoryAttachmentStore());
    final r = await importer.pickMany(max: 10);
    final a = r!.items[0];
    final b = r.items[1];
    final copied = await importer.copy(a, 'a', maxBytes: 100);
    expect(copied.byteSize, 1);
    // Ya liberada: una segunda copia del mismo token no la encuentra.
    await expectLater(
      importer.copy(a, 'a2', maxBytes: 100),
      throwsA(isA<ImageImportFailure>()),
    );
    await expectLater(
      importer.copy(b, 'b', maxBytes: 0),
      throwsA(
        isA<ImageImportFailure>().having(
          (e) => e.error,
          'error',
          ImageImportError.tooLarge,
        ),
      ),
    );
  });
}
