import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/attachments/task_labels.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 9, 28);

Task _task(String? url, {String? text}) => Task(
  id: 't1',
  text: text,
  status: TaskStatus.pending,
  rank: 'a',
  colorKey: 0,
  createdAt: _at,
  updatedAt: _at,
  attachment: attachmentFrom(StagedWeb(id: 'w1', url: url ?? ''), _at),
);

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));

  test(
    'CA-009-04: la tarea web es un adjunto sin archivos: solo la dirección',
    () {
      final a = attachmentFrom(
        const StagedWeb(id: 'w1', url: 'https://example.com/programa'),
        _at,
      );
      expect(a.kind, AttachmentKind.web);
      expect(a.isWeb, isTrue);
      expect(a.isPdf, isFalse);
      expect(a.origin, AttachmentOrigin.url);
      expect(a.url, 'https://example.com/programa');
      expect(a.mime, 'text/html');
      expect(a.byteSize, 0);
      expect(a.thumbPath, isNull);
      expect(a.originalName, isNull);
      expect(a.pageCount, isNull);
      // La dirección no va a ningún registro (CL-009-9).
      expect(a.toString(), isNot(contains('example')));
      expect(
        const StagedWeb(id: 'w1', url: 'https://example.com/').toString(),
        isNot(contains('example')),
      );
    },
  );

  test('CA-009-17: insignia "WEB" en el listado', () {
    expect(attachmentKindLabel(es, _task('https://example.com')), 'WEB');
    expect(attachmentKindLabel(en, _task('https://example.com')), 'WEB');
  });

  test('CA-009-17: la etiqueta es el dominio, sin www. (CA-009-14)', () {
    expect(
      taskLabel(es, _task('https://www.congreso.example.com/p')),
      'congreso.example.com',
    );
    expect(taskLabel(es, _task('https://xn--e1afmkfd.xn--p1ai/')), 'пример.рф');
    expect(
      taskLabel(es, _task('https://xn--pple-43d.com/')),
      'xn--pple-43d.com',
    );
    // Una dirección que no se puede leer: "WEB".
    expect(taskLabel(es, _task('')), 'WEB');
  });

  test('CA-009-18: lectura de la fila "{host}. Página web"', () {
    expect(
      taskReading(es, _task('https://www.example.com/')),
      'example.com. Página web',
    );
    expect(
      taskReading(en, _task('https://www.example.com/')),
      'example.com. Web page',
    );
  });
}
