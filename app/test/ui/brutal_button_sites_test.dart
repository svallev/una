import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/attachments/memory_attachment_store.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/license_package.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/ports/license_source.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/attachments/link_confirm_sheet.dart';
import 'package:app/features/editor/task_editor_screen.dart';
import 'package:app/features/settings/licenses_screen.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/task_list/task_list_screen.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/una_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/task_list/list_harness.dart';
import '../support/app_harness.dart';
import '../support/fake_image_importer.dart';
import '../support/fake_pdf_importer.dart';
import '../support/fonts.dart';
import '../support/pump_app.dart';
import '../support/semantics_stops.dart';

/// Quitar `container: true` de `BrutalButton` (CA-013-04, plan 013 P-013-4)
/// cambia el árbol de accesibilidad de toda la app: en cada sitio sensible el
/// botón es **un solo nodo** con etiqueta, `tap` y `focus`, y el aviso de foco
/// del lector llega a ese nodo.

/// Los nodos (no fundidos en su padre) cuya etiqueta es [label].
List<SemanticsNode> _nodesLabelled(WidgetTester tester, String label) {
  final out = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent && node.getSemanticsData().label == label) {
      out.add(node);
    }
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

/// Un solo nodo con [label], de botón, con `tap` y (si [focus]) `focus`;
/// devuelve su id.
int _expectSingleButtonNode(
  WidgetTester tester,
  String label, {
  bool focus = true,
}) {
  final nodes = _nodesLabelled(tester, label);
  expect(nodes, hasLength(1), reason: 'un solo nodo "$label"');
  final data = nodes.single.getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue, reason: label);
  expect(data.hasAction(SemanticsAction.tap), isTrue, reason: '$label: tap');
  if (focus) {
    expect(
      data.hasAction(SemanticsAction.focus),
      isTrue,
      reason: '$label: focus',
    );
  }
  return nodes.single.id;
}

/// Ids de los nodos que han recibido el aviso de foco del lector.
List<int> _recordFocusEvents(WidgetTester tester) {
  final ids = <int>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final map = message! as Map<Object?, Object?>;
      if (map['type'] == 'focus') ids.add(map['nodeId']! as int);
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
  return ids;
}

/// Envía el aviso de foco del lector desde la clave del nodo del botón
/// [label], como hacen el editor y el listado al devolverle el foco. Se manda
/// a mano porque en el código real sale justo al cerrar una hoja, con la
/// pantalla de debajo aún oculta al lector: el test comprueba que la clave
/// resuelve al nodo único del botón.
Future<void> _sendFocusEventFromKey(WidgetTester tester, String label) async {
  final button = tester.widget<BrutalButton>(
    find.byWidgetPredicate((w) => w is BrutalButton && w.label == label),
  );
  button.semanticsKey!.currentContext!.findRenderObject()!.sendSemanticsEvent(
    const FocusSemanticEvent(),
  );
  await tester.pump();
}

class _Opener implements LinkOpener {
  @override
  Future<bool> canOpen(LinkTarget target) async => true;

  @override
  Future<bool> open(LinkTarget target) async => true;
}

