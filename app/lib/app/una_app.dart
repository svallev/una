import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/locale_choice.dart';
import '../features/all_done/all_done_screen.dart';
import '../features/app_error/storage_error_screen.dart';
import '../features/complete/celebration_overlay.dart';
import '../features/complete/completion_controller.dart';
import '../features/current_task/current_task_screen.dart';
import '../features/delete/crumple_overlay.dart';
import '../features/delete/deletion_controller.dart';
import '../features/delete/undo_card_host.dart';
import '../features/delete/undo_controller.dart';
import '../features/editor/task_editor_screen.dart';
import '../features/first_run/welcome_intro.dart';
import '../features/settings/settings_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/full_width.dart';
import '../ui/semantics_action_order.dart';
import 'app_identity.g.dart';
import 'locale_resolution.dart';
import 'providers.dart';
import 'theme/tokens.g.dart';
import 'theme/una_theme.dart';
import 'web_preview_banner.dart';

/// Raíz de la app.
class UnaApp extends ConsumerStatefulWidget {
  const UnaApp({super.key});

  /// Tras este tiempo en segundo plano se vuelve a la tarea actual (P-2, CA-001-12).
  static const resetAfter = Duration(minutes: 10);

  /// El barrido de adjuntos huérfanos espera a que la primera pantalla ya se
  /// vea y se haya decodificado su imagen (CA-007-16, sin retrasar CA-001-09).
  static const sweepDelay = Duration(seconds: 2);

  @override
  ConsumerState<UnaApp> createState() => _UnaAppState();
}

class _UnaAppState extends ConsumerState<UnaApp> {
  late final AppLifecycleListener _lifecycle;
  final _navigatorKey = GlobalKey<NavigatorState>();
  // Ir a otra pantalla hace definitiva la eliminación (CA-014-07).
  late final _undoObserver = UndoNavigationObserver(
    () => ref.read(undoProvider.notifier),
  );
  DateTime? _hiddenAt;
  int _resetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _hiddenAt = ref.read(clockProvider).now();
        // Segundo plano (`hidden`; la cortina y los diálogos del sistema,
        // `inactive`, no cuentan, CA-014-12): el arrugado acaba ya y la
        // eliminación es definitiva, sin card (CA-014-11).
        ref.read(deletionProvider.notifier).finishNow();
        ref.read(undoProvider.notifier).appHidden();
      },
      onShow: _onShow,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Datos de páginas que quedaron si la app se cerró sin borrarlos
      // (CA-009-13): solo con la marca, y sin retrasar el primer fotograma.
      unawaited(ref.read(webDataJanitorProvider).clearAfterLaunch());
      _sweep = Timer(UnaApp.sweepDelay, () async {
        if (!mounted) return;
        try {
          await ref.read(attachmentJanitorProvider).sweep();
        } on Object {
          // Se reintenta en el siguiente arranque. Sin registrar nada.
        }
      });
    });
  }

  Timer? _sweep;

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    if (ref.read(clockProvider).now().difference(hiddenAt) >=
        UnaApp.resetAfter) {
      _navigatorKey.currentState?.popUntil((r) => r.isFirst);
      setState(
        () => _resetGeneration++,
      ); // descarta lo que hubiera en el editor
    }
  }

  @override
  void dispose() {
    _sweep?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choice = ref.watch(settingsProvider.select((s) => s.locale));
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_undoObserver],
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) => AppIdentity.displayName,
      theme: UnaTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Idioma elegido en Ajustes (ADR-0023): con "Español" o "English" Flutter
      // usa ese `Locale` sin mirar el sistema; con "Como el sistema" no hay
      // `locale` y decide la regla de la 010. `BootState.locale` lo trae ya
      // leído: el primer fotograma sale en ese idioma (CA-015-10).
      locale: localeOfChoice(choice),
      localeListResolutionCallback: choice == LocaleChoice.system
          ? (locales, _) => resolveAppLocale(locales)
          : null,
      builder: appFrame,
      home: HomeRouter(key: ValueKey(_resetGeneration)),
    );
  }
}

