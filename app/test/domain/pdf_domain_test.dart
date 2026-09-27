import 'dart:convert';

import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/pdf_position.dart';
import 'package:app/domain/services/file_name.dart';
import 'package:app/domain/services/pdf_sniffer.dart';
import 'package:flutter_test/flutter_test.dart';

Attachment _pdf({String? name = 'Programa.pdf'}) => Attachment(
  id: 'a1',
  kind: AttachmentKind.pdf,
  origin: AttachmentOrigin.file,
  mime: 'application/pdf',
  byteSize: 2400000,
  width: 595,
  height: 842,
  createdAt: DateTime.utc(2026, 9, 27),
  originalName: name,
  pageCount: 3,
);

void main() {
  group('CA-008-02: solo PDF, por el contenido', () {
    test('acepta la cabecera %PDF- al principio', () {
      expect(isPdf(latin1.encode('%PDF-1.7\n%âãÏÓ')), isTrue);
    });

    test('acepta la cabecera en los primeros 1024 bytes (tras basura)', () {
      expect(
        isPdf([...List.filled(100, 0), ...ascii.encode('%PDF-1.4\n')]),
        isTrue,
      );
      expect(
        isPdf([...List.filled(1019, 0x20), ...ascii.encode('%PDF-')]),
        isTrue,
      );
    });

    test('rechaza la cabecera después de 1024 bytes', () {
      expect(
        isPdf([...List.filled(1020, 0x20), ...ascii.encode('%PDF-')]),
        isFalse,
      );
    });

    test(
      'rechaza HTML, ZIP, imágenes, texto y vacío aunque se llamen .pdf',
      () {
        expect(isPdf(ascii.encode('<!DOCTYPE html><html>')), isFalse);
        expect(isPdf([0x50, 0x4B, 0x03, 0x04, 0, 0]), isFalse);
        expect(isPdf([0xFF, 0xD8, 0xFF, 0xE0]), isFalse);
        expect(isPdf(ascii.encode('PDF-1.7 sin porcentaje')), isFalse);
        expect(isPdf(const []), isFalse);
      },
    );

    test('los límites son 10 MB (10 × 10⁶ bytes) y 20 páginas (CA-008-03)', () {
      expect(PdfLimits.maxBytes, 10 * 1000 * 1000);
      expect(PdfLimits.maxBytesInMb, 10);
      expect(PdfLimits.maxPages, 20);
      expect(PdfLimits.timeout, const Duration(seconds: 20));
      expect(PdfLimits.headBytes, 1024);
    });
  });

  group('CA-008-07: nombre del archivo saneado', () {
    test('quita las rutas (con / y con \\)', () {
      expect(
        sanitizeFileName('/storage/emulated/0/Download/Programa.pdf'),
        'Programa.pdf',
      );
      expect(sanitizeFileName(r'C:\Users\x\Entradas.pdf'), 'Entradas.pdf');
      expect(sanitizeFileName('../../etc/passwd.pdf'), 'passwd.pdf');
    });

    test('quita los caracteres de control y de cambio de dirección', () {
      expect(sanitizeFileName('Pro\u0000gra\nma\t.pdf'), 'Programa.pdf');
      expect(sanitizeFileName('factura\u202Efdp.exe'), 'facturafdp.exe');
      expect(
        sanitizeFileName(
          'a\u200Eb\u200Fc\u061Cd\u2066e\u2067f\u2068g\u2069h\u202Ai\u202Bj\u202Ck\u202Dl.pdf',
        ),
        'abcdefghijkl.pdf',
      );
    });

    test('recorta a 120 caracteres visibles conservando la extensión', () {
      final long = '${'a' * 200}.pdf';
      final out = sanitizeFileName(long)!;
      expect(out.length, 120);
      expect(out.endsWith('.pdf'), isTrue);
    });

    test('cuenta caracteres visibles, no bytes: no parte un emoji ni un acento combinado', () {
      final name = '${'👩‍👩‍👧' * 130}.pdf';
      final out = sanitizeFileName(name)!;
      expect(out.endsWith('.pdf'), isTrue);
      expect(out.replaceAll('.pdf', '').replaceAll('👩‍👩‍👧', ''), isEmpty);
      final accents = '${'e\u0301' * 130}.pdf';
      final out2 = sanitizeFileName(accents)!;
      expect(out2.replaceAll('.pdf', '').replaceAll('e\u0301', ''), isEmpty);
    });

    test('recorta espacios alrededor', () {
      expect(sanitizeFileName('   Programa.pdf  '), 'Programa.pdf');
    });

    test('vacío, solo controles o solo ruta → null (se usará "PDF")', () {
      expect(sanitizeFileName(null), isNull);
      expect(sanitizeFileName(''), isNull);
      expect(sanitizeFileName('\u0000\u202E\n'), isNull);
      expect(sanitizeFileName('/storage/emulated/0/'), isNull);
      expect(sanitizeFileName('   '), isNull);
    });

    test('una extensión absurdamente larga no se conserva entera', () {
      final out = sanitizeFileName('a.${'x' * 300}')!;
      expect(out.length, 120);
    });
  });

  group('CA-008-09: última posición (página + fracción)', () {
    test('se serializa y se lee', () {
      const p = PdfPosition(page: 4, offset: 0.25);
      expect(PdfPosition.fromJson(p.toJson()), p);
    });

    test('valores fuera de rango se acotan; basura → null (empieza por la primera)', () {
      expect(
        PdfPosition.fromJson('{"page": 0, "offset": -1}'),
        const PdfPosition(page: 1, offset: 0),
      );
      expect(
        PdfPosition.fromJson('{"page": 3, "offset": 7}'),
        const PdfPosition(page: 3, offset: 1),
      );
      expect(PdfPosition.fromJson('no es json'), isNull);
      expect(PdfPosition.fromJson('{"page": "x"}'), isNull);
      expect(PdfPosition.fromJson(''), isNull);
    });

    test('la página se acota al número de páginas', () {
      expect(
        const PdfPosition(page: 30, offset: 0.5).clampTo(20),
        const PdfPosition(page: 20, offset: 0.5),
      );
      expect(PdfPosition.start, const PdfPosition(page: 1, offset: 0));
    });
  });

  group('Adjunto PDF (plan §1)', () {
    test('rutas propias: el documento, la versión de pantalla y la posición; sin miniatura', () {
      final a = _pdf();
      expect(a.isPdf, isTrue);
      expect(a.isPhoto, isFalse);
      expect(a.documentPath, 'attachments/a1/document.pdf');
      expect(a.screenPath, 'attachments/a1/screen.jpg');
      expect(a.positionPath, 'attachments/a1/position.json');
      expect(a.thumbPath, isNull);
      expect(a.mainPath, a.documentPath);
    });

    test('la imagen sigue como en la 007', () {
      final a = Attachment(
        id: 'i1',
        kind: AttachmentKind.image,
        origin: AttachmentOrigin.gallery,
        mime: 'image/jpeg',
        byteSize: 1,
        width: 10,
        height: 10,
        createdAt: DateTime.utc(2026),
      );
      expect(a.isPdf, isFalse);
      expect(a.thumbPath, 'attachments/i1/thumb.jpg');
      expect(a.mainPath, a.fullPrefix);
      expect(a.originalName, isNull);
      expect(a.pageCount, isNull);
    });

    test('igualdad con nombre y páginas', () {
      expect(_pdf(), _pdf());
      expect(_pdf() == _pdf(name: 'Otro.pdf'), isFalse);
    });
  });
}
