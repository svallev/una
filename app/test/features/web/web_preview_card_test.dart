import 'package:app/app/providers.dart';
import 'package:app/app/theme/tokens.g.dart';
import 'package:app/data/in_memory_task_repository.dart';
import 'package:app/domain/entities/link_target.dart';
import 'package:app/domain/entities/staged_attachment.dart';
import 'package:app/domain/entities/task.dart';
import 'package:app/domain/ports/attachment_store.dart';
import 'package:app/domain/ports/link_opener.dart';
import 'package:app/features/complete/hold_to_complete_button.dart';
import 'package:app/features/web/web_bar.dart';
import 'package:app/ui/brutal_button.dart';
import 'package:app/ui/square_icon_button.dart';
import 'package:app/ui/una_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_web_page_driver.dart';
import '../../support/focus.dart';
import '../../support/fonts.dart';

const _address = 'https://www.congreso.ejemplo.com/programa?dia=2';
const _host = 'congreso.ejemplo.com';

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

class _Opener implements LinkOpener {
  final opened = <LinkTarget>[];
  @override
  Future<bool> open(LinkTarget target) async {
    opened.add(target);
    return true;
  }
}

void main() {
  setUpAll(loadAppFonts);

  late FakeWebPages web;
  late _Opener links;
  late List<Uri> tabs;

  setUp(() {
    web = FakeWebPages();
    links = _Opener();
    tabs = [];
  });

  /// La web de pruebas con la tarea web como actual: sin WebView ni giro.
  Future<void> pumpPreview(WidgetTester tester) async {
    final repo = InMemoryTaskRepository();
    await repo.insert(_webTask());
    await pumpUnaApp(
      tester,
      repo: repo,
      tasks: const ['Segunda'],
      overrides: [
        ...web.overrides,
        webPreviewProvider.overrideWithValue(true),
        newTabOpenerProvider.overrideWithValue(tabs.add),
        linkOpenerProvider.overrideWithValue(links),
        attachmentRotatesProvider.overrideWithValue(false),
      ],
    );
    await tester.pumpAndSettle();
  }

  final openPage = find.text('Abrir página →');

  group('CL-009-5: web de pruebas, tarjeta del prototipo', () {
    testWidgets('la barra con el dominio y "WEB"; debajo, el dominio, la '
        'dirección entera y "Abrir página →"; el menú y el botón de '
        'completar como siempre', (tester) async {
      await pumpPreview(tester);
      final bar = tester.widget<WebBar>(find.byType(WebBar));
      expect((bar.host, bar.badge, bar.secure), (_host, 'WEB', true));
      final card = find.byKey(const ValueKey('web-preview-card'));
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(_host)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(_address)),
        findsOneWidget,
      );
      expect(openPage, findsOneWidget);
      expect(find.byType(SquareIconButton), findsOneWidget);
      expect(find.byType(HoldToCompleteButton), findsOneWidget);
      // La tarjeta, entre la barra y el botón de completar.
      final cardRect = tester.getRect(card);
      expect(
        cardRect.top,
        greaterThanOrEqualTo(tester.getRect(find.byType(WebBar)).bottom - 0.5),
      );
      expect(
        tester.getRect(openPage).bottom,
        lessThan(tester.getRect(find.byType(HoldToCompleteButton)).top),
      );
    });

    testWidgets('sin WebView: no se crea ninguna, no se carga nada, sin línea '
        'de carga ni marca de uso', (tester) async {
      await pumpPreview(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(web.drivers, isEmpty);
      expect(find.byKey(const ValueKey('web-loading')), findsNothing);
      expect(find.byKey(const ValueKey('web-view-0')), findsNothing);
      expect(web.janitor.marks, 0);
      expect(
        find.text('Necesitas conexión para ver esta página.'),
        findsNothing,
      );
    });

    testWidgets('"Abrir página →" abre la dirección guardada en una pestaña '
        'nueva (no el enlace nativo)', (tester) async {
      await pumpPreview(tester);
      await tester.tap(openPage);
      await tester.pump();
      expect(tabs, [Uri.parse(_address)]);
      expect(links.opened, isEmpty);
    });

    testWidgets('CA-009-20 / spec §6 (WCAG 2.4.7): con Tab, "Abrir página →" '
        'muestra el anillo de foco', (tester) async {
      await pumpPreview(tester);
      expect(await tabUntilRing(tester, 'Abrir página →'), isTrue);
    });

    testWidgets('"Abrir página →" es un botón para el lector (como '
        'todo UnaLinkButton), ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPreview(tester);
      expect(
        tester.getSemantics(openPage),
        isSemantics(
          label: 'Abrir página →',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(openPage).rect.height,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });

    testWidgets('"Abrir página →" es un enlace de texto (UnaLinkButton, como '
        'los avisos, DEV-48): sin caja ni el estilo del botón principal, '
        'ajustado al texto, bajo la dirección y a la izquierda', (
      tester,
    ) async {
      await pumpPreview(tester);
      final card = find.byKey(const ValueKey('web-preview-card'));
      final link = find.ancestor(
        of: openPage,
        matching: find.byType(UnaLinkButton),
      );
      expect(link, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.byType(BrutalButton)),
        findsNothing,
      );
      final linkRect = tester.getRect(link);
      final cardRect = tester.getRect(card);
      final addressRect = tester.getRect(
        find.descendant(of: card, matching: find.text(_address)),
      );
      // Ajustado al texto: mucho más estrecho que la tarjeta.
      expect(linkRect.width, lessThan(cardRect.width / 2));
      expect(
        linkRect.width,
        lessThanOrEqualTo(tester.getSize(openPage).width + 2 * UnaSpace.s),
      );
      // A la izquierda, como la dirección (el enlace lleva su margen).
      expect(
        (linkRect.left - addressRect.left).abs(),
        lessThanOrEqualTo(UnaSpace.s),
      );
      // Justo bajo la dirección, no al fondo de la tarjeta.
      expect(linkRect.top, greaterThanOrEqualTo(addressRect.bottom));
      expect(linkRect.top - addressRect.bottom, lessThanOrEqualTo(UnaSpace.l));
      expect(linkRect.height, greaterThanOrEqualTo(kMinInteractiveDimension));
      final style = tester.widget<Text>(openPage).style!;
      expect(style.decoration, TextDecoration.underline);
      expect(style.fontFamily, UnaFonts.mono);
    });

    // Que no pide la orientación lo decide `AttachmentRotation` con `kIsWeb`
    // (CL-008-12); aquí, lo que se ve.
    testWidgets('sin giro: con la ventana apaisada se ve como en vertical, '
        'con la tarjeta', (tester) async {
      await pumpPreview(tester);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(find.byType(WebBar), findsOneWidget);
      expect(find.byType(SquareIconButton), findsOneWidget);
      expect(find.byKey(const ValueKey('web-preview-card')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('texto al 200 % en 360 dp: la tarjeta se desplaza y nada se '
        'desborda', (tester) async {
      await pumpPreview(tester);
      tester.view.physicalSize = const Size(360, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        openPage,
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('web-preview-card')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.getSize(openPage).height, greaterThan(0));
      expect(
        tester
            .getSize(
              find.ancestor(of: openPage, matching: find.byType(UnaLinkButton)),
            )
            .height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
      await tester.tap(openPage);
      await tester.pump();
      expect(tabs, [Uri.parse(_address)]);
    });
  });
}
