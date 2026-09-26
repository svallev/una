import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/storage_errors.dart';
import '../../app/theme/tokens.g.dart';
import '../../app/theme/una_theme.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/delete_pending_task.dart' show TaskNotPending;
import '../../l10n/generated/app_localizations.dart';
import '../../ui/brutal_button.dart';
import '../../ui/square_icon_button.dart';
import '../../ui/una_icons.dart';
import '../delete/delete_confirm_sheet.dart';
import '../editor/task_editor_screen.dart';
import 'move_sheet.dart';
import 'task_list_controller.dart';
import 'task_list_row.dart';

/// Abre "Todas las tareas" (spec 006, CA-006-01) con la cola ya leída, para
/// no pintar una pantalla vacía (CA-006-20).
Future<void> openTaskList(BuildContext context, WidgetRef ref) async {
  final tasks = await ref.read(taskRepositoryProvider).pendingTasks();
  if (!context.mounted) return;
  await Navigator.of(context).push(TaskListScreen.route(tasks));
}

/// Listado de la cola (prototipo, pantalla 5): cabecera, ayuda, filas
/// reordenables y "Nueva tarea".
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, required this.initial});

  /// La cola leída al abrir; se usa hasta que llega la de la BD.
  final List<Task> initial;

  /// Como en el prototipo, el listado aparece y desaparece sin transición.
  static Route<void> route(List<Task> initial) => PageRouteBuilder<void>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => TaskListScreen(initial: initial),
  );

  /// Con la escala de texto a partir de aquí, la cabecera y la ayuda se
  /// desplazan con la lista (DEV-34).
  static const scrollHeaderFromTextScale = 1.3;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

/// Arrastre en curso (modelo del prototipo: `dragStart`/`dragMove`/`dragEnd`).
class _Drag {
  _Drag({
    required this.id,
    required this.from,
    required this.downY,
    required this.startScroll,
    required this.rowTop,
    required this.rowLeft,
    required this.rowWidth,
    required this.tops,
    required this.heights,
    required this.autoScroller,
  }) : pointerY = downY,
       to = from;

  final String id;
  final int from;
  final double downY;
  final double startScroll;

  /// Posición de la fila en el área de la lista al empezar.
  final double rowTop;
  final double rowLeft;
  final double rowWidth;

  /// Posición y alto de cada fila en el orden de partida (contenido de la
  /// lista; las no construidas nunca, con el alto medio).
  final List<double> tops;
  final List<double> heights;
  final EdgeDraggingAutoScroller autoScroller;

  double pointerY;
  int to;
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _scroll = ScrollController();
  final _areaKey = GlobalKey();
  final _newTaskFocus = FocusNode(skipTraversal: true);
  final _heights = <String, double>{};
  final _slotKeys = <String, GlobalKey>{};
  late final AppLifecycleListener _lifecycle;

  _Drag? _drag;

  /// Posición del dedo durante el arrastre: mueve solo la fila levantada, sin
  /// reconstruir la lista en cada movimiento.
  final _pointerY = ValueNotifier<double>(0);

  /// Tras soltar, las filas se colocan sin transición (`.li.still`).
  bool _freeze = false;
  Timer? _freezeTimer;

  /// Doble toque: primera fila tocada y ventana abierta (CA-006-13).
  String? _tapId;
  Timer? _tapTimer;

  /// Última petición de foco ya atendida (CA-006-17).
  int _handledFocus = 0;

  static const _gap = UnaSpace.sm;

  List<Task> get _tasks => ref.read(taskListProvider).tasks ?? widget.initial;

  @override
  void initState() {
    super.initState();
    // Un arrastre interrumpido no guarda nada (CA-006-11).
    _lifecycle = AppLifecycleListener(onHide: _cancelDrag);
  }