class _FailingSource implements LicenseSource {
  @override
  Future<List<LicensePackage>> load() => Future.error(StateError('boom'));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(UnaMotion.sheetOut);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('BrutalButton suelto (CA-013-04)', () {
    testWidgets(
      'CA-013-04: con texto, con icono y "ghost" son un solo nodo con etiqueta, tap y focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithApp(
          tester,
          Column(
            children: [
              BrutalButton(label: 'Guardar', onPressed: () {}),
              BrutalButton.icon(
                label: 'Añadir',
                icon: UnaIcons.plus,
                onPressed: () {},
              ),
              BrutalButton(label: 'Cancelar', ghost: true, onPressed: () {}),
            ],
          ),
        );
        for (final label in ['Guardar', 'Añadir', 'Cancelar']) {
          _expectSingleButtonNode(tester, label);
          // Un solo nodo con la etiqueta: bySemanticsLabel da ese nodo (ojo:
          // getSemantics(find.byType(BrutalButton)) devuelve un ancestro).
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          expect(node.id, _nodesLabelled(tester, label).single.id);
          expect(node.getSemanticsData().label, label);
        }
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04: deshabilitado, un solo nodo con su etiqueta y sin tap ni focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithApp(
          tester,
          const BrutalButton(label: 'Guardar', onPressed: null),
        );
        final nodes = _nodesLabelled(tester, 'Guardar');
        expect(nodes, hasLength(1));
        final data = nodes.single.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(data.hasAction(SemanticsAction.focus), isFalse);
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );
  });

  group('Sitios sensibles (CA-013-04, CA-004-10)', () {
    testWidgets(
      'CA-013-04 / CA-008-21: confirmación de un enlace (política de privacidad): "Cancelar" y "Abrir" son un nodo cada uno y el aviso de foco llega a "Cancelar"',
      (tester) async {
        final handle = tester.ensureSemantics();
        final events = _recordFocusEvents(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
          screenReader: true,
          overrides: [linkOpenerProvider.overrideWithValue(_Opener())],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Configuración y perfil'));
        await _settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text('Política de privacidad'),
          ),
        );
        await _settle(tester);
        expect(find.byType(LinkConfirmSheet), findsOneWidget);
        final cancel = _expectSingleButtonNode(tester, 'Cancelar');
        _expectSingleButtonNode(tester, 'Abrir');
        expect(events, contains(cancel));
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04 / CA-007-22: el "+" del editor es un solo nodo con etiqueta, tap y focus y el aviso de foco que sale de su clave llega a él',
      (tester) async {
        final handle = tester.ensureSemantics();
        final events = _recordFocusEvents(tester);
        final store = MemoryAttachmentStore();
        await pumpWithApp(
          tester,
          const TaskEditorScreen(mode: EditorMode.first),
          overrides: [
            attachmentStoreProvider.overrideWithValue(store),
            imageImporterProvider.overrideWithValue(FakeImageImporter(store)),
            pdfImporterProvider.overrideWithValue(FakePdfImporter(store)),
          ],
        );
        await tester.pumpAndSettle();
        const plusLabel = 'Añadir foto, imagen o archivo';
        final plus = _expectSingleButtonNode(tester, plusLabel);
        await _sendFocusEventFromKey(tester, plusLabel);
        expect(events, [plus]);
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04 / CA-006-17: "Nueva tarea" del listado es un solo nodo con etiqueta, tap y focus y el aviso de foco que sale de su clave llega a él',
      (tester) async {
        final handle = tester.ensureSemantics();
        final events = _recordFocusEvents(tester);
        await openList(
          tester,
          tasks: ['Primera', 'Segunda'],
          screenReader: true,
        );
        expect(find.byType(TaskListScreen), findsOneWidget);
        final newTask = _expectSingleButtonNode(tester, 'Nueva tarea');
        await _sendFocusEventFromKey(tester, 'Nueva tarea');
        expect(events, [newTask]);
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );

    testWidgets(
      'CA-013-04 / CA-012-15: "Reintentar" del nivel 2 es un solo nodo con tap, focus y la pista del error, y recibe el aviso de foco',
      (tester) async {
        final handle = tester.ensureSemantics();
        final events = _recordFocusEvents(tester);
        await pumpUnaApp(
          tester,
          repo: InMemoryTaskRepository(),
          tasks: ['Primera'],
          screenReader: true,
          overrides: [
            linkOpenerProvider.overrideWithValue(_Opener()),
            licenseSourceProvider.overrideWithValue(_FailingSource()),
          ],
        );
        await tester.tap(find.bySemanticsLabel('Menú de la tarea'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Configuración y perfil'));
        await _settle(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.text('Licencias de código abierto'),
          ),
        );
        await _settle(tester);
        expect(find.byType(LicensesScreen), findsOneWidget);
        final retry = _expectSingleButtonNode(tester, 'Reintentar');
        expect(events, contains(retry));
        expect(
          _nodesLabelled(tester, 'Reintentar').single.hint,
          'No se pudieron cargar las licencias.',
        );
        expectNoUnnamedSemanticsStops(tester);
        handle.dispose();
      },
    );
  });
}
