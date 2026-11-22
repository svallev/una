import 'dart:io';
import 'dart:ui' show Locale;

import 'package:app/app/providers.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/locale_choice.dart';
import 'package:app/domain/entities/notification_settings.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/services/notification_content.dart';
import 'package:app/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump_app.dart' show sampleTask;

/// Spec 028, T-028-18: el texto de las notificaciones de iOS, calculado en
/// Dart (CA-028-16, ADR-0030). Son los casos de `TaskLabelTest.kt`,
/// `NotificationTextTest.kt` y `SlotsTest.kt` (en lo que aplica) portados:
/// `labels.txt` es el mismo archivo que lee JUnit.

const _fixtures = 'test/fixtures/notifications';

String _unescape(String s) =>
    s.replaceAllMapped(RegExp(r'\\(u[0-9a-fA-F]{4}|\\|t|n|r)'), (m) {
      final e = m[1]!;
      return switch (e[0]) {
        'u' => String.fromCharCode(int.parse(e.substring(1), radix: 16)),
        't' => '\t',
        'n' => '\n',
        'r' => '\r',
        _ => '\\',
      };
    });

String? _nullable(String raw) => raw == '<null>' ? null : _unescape(raw);

List<(int, List<String>)> _cases(String name, int columns) {
  final lines = File('$_fixtures/$name').readAsLinesSync();
  final out = <(int, List<String>)>[];
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].isEmpty || lines[i].startsWith('#')) continue;
    final c = lines[i].split('\t');
    if (c.length != columns) {
      throw StateError('$name:${i + 1} no tiene $columns columnas');
    }
    out.add((i + 1, c));
  }
  return out;
}

List<NotificationAttachmentRow> _rows(String raw) => raw == '-'
    ? const []
    : [
        for (final r in raw.split(' | '))
          () {
            final parts = r.split(',');
            return NotificationAttachmentRow(
              _nullable(parts[0]),
              _nullable(parts[1]),
              _nullable(parts.skip(2).join(',')),
            );
          }(),
      ];

NotificationLabel? _expected(String spec) => switch (spec) {
  'none' => null,
  'photo' => const NotificationPhotoLabel(),
  'image' => const NotificationImageLabel(),
  'pdf' => const NotificationPdfLabel(),
  _ when spec.startsWith('text:') => NotificationTextLabel(
    _unescape(spec.substring(5)),
  ),
  _ when spec.startsWith('domain:') => NotificationDomainLabel(
    _unescape(spec.substring(7)),
  ),
  _ => throw StateError('esperado desconocido: $spec'),
};

NotificationLabel? _label(String? body, [List<NotificationAttachmentRow>? r]) =>
    NotificationLabel.of(body, r ?? const []);

String _text(NotificationLabel? l) => (l! as NotificationTextLabel).value;

String _chars(List<int> codes) => String.fromCharCodes(codes);

final _grin = _chars([0x1F600]);
final _family = _chars([0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467]);
final _eAcute = _chars([0x65, 0x301]);
final _flag = _chars([0x1F1EA, 0x1F1F8]);
const _ellipsis = NotificationLabel.ellipsis;

NotificationTexts _texts(String lang) {
  final l10n = lookupAppLocalizations(Locale(lang));
  return NotificationTexts(
    title: l10n.notificationTitle,
    publicBody: l10n.notificationPublic,
    photo: l10n.attachmentPhoto,
    image: l10n.attachmentImage,
    pdf: l10n.attachmentPdf,
  );
}

Attachment _attachment(
  AttachmentKind kind,
  AttachmentOrigin origin, {
  String? url,
  bool unreadable = false,
}) => Attachment(
  id: 'a-${kind.name}-${origin.name}',
  kind: kind,
  origin: origin,
  mime: 'image/jpeg',
  byteSize: 1,
  width: 1,
  height: 1,
  createdAt: DateTime.utc(2026, 11, 22),
  url: url,
  unreadable: unreadable,
);