/// Decide qué se ve (CA-001-03/05/09, CA-003-05/11, CA-004-07/08): tarea
/// actual; si no hay, "Todo hecho." (si ya se completó o eliminó alguna), la bienvenida (solo la primera
/// vez) o el editor de la primera tarea. Encima, la rotura y la enhorabuena al
/// completar (spec 003) o el arrugado al eliminar (spec 004).
class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(completionProvider);
    final deletion = ref.watch(deletionProvider);
    final crumpling = deletion.phase == DeletionPhase.crumpling;
    final busy = completion.busy || deletion.busy;
    final focusSignal = ref.watch(screenFocusProvider);
    final restorations = ref.watch(undoRestorationsProvider);
    final task = ref.watch(currentTaskProvider);
    final firstRunDone = ref.watch(firstRunDoneProvider);
    final hasEverHadTasks = ref.watch(hasEverHadTasksProvider);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final completing = completion.phase == CompletionPhase.completing;
    // Mientras se guarda, la tarea sigue en pantalla; mientras se arruga,
    // detrás ya está la siguiente, sin sus controles (CA-004-04).
    final shown = completing
        ? completion.task
        : deletion.phase == DeletionPhase.deleting
        ? deletion.task
        : crumpling
        ? deletion.next
        : task;
    final Widget child;
    if (shown != null) {
      // Mientras se guarda, la tarea sigue en pantalla con el relleno lleno.
      child = CurrentTaskScreen(
        key: ValueKey('task-${shown.id}'),
        task: shown,
        faceOnly: crumpling,
        focusSignal: focusSignal,
      );
    } else if (hasEverHadTasks || crumpling) {
      child = AllDoneScreen(
        key: const ValueKey('all-done'),
        // Tras eliminar la última: sin el botón hasta que cae en la papelera
        // (ocuparía el sitio de la papelera).
        showActions: !crumpling,
        focusSignal: focusSignal,
        onCreate: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditorScreen(
              colorKey: ref.read(colorPickerProvider).pick(),
            ),
          ),
        ),
      );
    } else if (!firstRunDone) {
      child = WelcomeIntro(
        key: const ValueKey('intro'),
        colorKey: ref.read(firstTaskColorProvider),
        onShown: () => ref.read(firstRunDoneProvider.notifier).persistSeen(),
        onDone: () => ref.read(firstRunDoneProvider.notifier).markDone(),
      );
    } else {
      child = const TaskEditorScreen(key: ValueKey('first-editor'));
    }
    // La card de deshacer vive dentro del nodo de la ruta de cada pantalla, no
    // en una capa aparte: al volver a montarse la pantalla tras el arrugado,
    // TalkBack no cuenta con un cambio de ventana para llegar a ella
    // (CA-014-16, plan 014 §3).
    final hasUndoCard = shown != null || hasEverHadTasks || crumpling;
    final screen = Semantics(
      key: child.key,
      scopesRoute: true,
      explicitChildNodes: true,
      child: hasUndoCard
          ? UndoCardHost(host: UndoHost.home, child: child)
          : child,
    );
    final screens = AnimatedSwitcher(
      // Al eliminar, la de detrás sustituye a la eliminada sin fundido (se
      // vería detrás de la bola): se monta de nuevo solo en ese momento
      // (CA-004-04). Lo mismo al deshacer: la recuperada se ve sin fundido
      // (CA-014-10).
      key: ValueKey('screens-${deletion.generation}-$restorations'),
      duration: reduced ? UnaMotion.reducedMotionFade : UnaMotion.introFade,
      // Cada pantalla es una "ruta" para el lector (se anuncia el cambio) y la
      // que sale no se lee durante el fundido; tampoco anima nada (así una
      // tarea web que sale deja de cargar y borra sus datos, CL-009-11). La
      // actual va envuelta igual y con su clave, para que al pasar a ser la
      // que sale no se vuelva a montar: una tarea web volvería a crear su
      // WebView y a cargar la página durante el fundido.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final p in previous)
            ExcludeSemantics(
              key: p.key,
              child: TickerMode(enabled: false, child: p),
            ),
          if (current != null)
            ExcludeSemantics(
              key: current.key,
              excluding: false,
              child: TickerMode(enabled: true, child: current),
            ),
        ],
      ),
      child: screen,
    );
    final celebrating =
        completion.phase == CompletionPhase.celebrating ||
        completion.phase == CompletionPhase.fading;
    final completed = completion.task;
    final deleted = deletion.task;
    // Durante toda la secuencia se ignoran toques, acciones y el gesto atrás,
    // sin cambiar el aspecto de nada (CA-003-09, CA-004-05, DEV-17).
    return PopScope(
      canPop: !busy,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AbsorbPointer(
            absorbing: busy,
            // Ni lector ni teclado desde que empieza a guardar.
            child: ExcludeSemantics(
              excluding: busy,
              child: ExcludeFocus(excluding: busy, child: screens),
            ),
          ),
          if (crumpling && deleted != null)
            CrumpleOverlay(
              key: ValueKey('crumple-${deleted.id}'),
              face: CurrentTaskScreen(task: deleted, faceOnly: true),
              chrome: (ctaHide) => CurrentTaskScreen(
                // El menú toma el color de la que queda detrás.
                task: deletion.next ?? deleted,
                chromeOnly: true,
                showLogoAndMenu: deletion.next != null,
                ctaHide: ctaHide,
              ),
              onFinished: () => ref.read(deletionProvider.notifier).finish(),
            ),
          if (celebrating && completed != null)
            CelebrationOverlay(
              key: ValueKey('celebration-${completed.id}'),
              face: CurrentTaskScreen(task: completed, faceOnly: true),
              colorKey: completed.colorKey,
              hasNext: completion.hasNext,
              onFadeStart: () =>
                  ref.read(completionProvider.notifier).startFade(),
              onFinished: () => ref.read(completionProvider.notifier).finish(),
            ),
        ],
      ),
    );
  }
}

/// App mínima para un error al abrir el almacenamiento (CL-001-6).
class StorageErrorApp extends StatelessWidget {
  const StorageErrorApp({
    super.key,
    required this.noSpace,
    required this.onRetry,
  });

  final bool noSpace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) => AppIdentity.displayName,
      theme: UnaTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      builder: appFrame,
      home: StorageErrorScreen(noSpace: noSpace, onRetry: onRetry),
    );
  }
}

/// Marco de todas las pantallas: en tablets y plegables el contenido se centra
/// con un ancho máximo (CL-001-7) y en la web de pruebas se añade su aviso
/// (ADR-0010).
Widget appFrame(BuildContext context, Widget? child) {
  final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
  if (l10n != null) registerSemanticsActionOrder(l10n);
  final centered = ColoredBox(
    color: UnaColors.paper,
    child: ValueListenableBuilder<int>(
      valueListenable: fullWidthRequests,
      // El visor va al ancho completo de la pantalla (CA-007-09).
      builder: (context, fullWidth, child) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: fullWidth > 0
                ? double.infinity
                : UnaSizes.contentMaxWidth,
          ),
          child: child,
        ),
      ),
      child: child,
    ),
  );
  // Marca de idioma del contenido: el lector de pantalla usa la voz del
  // idioma de la app (español o inglés) y no la del sistema, también con el
  // texto del usuario (CA-010-10).
  return Semantics(
    localeForSubtree: Localizations.maybeLocaleOf(context),
    child: kIsWeb ? WebPreviewBanner(child: centered) : centered,
  );
}