  @override
  void dispose() {
    _drag?.autoScroller.stopAutoScroll();
    _lifecycle.dispose();
    _freezeTimer?.cancel();
    _tapTimer?.cancel();
    _scroll.dispose();
    _newTaskFocus.dispose();
    _pointerY.dispose();
    super.dispose();
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  // ---------------------------------------------------------------- anuncios

  /// Un único anuncio (CA-006-17). Si se acaba de cerrar una hoja, se espera
  /// a que baje: el cambio de ventana podría cortarlo.
  void _announce(String message, {bool afterSheet = false}) {
    final view = View.of(context);
    final direction = Directionality.of(context);
    void send() =>
        unawaited(SemanticsService.sendAnnouncement(view, message, direction));
    if (afterSheet) {
      Timer(UnaMotion.sheetOut, send);
    } else {
      send();
    }
  }

  void _showError(String message, VoidCallback retry) {
    final l10n = AppLocalizations.of(context);
    // El aviso (SnackBar) ya se anuncia solo: no se duplica.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: l10n.retry,
          onPressed: () {
            if (mounted) retry();
          },
        ),
        persist: true,
      ),
    );
  }

  // ------------------------------------------------------------ desplazar

  /// Lleva la fila [id] a la vista. En la cola solo hace falta ir arriba del
  /// todo, abajo del todo o a una fila que ya está cerca (plan §7).
  Future<void> _reveal(String id) async {
    if (!_scroll.hasClients) return;
    final tasks = _tasks;
    final index = tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final reduced = _reduced;
    Future<void> go(double offset) => reduced
        ? Future.sync(() => _scroll.jumpTo(offset))
        : _scroll.animateTo(
            offset,
            duration: UnaMotion.enter,
            curve: UnaMotion.standardCurve,
          );
    final ctx = _slotKeys[id]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: reduced ? Duration.zero : UnaMotion.enter,
        curve: UnaMotion.standardCurve,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      if (!mounted || !ctx.mounted) return;
      await Scrollable.ensureVisible(
        ctx,
        duration: reduced ? Duration.zero : UnaMotion.enter,
        curve: UnaMotion.standardCurve,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
      return;
    }
    if (index == 0) return go(0);
    // Abajo del todo: la lista es perezosa y el final se conoce al llegar.
    await go(_scroll.position.maxScrollExtent);
    for (var i = 0; i < 4 && mounted && _scroll.hasClients; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!_scroll.hasClients) return;
      final max = _scroll.position.maxScrollExtent;
      if ((_scroll.offset - max).abs() < 1) break;
      _scroll.jumpTo(max);
    }
  }

  // ---------------------------------------------------------------- mover

  /// Mueve [task] a [to] (0 = actual) por cualquier vía: arrastre, "Mover" o
  /// acción del lector (CA-006-04/08/16).
  Future<void> _move(Task task, int to, {bool afterSheet = false}) async {
    final l10n = AppLocalizations.of(context);
    // Arriba del todo: la lista sube en el mismo fotograma en que cambia el
    // orden, para que la fila se reutilice (misma fila para el lector) en
    // lugar de destruirse fuera de la pantalla: TalkBack no perderá el foco.
    if (to == 0 && _scroll.hasClients && _scroll.offset > 0) {
      _scroll.jumpTo(0);
    }
    final outcome = await ref
        .read(taskListProvider.notifier)
        .move(_tasks, task.id, to);
    if (!mounted) return;
    switch (outcome) {
      case Moved(:final position, :final total):
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        ref.read(taskListProvider.notifier).focus(task.id);
        _announce(
          position == 1
              ? l10n.a11yNowCurrent
              : l10n.a11yMovedTo(position, total),
          afterSheet: afterSheet,
        );
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) await _reveal(task.id);
      case NotMoved():
        break;
      case MoveFailed(:final error):
        _showError(
          isNoSpaceError(error) ? l10n.storageErrorNoSpace : l10n.listMoveError,
          () => _move(task, to),
        );
    }
  }

  Future<void> _openMove(Task task) async {
    final tasks = _tasks;
    final position = tasks.indexWhere((t) => t.id == task.id) + 1;
    if (position < 2) return;
    final choice = await showMoveSheet(
      context,
      position: position,
      total: tasks.length,
    );
    if (!mounted) return;
    if (choice == null) {
      ref.read(taskListProvider.notifier).focus(task.id);
      return;
    }
    await _move(task, moveTargetIndex(choice, position), afterSheet: true);
  }

  // -------------------------------------------------------------- arrastre

  void _dragStart(Task task, BuildContext rowContext, Offset global) {
    if (_drag != null) return;
    final tasks = _tasks;
    final from = tasks.indexWhere((t) => t.id == task.id);
    final area = _areaKey.currentContext?.findRenderObject() as RenderBox?;
    final row = rowContext.findRenderObject() as RenderBox?;
    if (from < 1 || area == null || row == null || !_scroll.hasClients) return;
    _tapId = null; // Un toque seguido de arrastre no edita (CL-006-7).
    final known = _heights.values;
    final average = known.isEmpty
        ? row.size.height
        : known.reduce((a, b) => a + b) / known.length;
    final heights = [for (final t in tasks) _heights[t.id] ?? average];
    final tops = <double>[];
    var y = 0.0;
    for (final h in heights) {
      tops.add(y);
      y += h + _gap;
    }
    final origin = row.localToGlobal(Offset.zero, ancestor: area);
    final scrollable = Scrollable.of(rowContext);
    _pointerY.value = global.dy;
    setState(() {
      _drag = _Drag(
        id: task.id,
        from: from,
        downY: global.dy,
        startScroll: _scroll.offset,
        rowTop: origin.dy,
        rowLeft: origin.dx,
        rowWidth: row.size.width,
        tops: tops,
        heights: heights,
        autoScroller: EdgeDraggingAutoScroller(
          scrollable,
          onScrollViewScrolled: _onAutoScrolled,
          velocityScalar: _autoScrollVelocity,
        ),
      );
    });
  }

  /// Velocidad del desplazamiento automático (la de `SliverReorderableList`).
  static const _autoScrollVelocity = 50.0;

  void _dragUpdate(Offset global) {
    final d = _drag;
    if (d == null) return;
    d.pointerY = global.dy;
    _pointerY.value = global.dy;
    _retarget();
    d.autoScroller.startAutoScrollIfNecessary(_liftedGlobalRect());
  }

  void _onAutoScrolled() {
    final d = _drag;
    if (d == null) return;
    _retarget();
    d.autoScroller.startAutoScrollIfNecessary(_liftedGlobalRect());
  }

  /// Destino: cuántas filas quedan por encima del centro de la arrastrada
  /// (prototipo, `dragMove`).
  void _retarget() {
    final d = _drag!;
    final dy = d.pointerY - d.downY + (_scroll.offset - d.startScroll);
    final center = d.tops[d.from] + d.heights[d.from] / 2 + dy;
    var to = 0;
    for (var i = 0; i < d.tops.length; i++) {
      if (i != d.from && d.tops[i] + d.heights[i] / 2 < center) to++;
    }
    // Las demás filas solo se recolocan cuando cambia el destino.
    if (to != d.to) setState(() => d.to = to);
  }

  double get _liftedTop {
    final d = _drag!;
    return d.rowTop + d.pointerY - d.downY;
  }

  Rect _liftedGlobalRect() {
    final d = _drag!;
    final area = _areaKey.currentContext!.findRenderObject()! as RenderBox;
    final topLeft = area.localToGlobal(Offset(d.rowLeft, _liftedTop));
    return topLeft & Size(d.rowWidth, d.heights[d.from]);
  }

  void _dragEnd() {
    final d = _drag;
    if (d == null) return;
    d.autoScroller.stopAutoScroll();
    final task = _tasks.firstWhere((t) => t.id == d.id);
    setState(() {
      _drag = null;
      _freeze = true;
    });
    _freezeTimer?.cancel();
    _freezeTimer = Timer(UnaMotion.listDropFreeze, () {
      if (mounted) setState(() => _freeze = false);
    });
    if (d.to != d.from) unawaited(_move(task, d.to));
  }

  void _cancelDrag() {
    final d = _drag;
    if (d == null) return;
    d.autoScroller.stopAutoScroll();
    setState(() => _drag = null);
  }

  /// Desplazamiento de la fila [index] para hacer hueco a la arrastrada.
  double _shiftOf(int index) {
    final d = _drag;
    if (d == null || index == d.from) return 0;
    final shift = d.heights[d.from] + _gap;
    if (d.from < d.to && index > d.from && index <= d.to) return -shift;
    if (d.from > d.to && index >= d.to && index < d.from) return shift;
    return 0;
  }

  // ------------------------------------------------ editar, eliminar, crear

  void _rowTap(Task task) {
    if (_drag != null) return;
    if (_tapId == task.id && (_tapTimer?.isActive ?? false)) {
      _tapTimer?.cancel();
      _tapId = null;
      unawaited(_edit(task));
      return;
    }
    _tapId = task.id;
    _tapTimer?.cancel();
    _tapTimer = Timer(UnaMotion.doubleTapWindow, () => _tapId = null);
  }

  /// Editor de la spec 005; al volver, el foco en la fila (CA-006-13).
  Future<void> _edit(Task task) async {
    if (_drag != null) return;
    await Navigator.of(context).push(
      TaskEditorScreen.route(
        context,
        TaskEditorScreen(mode: EditorMode.edit, task: task, fromList: true),
      ),
    );
    if (mounted) ref.read(taskListProvider.notifier).focus(task.id);
  }

  Future<void> _delete(Task task) async {
    if (_drag != null) return;
    final confirmed = await showDeleteConfirmSheet(
      context,
      label: task.text ?? '',
      ignoreEarlyTaps: true,
    );
    if (!mounted) return;
    if (confirmed != true) {
      ref.read(taskListProvider.notifier).focus(task.id);
      return;
    }
    await _deleteConfirmed(task);
  }

  /// Sin arrugado (CA-006-14): la fila desaparece y las de debajo suben.
  Future<void> _deleteConfirmed(Task task) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final before = _tasks;
    final index = before.indexWhere((t) => t.id == task.id);
    try {
      final result = await ref.read(taskListProvider.notifier).delete(task.id);
      if (!mounted) return;
      messenger?.hideCurrentSnackBar();
      if (result.remaining == 0) {
        // "Todo hecho." y el listado deja de existir (CL-006-3).
        ref.read(hasHistoryProvider.notifier).mark();
        _announce(l10n.a11yDeletedAllDone, afterSheet: true);
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      final rest = [
        for (final t in before)
          if (t.id != task.id) t,
      ];
      final target = rest[math.min(math.max(index, 0), rest.length - 1)];
      ref.read(taskListProvider.notifier).focus(target.id);
      final next = result.next;
      _announce(
        result.wasCurrent && next != null
            ? l10n.a11yDeletedNext(next.text ?? '')
            : l10n.a11yDeletedFromList(result.remaining),
        afterSheet: true,
      );
    } on TaskNotPending {
      messenger?.hideCurrentSnackBar();
    } on Object catch (e) {
      if (!mounted) return;
      _showError(
        isNoSpaceError(e) ? l10n.storageErrorNoSpace : l10n.deleteError,
        () => _deleteConfirmed(task),
      );
    }
  }

  /// Editor de la spec 002; al colocarla se vuelve aquí con la tarea
  /// resaltada, a la vista y con el foco (CA-006-15, DEV-30).
  Future<void> _create() async {
    if (_drag != null) return;
    final l10n = AppLocalizations.of(context);
    final current = _tasks.firstOrNull;
    final saved = await Navigator.of(context).push(
      TaskEditorScreen.route(
        context,
        TaskEditorScreen(
          mode: EditorMode.create,
          // Distinto del de la tarea actual (CA-001-08).
          colorKey: ref
              .read(colorPickerProvider)
              .pick(currentColorKey: current?.colorKey),
          fromList: true,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == null) {
      _requestFocus(_newTaskFocus);
      return;
    }
    final tasks = await ref.read(taskRepositoryProvider).pendingTasks();
    if (!mounted) return;
    final index = tasks.indexWhere((t) => t.id == saved.id);
    if (index < 0) return;
    ref.read(taskListProvider.notifier).flashAndFocus(saved.id);
    _announce(
      index == 0
          ? l10n.a11yNowCurrent
          : l10n.a11yAddedAt(index + 1, tasks.length),
      afterSheet: true,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) await _reveal(saved.id);
  }

  void _requestFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      node.requestFocus();
      node.context?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  // ----------------------------------------------------------------- vista

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskListProvider);
    final tasks = state.tasks ?? widget.initial;
    final reduced = _reduced;
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    final scrollHeader =
        MediaQuery.textScalerOf(context).scale(1) >=
        TaskListScreen.scrollHeaderFromTextScale;
    final drag = _drag;

    final header = _Header(
      title: l10n.listTitle,
      backLabel: l10n.listBack,
      help: screenReader ? l10n.listHelpScreenReader : l10n.listHelp,
      onBack: () => Navigator.of(context).maybePop(),
    );

    Widget rowFor(int index) {
      final task = tasks[index];
      final first = index == 0;
      final position = index + 1;
      final total = tasks.length;
      final actions = <CustomSemanticsAction, VoidCallback>{
        for (final c in moveChoicesFor(position, total))
          CustomSemanticsAction(label: moveChoiceLabel(l10n, c)): () =>
              _move(task, moveTargetIndex(c, position)),
        CustomSemanticsAction(label: l10n.listEdit): () => _edit(task),
        CustomSemanticsAction(label: l10n.deleteA11yAction): () =>
            _delete(task),
      };
      final lifted = drag?.id == task.id;
      final slot = _RowSlot(
        key: _slotKeys.putIfAbsent(task.id, GlobalKey.new),
        lifted: lifted,
        reduced: reduced,
        focusSerial: state.focus.id == task.id ? state.focus.serial : null,
        handledFocus: _handledFocus,
        onFocusHandled: (s) => _handledFocus = s,
        flashSerial: state.flash.id == task.id ? state.flash.serial : null,
        onSize: (h) => _heights[task.id] = h,
        builder: (shadow) => TaskListRow(
          task: task,
          first: first,
          palette: UnaPalettes.classic,
          semanticsLabel: first
              ? l10n.a11yRowCurrent(total, task.text ?? '')
              : l10n.a11yRowPosition(position, total, task.text ?? ''),
          editHint: l10n.listEditHint,
          actions: actions,
          onEdit: () => _edit(task),
          onDelete: () => _delete(task),
          onMove: first ? null : () => _openMove(task),
          onRowTap: () => _rowTap(task),
          drag: first
              ? null
              : RowDragCallbacks(
                  onStart: (ctx, g) => _dragStart(task, ctx, g),
                  onUpdate: _dragUpdate,
                  onEnd: _dragEnd,
                  onCancel: _cancelDrag,
                ),
          shadow: shadow,
          reduced: reduced,
        ),
      );
      return KeyedSubtree(
        key: ValueKey(task.id),
        child: Padding(
          padding: EdgeInsets.only(bottom: index == total - 1 ? 0 : _gap),
          child: _Shift(
            offset: _shiftOf(index),
            // Al soltar, sin transición (`.still`); al cancelar, las demás
            // vuelven a su sitio con la misma transición.
            duration: _freeze || reduced ? Duration.zero : UnaMotion.listShift,
            child: slot,
          ),
        ),
      );
    }

    final list = CustomScrollView(
      controller: _scroll,
      semanticChildCount: tasks.length,
      slivers: [
        if (scrollHeader) SliverToBoxAdapter(child: header),
        SliverPadding(
          // Prototipo: `padding: 4px 24px 20px 20px`.
          padding: const EdgeInsets.fromLTRB(
            UnaSpace.ml,
            UnaSpace.xs,
            UnaSpace.l,
            UnaSpace.ml,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => rowFor(index),
              childCount: tasks.length,
              findChildIndexCallback: (key) {
                final id = (key as ValueKey<String>).value;
                final i = tasks.indexWhere((t) => t.id == id);
                return i < 0 ? null : i;
              },
            ),
          ),
        ),
      ],
    );

    final area = Stack(
      key: _areaKey,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(child: list),
        if (drag != null)
          Positioned.fill(
            child: ValueListenableBuilder<double>(
              valueListenable: _pointerY,
              builder: (context, pointerY, child) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: drag.rowLeft,
                    top: drag.rowTop + pointerY - drag.downY,
                    width: drag.rowWidth,
                    child: child!,
                  ),
                ],
              ),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _LiftShadow(
                    reduced: reduced,
                    builder: (shadow) => TaskListRow(
                      task: tasks.firstWhere(
                        (t) => t.id == drag.id,
                        orElse: () => tasks[drag.from],
                      ),
                      first: false,
                      palette: UnaPalettes.classic,
                      lifted: true,
                      reduced: reduced,
                      shadow: shadow,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return PopScope(
      // Al volver (botón, gesto atrás o tras eliminar la última), el foco va
      // a la tarea actual o a "Todo hecho." (CA-006-03, CA-006-17).
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(screenFocusProvider.notifier).signal();
      },
      child: Scaffold(
        backgroundColor: UnaColors.paper,
        body: SafeArea(
          bottom: false,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: l10n.listTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!scrollHeader) header,
                Expanded(
                  child: Semantics(
                    sortKey: const OrdinalSortKey(_Order.list),
                    child: area,
                  ),
                ),
                _Bottom(
                  label: l10n.listNewTask,
                  focusNode: _newTaskFocus,
                  onPressed: _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Orden de lectura (CA-006-18): título, ayuda, filas, "Nueva tarea",
/// "Volver". El título va primero: TalkBack enfoca el primer elemento de la
/// pantalla (lección de la spec 004).
abstract final class _Order {
  static const title = 0.0;
  static const help = 1.0;
  static const list = 2.0;
  static const newTask = 3.0;
  static const back = 4.0;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.backLabel,
    required this.help,
    required this.onBack,
  });

  final String title;
  final String backLabel;
  final String help;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Prototipo: alto 68, `padding: 12px 20px 0`, separación 14.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UnaSpace.ml - 1,
            UnaSpace.sm,
            UnaSpace.ml,
            0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: UnaSizes.listHeader - UnaSpace.sm,
            ),
            child: Row(
              children: [
                Semantics(
                  sortKey: const OrdinalSortKey(_Order.back),
                  child: SquareIconButton(
                    icon: UnaIcons.arrowLeft,
                    label: backLabel,
                    fill: UnaColors.paper,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: UnaSpace.sm - 1),
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    sortKey: const OrdinalSortKey(_Order.title),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: UnaFonts.display,
                        fontSize: UnaFontSizes.title,
                        fontWeight: UnaFontWeights.extrabold,
                        letterSpacing:
                            UnaLetterSpacing.tighter * UnaFontSizes.title,
                        color: UnaColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Prototipo: `padding: 14px 24px 18px`, Space Mono 13, interlineado 1,5.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            UnaSpace.l,
            UnaSpace.sm + 2,
            UnaSpace.l,
            UnaSpace.m + 2,
          ),
          child: Semantics(
            container: true,
            sortKey: const OrdinalSortKey(_Order.help),
            child: Text(
              help,
              style: UnaTheme.mono.copyWith(color: UnaColors.ink, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra inferior con "Nueva tarea" (`padding: 16px 24px 38px`, borde superior
/// de 3 px).
class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.label,
    required this.focusNode,
    required this.onPressed,
  });

  final String label;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      sortKey: const OrdinalSortKey(_Order.newTask),
      child: Container(
        decoration: const BoxDecoration(
          color: UnaColors.paper,
          border: Border(
            top: BorderSide(
              color: UnaColors.ink,
              width: UnaBorders.strongWidth,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          UnaSpace.l,
          UnaSpace.m,
          UnaSpace.l,
          math.max(UnaSpace.xxl - 2, bottomInset + UnaSpace.m),
        ),
        child: Focus(
          focusNode: focusNode,
          child: BrutalButton(
            label: label,
            icon: UnaIcons.plus,
            iconSize: UnaSizes.icon,
            iconStroke: UnaSizes.iconStroke,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

/// Desplaza una fila para hacer hueco (`.li{transition:transform .2s ease}`).
class _Shift extends StatelessWidget {
  const _Shift({
    required this.offset,
    required this.duration,
    required this.child,
  });

  final double offset;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: offset),
    duration: duration,
    curve: UnaMotion.easeCurve,
    builder: (_, dy, child) =>
        Transform.translate(offset: Offset(0, dy), child: child),
    child: child,
  );
}

/// Hueco de una fila en la lista: mide su alto, recibe el foco cuando se
/// pide, se resalta al crearla y, mientras se arrastra, se queda invisible
/// (y viva, aunque salga de la pantalla) en su sitio de partida.
class _RowSlot extends StatefulWidget {
  const _RowSlot({
    super.key,
    required this.lifted,
    required this.reduced,
    required this.focusSerial,
    required this.handledFocus,
    required this.onFocusHandled,
    required this.flashSerial,
    required this.onSize,
    required this.builder,
  });

  final bool lifted;
  final bool reduced;
  final int? focusSerial;
  final int handledFocus;
  final ValueChanged<int> onFocusHandled;
  final int? flashSerial;
  final ValueChanged<double> onSize;
  final Widget Function(BoxShadow shadow) builder;

  @override
  State<_RowSlot> createState() => _RowSlotState();
}

class _RowSlotState extends State<_RowSlot>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  // Fuera del recorrido con Tab: solo recibe el foco cuando se pide.
  final _focus = FocusNode(skipTraversal: true);
  // `preserve`: con "quitar animaciones" Flutter acorta las animaciones 20
  // veces, y el resaltado fijo debe durar 0,9 s (CA-006-19).
  late final _flash = AnimationController(
    vsync: this,
    duration: UnaMotion.listFlash,
    animationBehavior: AnimationBehavior.preserve,
  );
  int? _flashedSerial;

  @override
  bool get wantKeepAlive => widget.lifted;

  @override
  void initState() {
    super.initState();
    _maybeFocus();
    _maybeFlash();
  }

  @override
  void didUpdateWidget(_RowSlot old) {
    super.didUpdateWidget(old);
    if (old.lifted != widget.lifted) updateKeepAlive();
    _maybeFocus();
    _maybeFlash();
  }

  void _maybeFocus() {
    final serial = widget.focusSerial;
    if (serial == null || serial <= widget.handledFocus) return;
    widget.onFocusHandled(serial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      context.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  void _maybeFlash() {
    final serial = widget.flashSerial;
    if (serial == null || serial == _flashedSerial) return;
    _flashedSerial = serial;
    unawaited(_flash.forward(from: 0));
  }

  @override
  void dispose() {
    _focus.dispose();
    _flash.dispose();
    super.dispose();
  }

  /// `@keyframes flash{0%,40%{9px}100%{4px}}`; con reducir movimiento, la
  /// sombra grande fija durante 0,9 s (CA-006-19).
  BoxShadow _shadowAt(double t) {
    if (!_flash.isAnimating) return UnaShadows.listItem;
    if (widget.reduced || t <= 0.4) return UnaShadows.listItemFlash;
    final k = UnaMotion.easeCurve.transform((t - 0.4) / 0.6);
    return BoxShadow.lerp(UnaShadows.listItemFlash, UnaShadows.listItem, k)!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Widget row = AnimatedBuilder(
      animation: _flash,
      builder: (context, _) => widget.builder(_shadowAt(_flash.value)),
    );
    row = _MeasureHeight(onHeight: widget.onSize, child: row);
    // Invisible en su sitio mientras se arrastra; el lector la sigue teniendo
    // (TalkBack también arrastra con doble toque mantenido). Siempre con el
    // mismo envoltorio: si cambiara, se perdería el gesto en curso.
    row = Opacity(
      opacity: widget.lifted ? 0 : 1,
      alwaysIncludeSemantics: true,
      child: row,
    );
    return Focus(focusNode: _focus, child: row);
  }
}

/// Sombra de la fila levantada: crece en 0,15 s (`.li.dragging`), o de golpe
/// con reducir movimiento.
class _LiftShadow extends StatelessWidget {
  const _LiftShadow({required this.reduced, required this.builder});

  final bool reduced;
  final Widget Function(BoxShadow shadow) builder;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: reduced ? 1 : 0, end: 1),
    duration: reduced ? Duration.zero : UnaMotion.listLift,
    curve: UnaMotion.easeCurve,
    builder: (_, t, _) => builder(
      BoxShadow.lerp(UnaShadows.listItem, UnaShadows.listItemDragging, t)!,
    ),
  );
}

/// Informa del alto de su hijo tras cada maquetación (para calcular el
/// destino del arrastre con filas de alto variable).
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onHeight);

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