Task _task(String? text, [List<Attachment> attachments = const []]) {
  final base = sampleTask();
  return Task(
    id: base.id,
    text: text,
    status: base.status,
    rank: base.rank,
    colorKey: base.colorKey,
    createdAt: base.createdAt,
    updatedAt: base.updatedAt,
    attachments: attachments,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CA-028-16 / CA-019-16: la etiqueta (labels.txt, el de JUnit)', () {
    final cases = _cases('labels.txt', 4);

    test('el archivo tiene los casos de TaskLabelTest.kt', () {
      expect(cases.length, greaterThan(40));
    });

    for (final (line, c) in cases) {
      test('labels.txt:$line ${c[0]}', () {
        expect(
          NotificationLabel.of(_nullable(c[1]), _rows(c[2])),
          _expected(c[3]),
        );
      });
    }
  });

  group('CA-028-16 / CL-019-13: el recorte, 120 letras completas y «…»', () {
    test('120 letras exactas no llevan puntos suspensivos', () {
      final body = 'a' * 120;
      expect(_label(body), NotificationTextLabel(body));
    });

    test('121 letras se recortan a 120 más puntos suspensivos', () {
      expect(
        _label('${'a' * 120}b'),
        NotificationTextLabel('${'a' * 120}$_ellipsis'),
      );
    });

    test('un texto de 10 000 caracteres sale en 120 letras', () {
      final body = 'Palabra ' * 1250;
      expect(body.length, 10000);
      final value = _text(_label(body));
      expect(value.length, 121);
      expect(value.endsWith(_ellipsis), isTrue);
      expect(value.substring(0, 120), body.trim().substring(0, 120));
    });

    test('un texto de 10 000 caracteres con saltos de línea sale sin '
        'saltos', () {
      final value = _text(_label('linea\n' * 1700));
      expect(value.contains('\n'), isFalse);
      expect(value.length, 121);
    });

    test('cuenta letras completas, no unidades UTF-16', () {
      expect(_label(_grin * 120), NotificationTextLabel(_grin * 120));
      expect(
        _label(_grin * 121),
        NotificationTextLabel('${_grin * 120}$_ellipsis'),
      );
    });

    test('no parte un emoji con ZWJ en la frontera del recorte', () {
      expect(
        _text(_label('${'a' * 119}${_family}b')),
        '${'a' * 119}$_family$_ellipsis',
      );
      // Desplazado una letra: la familia ya no cabe y se descarta entera.
      expect(
        _label('${'a' * 120}$_family'),
        NotificationTextLabel('${'a' * 120}$_ellipsis'),
      );
    });

    test('no separa una letra de su acento ni una bandera', () {
      expect(
        _label('${'a' * 119}$_eAcute$_flag'),
        NotificationTextLabel('${'a' * 119}$_eAcute$_ellipsis'),
      );
      expect(
        _label('${'a' * 119}${_flag}z'),
        NotificationTextLabel('${'a' * 119}$_flag$_ellipsis'),
      );
    });

    test('la escritura de derecha a izquierda se deja tal cual', () {
      final arabic = _chars([0x645, 0x631, 0x62D, 0x628, 0x627]);
      expect(_label(arabic), NotificationTextLabel(arabic));
    });

    test('U+FEFF no es un espacio (como `isWhitespace` de Kotlin)', () {
      final bom = _chars([0xFEFF]);
      expect(_label(bom), NotificationTextLabel(bom));
    });
  });

  group('CA-028-16 / CA-019-16: la etiqueta de una tarea de la BD', () {
    test('sin tarea, sin texto ni adjuntos: sin etiqueta', () {
      expect(NotificationLabel.ofTask(null), isNull);
      expect(NotificationLabel.ofTask(_task(null)), isNull);
    });

    test('foto, imagen, PDF y web, con los tipos de la entidad', () {
      expect(
        NotificationLabel.ofTask(
          _task(null, [
            _attachment(AttachmentKind.image, AttachmentOrigin.camera),
          ]),
        ),
        const NotificationPhotoLabel(),
      );
      expect(
        NotificationLabel.ofTask(
          _task(null, [
            _attachment(AttachmentKind.image, AttachmentOrigin.gallery),
          ]),
        ),
        const NotificationImageLabel(),
      );
      expect(
        NotificationLabel.ofTask(
          _task(null, [_attachment(AttachmentKind.pdf, AttachmentOrigin.file)]),
        ),
        const NotificationPdfLabel(),
      );
      expect(
        NotificationLabel.ofTask(
          _task(null, [
            _attachment(
              AttachmentKind.web,
              AttachmentOrigin.url,
              url: 'https://www.example.com/a',
            ),
          ]),
        ),
        const NotificationDomainLabel('example.com'),
      );
    });

    test('un grupo de fotos o un adjunto ilegible: sin etiqueta', () {
      final photo = _attachment(AttachmentKind.image, AttachmentOrigin.camera);
      expect(NotificationLabel.ofTask(_task(null, [photo, photo])), isNull);
      expect(
        NotificationLabel.ofTask(
          _task(null, [
            _attachment(
              AttachmentKind.image,
              AttachmentOrigin.camera,
              unreadable: true,
            ),
          ]),
        ),
        isNull,
      );
    });

    test('el texto manda sobre el adjunto', () {
      expect(
        NotificationLabel.ofTask(
          _task('Leer esto', [
            _attachment(AttachmentKind.pdf, AttachmentOrigin.file),
          ]),
        ),
        const NotificationTextLabel('Leer esto'),
      );
    });
  });

  group('CA-028-16 / CA-019-16, 17 y 21: los textos', () {
    test('Foto, Imagen y PDF en el idioma de la app; texto y dominio tal '
        'cual', () {
      final es = _texts('es');
      final en = _texts('en');
      expect(es.bodyFor(const NotificationPhotoLabel()), 'Foto');
      expect(es.bodyFor(const NotificationImageLabel()), 'Imagen');
      expect(es.bodyFor(const NotificationPdfLabel()), 'PDF');
      expect(en.bodyFor(const NotificationPhotoLabel()), 'Photo');
      expect(en.bodyFor(const NotificationImageLabel()), 'Image');
      expect(en.bodyFor(const NotificationPdfLabel()), 'PDF');
      for (final t in [es, en]) {
        expect(t.bodyFor(const NotificationTextLabel('hola')), 'hola');
        expect(
          t.bodyFor(const NotificationDomainLabel('example.com')),
          'example.com',
        );
      }
    });

    test('sin etiqueta, el cuerpo es el genérico', () {
      expect(_texts('es').bodyFor(null), 'Tienes una tarea pendiente.');
      expect(_texts('en').bodyFor(null), 'You have a task waiting.');
    });

    test('notificationTextsFor: el elegido en Ajustes o, con «Como el '
        'sistema», la regla de la 010', () {
      final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
      addTearDown(dispatcher.clearLocalesTestValue);
      dispatcher.localesTestValue = const [Locale('en', 'US')];
      expect(notificationTextsFor(LocaleChoice.es).title, 'Tarea actual');
      expect(notificationTextsFor(LocaleChoice.en).title, 'Current task');
      expect(notificationTextsFor(LocaleChoice.system).title, 'Current task');
      for (final (locales, title) in [
        (const [Locale('es', 'ES')], 'Tarea actual'),
        (const [Locale('ca', 'ES'), Locale('en', 'US')], 'Tarea actual'),
        (const [Locale('gl'), Locale('es')], 'Tarea actual'),
        (const [Locale('gl')], 'Current task'),
      ]) {
        dispatcher.localesTestValue = locales;
        expect(
          notificationTextsFor(LocaleChoice.system).title,
          title,
          reason: '$locales',
        );
      }
      dispatcher.localesTestValue = const [Locale('es', 'ES')];
      final es = notificationTextsFor(LocaleChoice.system);
      expect(
        (es.publicBody, es.photo, es.image, es.pdf),
        ('Tienes una tarea pendiente.', 'Foto', 'Imagen', 'PDF'),
      );
    });
  });

  group('CA-028-15 / CA-019-03, 10 y 15: los avisos que se programan', () {
    final es = _texts('es');
    final task = _task('Llamar a Marta');

    test('1, 2 o 3 al día, a las 08:55, 13:55 y 18:55', () {
      for (final (perDay, hours) in [
        (NotificationsPerDay.one, ['08:55']),
        (NotificationsPerDay.two, ['08:55', '13:55']),
        (NotificationsPerDay.three, ['08:55', '13:55', '18:55']),
      ]) {
        final slots = notificationSlots(
          on: true,
          perDay: perDay,
          task: task,
          texts: es,
        );
        expect(slots.map((s) => s.time.label).toList(), hours);
        for (final s in slots) {
          expect(s.title, 'Tarea actual');
          expect(s.body, 'Llamar a Marta');
          expect(s.publicBody, 'Tienes una tarea pendiente.');
        }
      }
    });

    test('apagado o sin tarea actual: nada', () {
      expect(
        notificationSlots(
          on: false,
          perDay: NotificationsPerDay.three,
          task: task,
          texts: es,
        ),
        isEmpty,
      );
      expect(
        notificationSlots(
          on: true,
          perDay: NotificationsPerDay.three,
          task: null,
          texts: es,
        ),
        isEmpty,
      );
    });

    test('CA-019-17: la versión pública y el título no llevan nada de la '
        'tarea', () {
      const secret = 'SECRETO-7 www.ejemplo.test';
      for (final t in [_texts('es'), _texts('en')]) {
        final slot = notificationSlots(
          on: true,
          perDay: NotificationsPerDay.one,
          task: _task(secret),
          texts: t,
        ).single;
        expect(slot.body, secret);
        expect(slot.publicBody.contains('SECRETO'), isFalse);
        expect(slot.title.contains('SECRETO'), isFalse);
        expect(slot.toString().contains('SECRETO'), isFalse);
      }
    });

    test('sin etiqueta (grupo de fotos): el cuerpo es el genérico', () {
      final photo = _attachment(AttachmentKind.image, AttachmentOrigin.camera);
      final slot = notificationSlots(
        on: true,
        perDay: NotificationsPerDay.one,
        task: _task(null, [photo, photo]),
        texts: es,
      ).single;
      expect(slot.body, slot.publicBody);
    });
  });
}
