import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_error/storage_error_screen.dart';
import '../features/current_task/current_task_screen.dart';
import '../features/editor/task_editor_screen.dart';
import '../features/first_run/welcome_intro.dart';
import '../l10n/generated/app_localizations.dart';
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

/// Decide qué se ve (CA-001-03/05/09): tarea actual; si no hay, la bienvenida
/// (solo la primera vez) o el editor de la primera tarea.
class HomeRouter extends ConsumerWidget {
  const HomeRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentTaskProvider);
    final firstRunDone = ref.watch(firstRunDoneProvider);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final Widget child;
    if (task != null) {
      child = CurrentTaskScreen(key: ValueKey('task-${task.id}'), task: task);
    } else if (!firstRunDone) {
      child = WelcomeIntro(
        key: const ValueKey('intro'),
        onShown: () => ref.read(firstRunDoneProvider.notifier).persistSeen(),
        onDone: () => ref.read(firstRunDoneProvider.notifier).markDone(),
      );
    } else {
      child = const FirstTaskEditorScreen(key: ValueKey('first-editor'));
    }
    return AnimatedSwitcher(
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
      child: Semantics(
        key: child.key,
        scopesRoute: true,
        explicitChildNodes: true,
        child: child,
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
