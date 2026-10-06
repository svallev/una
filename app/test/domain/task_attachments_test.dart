import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/image_type.dart';
import 'package:app/domain/entities/task.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 10, 6);

Attachment _att(
  String id, {
  AttachmentKind kind = AttachmentKind.image,
  bool unreadable = false,
}) => Attachment(
  id: id,
  kind: kind,
  origin: kind == AttachmentKind.pdf
      ? AttachmentOrigin.file
      : AttachmentOrigin.gallery,
  mime: 'image/jpeg',
  byteSize: 10,
  width: 100,
  height: 100,
  createdAt: _at,
  unreadable: unreadable,
);

List<Attachment> _images(int n) => [for (var i = 0; i < n; i++) _att('a$i')];

Task _task({Attachment? attachment, List<Attachment>? attachments}) => Task(
  id: 't',
  text: 'x',
  status: TaskStatus.pending,
  rank: 'a',
  colorKey: 0,
  createdAt: _at,
  updatedAt: _at,
  attachment: attachment,
  attachments: attachments,
);

void main() {
  group('AttachmentGroup', () {
    test('CA-016-14: 0 adjuntos es válido y no es grupo de fotos', () {
      expect(const <Attachment>[].isValidGroup, isTrue);
      expect(const <Attachment>[].isPhotoGroup, isFalse);
    });

    test('CA-016-14: uno de cada tipo es válido y no es grupo de fotos', () {
      for (final kind in AttachmentKind.values) {
        final one = [_att('a', kind: kind)];
        expect(one.isValidGroup, isTrue, reason: kind.name);
        expect(one.isPhotoGroup, isFalse, reason: kind.name);
      }
    });

    test('CA-016-14: de 2 a 10 imágenes es un grupo válido', () {
      for (var n = 2; n <= ImageLimits.maxGroup; n++) {
        expect(_images(n).isValidGroup, isTrue, reason: '$n');
        expect(_images(n).isPhotoGroup, isTrue, reason: '$n');
      }
    });

    test('CA-016-14: 11 imágenes no son válidas (tope de 10)', () {
      expect(ImageLimits.maxGroup, 10);
      expect(_images(11).isValidGroup, isFalse);
      expect(_images(11).isPhotoGroup, isFalse);
      expect(_images(500).isValidGroup, isFalse);
    });

    test('CA-016-25: un PDF o una web con otra fila no es válido', () {
      for (final kind in [AttachmentKind.pdf, AttachmentKind.web]) {
        final mixed = [_att('a', kind: kind), _att('b')];
        expect(mixed.isValidGroup, isFalse, reason: kind.name);
        expect(mixed.isPhotoGroup, isFalse, reason: kind.name);
        final reversed = [_att('b'), _att('a', kind: kind)];
        expect(reversed.isValidGroup, isFalse, reason: kind.name);
      }
      expect(
        [
          _att('a', kind: AttachmentKind.pdf),
          _att('b', kind: AttachmentKind.pdf),
        ].isValidGroup,
        isFalse,
      );
    });

    test('CA-016-25: una fila unreadable invalida la tarea entera', () {
      final withBad = [_att('a'), _att('b', unreadable: true), _att('c')];
      expect(withBad.isValidGroup, isFalse);
      expect(withBad.isPhotoGroup, isFalse);
      expect([_att('a', unreadable: true)].isValidGroup, isFalse);
    });
  });

  group('Task.attachments', () {
    test('CA-016-14: attachment es la primera y null sin ninguna', () {
      final imgs = _images(3);
      expect(_task(attachments: imgs).attachment, imgs.first);
      expect(_task(attachments: imgs).attachments, imgs);
      expect(_task().attachment, isNull);
      expect(_task().attachments, isEmpty);
    });

    test('CA-016-14: attachment: sigue siendo el atajo de uno solo', () {
      final one = _att('a');
      final t = _task(attachment: one);
      expect(t.attachments, [one]);
      expect(t.attachment, one);
    });

    test('CA-016-14: no admite attachment y attachments a la vez', () {
      expect(
        () => _task(attachment: _att('a'), attachments: _images(2)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('CA-016-14: la lista es inmutable y no depende de la original', () {
      final source = _images(2);
      final t = _task(attachments: source);
      expect(() => t.attachments.add(_att('z')), throwsUnsupportedError);
      source.add(_att('z'));
      expect(t.attachments, hasLength(2));
    });

    test('CA-016-25: construir una mezcla inválida no lanza', () {
      expect(_task(attachments: _images(11)).attachments, hasLength(11));
      expect(
        () => _task(
          attachments: [
            _att('a', kind: AttachmentKind.pdf),
            _att('b'),
          ],
        ),
        returnsNormally,
      );
      expect(
        () => _task(
          attachments: [_att('a'), _att('b', unreadable: true), _att('c')],
        ),
        returnsNormally,
      );
      expect(
        _task(attachments: [_att('a'), _att('b', unreadable: true), _att('c')])
            .attachments
            .isValidGroup,
        isFalse,
      );
    });

    test('CA-016-14: la igualdad compara la lista, en orden', () {
      final a = _images(3);
      expect(_task(attachments: a), _task(attachments: [...a]));
      expect(
        _task(attachments: a),
        isNot(_task(attachments: [a[1], a[0], a[2]])),
      );
      expect(_task(attachments: a), isNot(_task(attachments: a.sublist(0, 2))));
      expect(_task(attachment: a[0]), _task(attachments: [a[0]]));
    });

    test('CA-016-14: withContent acepta una lista y el de uno sigue', () {
      final t = _task(attachment: _att('a'));
      final imgs = _images(3);
      final grouped = t.withContent('y', null, _at, attachments: imgs);
      expect(grouped.attachments, imgs);
      expect(grouped.text, 'y');
      final one = t.withContent('y', _att('b'), _at);
      expect(one.attachments.map((a) => a.id), ['b']);
      expect(t.withContent('y', null, _at).attachments, isEmpty);
      expect(
        () => t.withContent('y', _att('b'), _at, attachments: imgs),
        throwsA(isA<AssertionError>()),
      );
    });

    test('CA-016-14: withText y withRank conservan todo el grupo', () {
      final imgs = _images(4);
      final t = _task(attachments: imgs);
      expect(t.withText('otro', _at).attachments, imgs);
      expect(t.withRank('b', _at).attachments, imgs);
    });
  });

  test('CA-016-14: el estimado de una foto guardada y el tiempo del grupo', () {
    expect(ImageLimits.groupTimeout, const Duration(minutes: 2));
    expect(ImageLimits.storedPhotoEstimate, 16 * 1000 * 1000);
  });
}
