import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/all_done/all_done_screen.dart';
import '../features/app_error/storage_error_screen.dart';
import '../features/complete/celebration_overlay.dart';
import '../features/complete/completion_controller.dart';
import '../features/current_task/current_task_screen.dart';
import '../features/delete/crumple_overlay.dart';
import '../features/delete/deletion_controller.dart';
import '../features/editor/task_editor_screen.dart';
import '../features/first_run/welcome_intro.dart';
import '../l10n/generated/app_localizations.dart';
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

  @override
  ConsumerState<UnaApp> createState() => _UnaAppState();
}

class _UnaAppState extends ConsumerState<UnaApp> {
  late final AppLifecycleListener _lifecycle;
  final _navigatorKey = GlobalKey<NavigatorState>();
  DateTime? _hiddenAt;
  int _resetGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt = ref.read(clockProvider).now(),
      onShow: _onShow,
    );
  }

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
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (_) => AppIdentity.displayName,
      theme: UnaTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
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
    final task = ref.watch(currentTaskProvider);
    final firstRunDone = ref.watch(firstRunDoneProvider);
    final hasHistory = ref.watch(hasHistoryProvider);
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
    } else if (hasHistory || crumpling) {
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
    final screen = Semantics(
      key: child.key,
      scopesRoute: true,
      explicitChildNodes: true,
      child: child,
    );
    final screens = AnimatedSwitcher(
      // Al eliminar, la de detrás sustituye a la eliminada sin fundido (se
      // vería detrás de la bola): se monta de nuevo solo en ese momento
      // (CA-004-04).
      key: ValueKey('screens-${deletion.generation}'),
      duration: reduced ? UnaMotion.reducedMotionFade : UnaMotion.introFade,
      // Cada pantalla es una "ruta" para el lector (se anuncia el cambio) y la
      // que sale no se lee durante el fundido.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [
          for (final p in previous) ExcludeSemantics(child: p),
          ?current,
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
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: UnaSizes.contentMaxWidth),
        child: child,
      ),
    ),
  );
  return kIsWeb ? WebPreviewBanner(child: centered) : centered;
}
