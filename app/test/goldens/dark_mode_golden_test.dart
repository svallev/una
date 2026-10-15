// Spec 021, CA-021-06 (T-021-05): la app se ve píxel a píxel igual con el sistema en claro y en
// oscuro.
//
// - Primera parte: cada suite de *goldens* existente se vuelve a correr con el brillo de la
//   plataforma en oscuro **contra los mismos PNG** de claro. Se omiten donde se omiten las
//   originales (solo se comparan en Linux; ver docs/testing.md, "Goldens"). Este archivo **no**
//   lleva la etiqueta `golden`: así `flutter test --update-goldens --tags golden` (el trabajo de
//   `actualizar-goldens`) no lo corre, y su comparador, además, nunca escribe un PNG.
// - Segunda parte: lo que no tiene *golden* (aviso de error al guardar, «Cargar URL», el marco de
//   la web ya cargada, el menú de selección de texto y sus asas) se monta en claro y en oscuro y
//   se comparan los píxeles y la lectura. Esa parte corre en cualquier sistema.
import 'dart:typed_data';

import 'package:app/app/providers.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/web/url_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/settings/settings_harness.dart';
import '../support/app_harness.dart';
import '../support/dark_mode.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_web_page_driver.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';
import 'complete_golden_test.dart' as complete;
import 'delete_golden_test.dart' as delete;
import 'image_golden_test.dart' as image;
import 'menu_editor_golden_test.dart' as menu_editor;
import 'pdf_golden_test.dart' as pdf;
import 'photo_group_golden_test.dart' as photo_group;
import 'screens_golden_test.dart' as screens;
import 'settings_golden_test.dart' as settings;
import 'task_list_golden_test.dart' as task_list;
import 'web_golden_test.dart' as web_goldens;

const _address = 'https://www.congreso.ejemplo.com/programa';

class _FakeComparator implements GoldenFileComparator {
  _FakeComparator({required this.matches});

  final bool matches;
  final updates = <Uri>[];

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => matches;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async =>
      updates.add(golden);

  @override
  Uri getTestUri(Uri key, int? version) => key;
}

/// Falla al guardar mientras [fail] sea verdadero (el error del editor, spec 001 §5).
class _FailingRepository extends InMemoryTaskRepository {
  bool fail = true;

  @override
  Future<void> insert(Task task) async {
    if (fail) throw StateError('disk I/O error');
    return super.insert(task);
  }
}

Task _webTask() {
  final at = DateTime.utc(2026, 9, 29, 9);
  return Task(
    id: 'w',
    text: null,
    status: TaskStatus.pending,
    rank: 'MA',
    colorKey: 3,
    createdAt: at,
    updatedAt: at,
    attachment: attachmentFrom(StagedWeb(id: 'a-w', url: _address), at),
  );
}

