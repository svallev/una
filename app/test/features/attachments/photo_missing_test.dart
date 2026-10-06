import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/features/attachments/attachment_health.dart';
import 'package:app/features/attachments/group_health.dart';
import 'package:app/features/attachments/missing_attachment_card.dart';
import 'package:app/features/attachments/photo_missing_box.dart';
import 'package:app/features/attachments/photo_stack.dart';
import 'package:app/features/attachments/task_image.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/attachments.dart';
import '../../support/fake_image_importer.dart';
import '../../support/fonts.dart';
import '../../support/pump_app.dart';

/// Salud del grupo de fotos y fotos que faltan (spec 016, CA-016-18a/b, 23 y
/// 25): una foto que falta no tumba a las demás; solo faltan todas o un grupo
/// que no es válido → "Adjunto no disponible".
void main() {
  setUpAll(loadAppFonts);

  late MemoryAttachmentStore store;
  late FakeImageImporter importer;
  late InMemoryTaskRepository repo;
  late List<String> announcements;

  setUp(() {
    store = MemoryAttachmentStore();
    importer = FakeImageImporter(store);
    repo = InMemoryTaskRepository();
  });

  void listen(WidgetTester tester) {
    announcements = [];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
  }

  List<Override> overrides() => [
    attachmentStoreProvider.overrideWithValue(store),
    imageImporterProvider.overrideWithValue(importer),
  ];

  /// [n] fotos guardadas (`g0`, `g1`…) con todos sus archivos.
  Future<List<Attachment>> photos(int n) async => [
    for (var i = 0; i < n; i++)
      await store.commit(
        stageImage(store, 'g$i', origin: AttachmentOrigin.gallery),
        DateTime.utc(2026, 9, 20),
      ),
  ];

  Task taskOf(List<Attachment> attachments, {String text = 'Horario'}) {
    final base = sampleTask(text: text, colorKey: 3, rank: 'M');
    return base.withContent(
      text,
      null,
      base.updatedAt,
      attachments: attachments,
    );
  }

  ProviderContainer container() {
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    return c;
  }

  /// Espera (con reloj real) a que [done] se cumpla.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'no llegó a cumplirse a tiempo');
  }

  /// Mantiene viva la salud de la foto [a] (como la foto a la vista).
  ProviderSubscription<AttachmentHealthState> watchPhoto(
    ProviderContainer c,
    Attachment a,
  ) => c.listen(attachmentHealthProvider(a), (_, _) {});

  AttachmentHealth healthOf(ProviderContainer c, Attachment a) =>
      c.read(attachmentHealthProvider(a)).health;

  GroupHealthState groupOf(ProviderContainer c, List<Attachment> all) =>
      c.read(groupHealthProvider(AttachmentGroupKey(all)));

  group('CA-016-18a: falta una foto del grupo, no todas', () {
    test('el grupo se ve y solo esa foto es "no disponible"', () async {
      final all = await photos(3);
      store.removeFile('g1', 'full-0-0.jpg');
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub.read().health != AttachmentHealth.checking);

      expect(sub.read().health, AttachmentHealth.ok);
      expect(sub.read().missingIds, {'g1'});
      final photoSubs = [for (final a in all) watchPhoto(c, a)];
      await until(
        () => photoSubs.every(
          (s) => s.read().health != AttachmentHealth.checking,
        ),
      );
      expect(
        [for (final a in all) healthOf(c, a)],
        [AttachmentHealth.ok, AttachmentHealth.missing, AttachmentHealth.ok],
      );
    });

    test('vacía o con una tesela vacía también cuenta como perdida', () async {
      final all = await photos(3);
      store.putStored('g0', 'full-0-0.jpg', Uint8List(0));
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub.read().health != AttachmentHealth.checking);
      expect(sub.read().health, AttachmentHealth.ok);
      expect(sub.read().missingIds, {'g0'});
    });

    test('si solo faltan derivadas, no cuenta como perdida', () async {
      final all = await photos(3);
      store
        ..removeFile('g0', 'screen.jpg')
        ..removeFile('g2', 'thumb.jpg');
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub.read().health != AttachmentHealth.checking);
      expect(sub.read().health, AttachmentHealth.ok);
      expect(sub.read().missingIds, isEmpty);
      // Y el grupo no regenera nada: eso es de cada foto, cuando se ve.
      expect(importer.regenerated, isEmpty);
    });

    testWidgets('en el editor, la pila pone el recuadro en su sitio y las '
        'demás se ven', (tester) async {
      final all = await photos(3);
      store.removeFile('g0', 'full-0-0.jpg');
      await pumpWithApp(
        tester,
        TaskEditorScreen(mode: EditorMode.edit, task: taskOf(all)),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhotoStack), findsOneWidget);
      expect(find.text('3 fotos'), findsOneWidget);
      // La primera (arriba) es el recuadro; las otras dos, imágenes.
      final top = find.descendant(
        of: find.byKey(PhotoStack.cardKey(0)),
        matching: find.byType(PhotoMissingBox),
      );
      expect(top, findsOneWidget);
      expect(find.byType(PhotoMissingBox), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PhotoStack.cardKey(1)),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('en el editor, con todas las fotos bien no hay ningún '
        'recuadro', (tester) async {
      final all = await photos(3);
      await pumpWithApp(
        tester,
        TaskEditorScreen(mode: EditorMode.edit, task: taskOf(all)),
        repo: repo,
        overrides: overrides(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhotoMissingBox), findsNothing);
    });
  });

  group('CA-016-18b: faltan todas las fotos', () {
    test('todas perdidas → la tarea es "no disponible"', () async {
      final all = await photos(3);
      for (final a in all) {
        store.removeFile(a.id, 'full-0-0.jpg');
      }
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub.read().health != AttachmentHealth.checking);
      expect(sub.read().health, AttachmentHealth.missing);
      expect(sub.read().missingIds, {'g0', 'g1', 'g2'});
    });

    test('corruptas: las que el carrusel no pudo dibujar ni regenerar '
        'cuentan, y con la última cae la tarea entera', () async {
      final all = await photos(3);
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub.read().health != AttachmentHealth.checking);
      expect(sub.read().health, AttachmentHealth.ok);

      final controller = c.read(
        groupHealthProvider(AttachmentGroupKey(all)).notifier,
      );
      controller
        ..reportMissing('g0')
        ..reportMissing('g2');
      expect(sub.read().health, AttachmentHealth.ok);
      expect(sub.read().missingIds, {'g0', 'g2'});
      controller
        ..reportMissing('g2')
        ..reportMissing('desconocida');
      expect(sub.read().health, AttachmentHealth.ok);
      controller.reportMissing('g1');
      expect(sub.read().health, AttachmentHealth.missing);
    });

    testWidgets('la tarjeta con su única acción; "Quitar adjunto" quita todo '
        'el grupo y sus archivos', (tester) async {
      listen(tester);
      final all = await photos(3);
      for (final a in all) {
        store.removeFile(a.id, 'full-0-0.jpg');
      }
      final task = taskOf(all);
      await repo.insert(task);
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(find.byType(TaskImage), findsNothing);
      expect(find.text('Adjunto no disponible'), findsOneWidget);
      expect(find.text('Horario'), findsOneWidget);
      expect(find.text('Quitar adjunto'), findsOneWidget);
      expect(find.text('Eliminar tarea'), findsNothing);

      await tester.tap(find.text('Quitar adjunto'));
      await tester.pumpAndSettle();

      final saved = (await repo.currentTask())!;
      expect(saved.attachments, isEmpty);
      expect(saved.text, 'Horario');
      expect(saved.rank, task.rank);
      expect(await store.storedIds(), isEmpty);
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(announcements, ['Adjunto quitado']);
    });

    testWidgets('sin texto: "Eliminar tarea" y se lee "Foto/Imagen"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final all = await photos(2);
      for (final a in all) {
        store.removeFile(a.id, 'full-0-0.jpg');
      }
      final base = sampleTask(text: 'x', colorKey: 3, rank: 'M');
      await repo.insert(
        base.withContent(null, null, base.updatedAt, attachments: all),
      );
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();

      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(find.text('Quitar adjunto'), findsNothing);
      expect(find.text('Eliminar tarea'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Tarea actual: Imagen. Adjunto no disponible'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('con solo una foto que falta de tres, la tarea se ve (no es '
        'la tarjeta)', (tester) async {
      listen(tester);
      final all = await photos(3);
      store.removeFile('g2', 'full-0-0.jpg');
      await repo.insert(taskOf(all));
      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();
      expect(find.byType(MissingAttachmentCard), findsNothing);
      expect(find.byType(TaskImage), findsOneWidget);
    });
  });

  group('CA-016-23: regenerar derivadas, de una en una', () {
    test('tres fotos sin pantalla ni miniatura: se regeneran sin avisar y '
        'nunca a la vez', () async {
      final all = await photos(3);
      for (final a in all) {
        store
          ..removeFile(a.id, 'screen.jpg')
          ..removeFile(a.id, 'thumb.jpg');
      }
      importer.regenerateDelay = const Duration(milliseconds: 20);
      final c = container();
      final subs = [for (final a in all) watchPhoto(c, a)];
      await until(
        () => subs.every((s) => s.read().health == AttachmentHealth.ok),
      );

      expect(importer.regenerated, ['g0', 'g1', 'g2']);
      expect(importer.maxRegenerating, 1);
      for (final s in subs) {
        expect(s.read().generation, 1);
      }
      expect(store.bytes('attachments/g1/screen.jpg'), isNotNull);
    });

    test(
      'la foto que sale de la vista antes de su turno no se regenera',
      () async {
        final all = await photos(3);
        for (final a in all) {
          store.removeFile(a.id, 'screen.jpg');
        }
        importer.regenerateDelay = const Duration(milliseconds: 30);
        final c = container();
        final first = watchPhoto(c, all[0]);
        final second = watchPhoto(c, all[1]);
        final third = watchPhoto(c, all[2]);
        // Se pasa de largo la segunda mientras la primera aún se regenera.
        await until(() => importer.regenerated.isNotEmpty);
        second.close();
        await until(() => third.read().health == AttachmentHealth.ok);

        expect(first.read().health, AttachmentHealth.ok);
        expect(importer.regenerated, ['g0', 'g2']);
        expect(importer.maxRegenerating, 1);
      },
    );

    test('un fallo de decodificación no cierra la app ni detiene a las '
        'demás: esa foto es "no disponible"', () async {
      final all = await photos(3);
      for (final a in all) {
        store.removeFile(a.id, 'screen.jpg');
      }
      importer.regenerateErrorsById['g1'] = const FormatException('corrupta');
      final c = container();
      final subs = [for (final a in all) watchPhoto(c, a)];
      await until(
        () => subs.every((s) => s.read().health != AttachmentHealth.checking),
      );

      expect(
        [for (final s in subs) s.read().health],
        [AttachmentHealth.ok, AttachmentHealth.missing, AttachmentHealth.ok],
      );
      expect(importer.maxRegenerating, 1);
    });

    test('también los errores que no son excepciones de la app', () async {
      final all = await photos(2);
      store.removeFile('g0', 'screen.jpg');
      importer.regenerateError = StateError('decodificador roto');
      final c = container();
      final sub = watchPhoto(c, all[0]);
      await until(() => sub.read().health != AttachmentHealth.checking);
      expect(sub.read().health, AttachmentHealth.missing);
    });

    test('la imagen suelta sigue como en la 007: ella misma se comprueba y '
        'regenera', () async {
      final all = await photos(1);
      store.removeFile('g0', 'thumb.jpg');
      final c = container();
      final sub = c.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => importer.regenerated.isNotEmpty);
      await until(() => sub.read().health == AttachmentHealth.ok);
      expect(importer.regenerated, ['g0']);
      expect(healthOf(c, all.single), AttachmentHealth.ok);

      store.removeFile('g0', 'full-0-0.jpg');
      final c2 = container();
      final sub2 = c2.listen(
        groupHealthProvider(AttachmentGroupKey(all)),
        (_, _) {},
      );
      await until(() => sub2.read().health != AttachmentHealth.checking);
      expect(sub2.read().health, AttachmentHealth.missing);
    });
  });

  group('CA-016-25: un grupo no válido o con datos raros', () {
    Attachment image(String id, {int width = 4000, int height = 3000}) =>
        Attachment(
          id: id,
          kind: AttachmentKind.image,
          origin: AttachmentOrigin.gallery,
          mime: 'image/jpeg',
          byteSize: 10,
          width: width,
          height: height,
          createdAt: DateTime.utc(2026),
        );

    test('es "no disponible" al instante, antes de mirar el disco', () async {
      final all = await photos(2);
      final weird = Attachment(
        id: 'raro',
        kind: AttachmentKind.image,
        origin: AttachmentOrigin.gallery,
        mime: 'image/jpeg',
        byteSize: 0,
        width: 1,
        height: 1,
        createdAt: DateTime.utc(2026),
        unreadable: true,
      );
      final group = [...all, weird];
      final c = container();
      // Sin esperar nada: ya es "no disponible", no pasa por "comprobando".
      final state = groupOf(c, group);
      expect(state.health, AttachmentHealth.missing);
      expect(state.missingIds, {'g0', 'g1', 'raro'});
    });

    test('más de 10, o PDF o web mezclados con imágenes: "no disponible"', () {
      final c = container();
      expect(
        groupOf(c, [for (var i = 0; i < 11; i++) image('i$i')]).health,
        AttachmentHealth.missing,
      );
      final pdf = Attachment(
        id: 'p',
        kind: AttachmentKind.pdf,
        origin: AttachmentOrigin.file,
        mime: 'application/pdf',
        byteSize: 10,
        width: 595,
        height: 842,
        createdAt: DateTime.utc(2026),
      );
      expect(groupOf(c, [image('a'), pdf]).health, AttachmentHealth.missing);
      expect(
        groupOf(c, [image('a'), image('b'), pdf]).health,
        AttachmentHealth.missing,
      );
    });

    testWidgets('tipo desconocido junto a 2 fotos buenas: la tarjeta desde el '
        'primer fotograma, sin excepciones', (tester) async {
      listen(tester);
      final good = await photos(2);
      final task = taskOf(const []);
      await repo.insert(task);
      await repo.updateContent(
        task.id,
        'Horario',
        DateTime.utc(2026, 9, 21),
        attachments: good,
      );
      repo.putRawAttachment(task.id, id: 'raro', kind: 'sticker', position: 2);

      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      // Sin `pumpAndSettle`: ni un fotograma de la foto antes de la tarjeta.
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(find.byType(TaskImage), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(find.byType(TaskImage), findsNothing);
      expect(find.text('Adjunto no disponible'), findsOneWidget);
      expect(find.text('Quitar adjunto'), findsOneWidget);
    });

    for (final (what, w, h) in <(String, int?, int?)>[
      ('cero', 0, 3000),
      ('negativas', -1, -1),
      ('enormes', 2147483647, 2147483647),
    ]) {
      testWidgets('medidas $what junto a otra foto: la tarjeta, sin división '
          'por cero ni excepciones', (tester) async {
        listen(tester);
        final good = await photos(1);
        final task = taskOf(const []);
        await repo.insert(task);
        await repo.updateContent(
          task.id,
          'Horario',
          DateTime.utc(2026, 9, 21),
          attachments: good,
        );
        repo.putRawAttachment(
          task.id,
          id: 'raro',
          position: 1,
          width: w,
          height: h,
        );

        await pumpUnaApp(tester, repo: repo, overrides: overrides());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(MissingAttachmentCard), findsOneWidget);
        expect(find.byType(TaskImage), findsNothing);
      });
    }

    testWidgets('una mezcla (PDF y foto) también es la tarjeta, con el icono '
        'de imagen, y "Quitar adjunto" quita todo', (tester) async {
      listen(tester);
      final good = await photos(1);
      final task = taskOf(const []);
      await repo.insert(task);
      await repo.updateContent(
        task.id,
        'Horario',
        DateTime.utc(2026, 9, 21),
        attachments: good,
      );
      repo.putRawAttachment(
        task.id,
        id: 'doc',
        kind: 'pdf',
        origin: 'file',
        position: 1,
        width: 595,
        height: 842,
      );

      await pumpUnaApp(tester, repo: repo, overrides: overrides());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(MissingAttachmentCard), findsOneWidget);
      expect(
        tester
            .widget<UnaIcon>(
              find.descendant(
                of: find.byType(MissingAttachmentCard),
                matching: find.byType(UnaIcon),
              ),
            )
            .icon,
        UnaIcons.image,
      );

      await tester.tap(find.text('Quitar adjunto'));
      await tester.pumpAndSettle();
      final saved = (await repo.currentTask())!;
      expect(saved.attachments, isEmpty);
      expect(saved.text, 'Horario');
      expect(find.byType(MissingAttachmentCard), findsNothing);
    });
  });

  test('AttachmentGroupKey compara por contenido', () async {
    final all = await photos(2);
    expect(AttachmentGroupKey(all), AttachmentGroupKey([...all]));
    expect(
      AttachmentGroupKey(all).hashCode,
      AttachmentGroupKey([...all]).hashCode,
    );
    expect(AttachmentGroupKey(all), isNot(AttachmentGroupKey([all.first])));
    expect(
      AttachmentGroupKey(all),
      isNot(AttachmentGroupKey(all.reversed.toList())),
    );
  });
}