void main() {
  setUpAll(loadAppFonts);

  group('CA-021-06: suites de goldens con el sistema en oscuro (mismos PNG de claro)', () {
    final suites = <String, void Function()>{
      'screens (spec 001)': screens.main,
      'menú y editor (specs 002 y 005)': menu_editor.main,
      'tarea completada (spec 003)': complete.main,
      'eliminar y deshacer (specs 004 y 014)': delete.main,
      'imagen (spec 007)': image.main,
      'PDF (spec 008)': pdf.main,
      'web (spec 009)': web_goldens.main,
      'listado (spec 006)': task_list.main,
      'Ajustes (specs 015, 017 y 019)': settings.main,
      'varias fotos (spec 016)': photo_group.main,
    };
    for (final MapEntry(:key, :value) in suites.entries) {
      group(key, () => runSuiteInDarkMode(value));
    }
  });

  group('CA-021-06: el comparador de la suite de oscuro no escribe PNG', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final key = Uri.parse('goldens/x.png');

    test(
      'CA-021-06: pedirle actualizar con un PNG distinto falla y no escribe',
      () async {
        final inner = _FakeComparator(matches: false);
        final comparator = CompareOnlyComparator(inner);
        await expectLater(
          comparator.update(key, bytes),
          throwsA(isA<TestFailure>()),
        );
        expect(inner.updates, isEmpty);
      },
    );

    test(
      'CA-021-06: pedirle actualizar con un PNG igual pasa y tampoco escribe',
      () async {
        final inner = _FakeComparator(matches: true);
        await CompareOnlyComparator(inner).update(key, bytes);
        expect(inner.updates, isEmpty);
      },
    );

    test('CA-021-06: comparar delega en el comparador de verdad', () async {
      expect(
        await CompareOnlyComparator(_FakeComparator(matches: true))
            .compare(bytes, key),
        isTrue,
      );
      expect(
        await CompareOnlyComparator(_FakeComparator(matches: false))
            .compare(bytes, key),
        isFalse,
      );
    });
  });

  group('CA-021-06: lo que no tiene golden, claro contra oscuro', () {
    testWidgets('CA-021-06: el aviso de error al guardar del editor', (
      tester,
    ) async {
      await expectSameInLightAndDark(tester, () async {
        final repo = _FailingRepository();
        await pumpWithApp(tester, const TaskEditorScreen(), repo: repo);
        await tester.enterText(find.byType(TextField), 'Llamar a Marta');
        await tester.pump();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(find.text('No hemos podido guardar la tarea'), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
      });
    });

    testWidgets('CA-021-06: el aviso de error al guardar un ajuste', (
      tester,
    ) async {
      await expectSameInLightAndDark(tester, () async {
        await openSettingsScreen(
          tester,
          repo: SettingsRepo()..error = Exception('x'),
        );
        await tester.tap(inSettings(find.text('Pantalla siempre activa')));
        await settleSettings(tester);
        expect(
          inSettings(find.text('No se pudo guardar el ajuste.')),
          findsOneWidget,
        );
      });
    });

    testWidgets('CA-021-06: la hoja «Cargar URL» con una dirección escrita', (
      tester,
    ) async {
      await expectSameInLightAndDark(tester, () async {
        final pages = FakeWebPages();
        final store = MemoryAttachmentStore();
        await pumpWithApp(
          tester,
          const TaskEditorScreen(mode: EditorMode.first),
          overrides: [
            ...pages.overrides,
            attachmentStoreProvider.overrideWithValue(store),
            imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel('Añadir foto, imagen o archivo'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cargar URL'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(UrlSheet),
            matching: find.byType(TextField),
          ),
          'www.ejemplo.com',
        );
        await tester.pumpAndSettle();
        expect(find.byType(UrlSheet), findsOneWidget);
      });
    });

    testWidgets(
      'CA-021-06: el marco de la web ya cargada (barra del dominio)',
      (tester) async {
        await expectSameInLightAndDark(tester, () async {
          final pages = FakeWebPages();
          final store = MemoryAttachmentStore();
          final repo = InMemoryTaskRepository();
          await repo.insert(_webTask());
          await pumpUnaApp(
            tester,
            repo: repo,
            overrides: [
              ...pages.overrides,
              attachmentStoreProvider.overrideWithValue(store),
              imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
            ],
          );
          await tester.pumpAndSettle();
          pages.last
            ..started(_address)
            ..progress(100)
            ..finished(_address);
          await tester.pumpAndSettle();
          expect(find.text('congreso.ejemplo.com'), findsWidgets);
        });
      },
    );

    testWidgets(
      'CA-021-06: el menú de selección de texto y las asas del editor',
      (tester) async {
        await expectSameInLightAndDark(tester, () async {
          await pumpWithApp(tester, const TaskEditorScreen());
          await tester.enterText(
            find.byType(TextField),
            'Llamar a Marta para confirmar la cena',
          );
          await tester.pump();
          await tester.longPress(find.byType(TextField));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text('Copiar'), findsOneWidget);
        });
      },
    );
  });
}
