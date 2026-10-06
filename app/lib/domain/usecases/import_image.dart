import 'dart:async';

import '../entities/attachment.dart';
import '../entities/image_type.dart';
import '../ports/attachment_store.dart';
import '../ports/clock.dart';
import '../ports/id_generator.dart';
import '../ports/image_importer.dart';
import '../services/attachment_janitor.dart';
import '../services/import_budget.dart';

/// Importa una foto de la cámara o una imagen de la galería (spec 007) en dos
/// pasos: [pick] abre el sistema y, si el usuario elige algo, devuelve un
/// [ImportJob] que la copia y la limpia.
///
/// La preparación queda protegida del barrido (CA-007-16) desde que se abre la
/// cámara hasta que la tarea se guarda (`CreateTask`/`EditTask` la liberan) o
/// se descarta.
class ImportImage {
  ImportImage({
    required this.importer,
    required this.janitor,
    required this.ids,
    this.clock = const SystemClock(),
    this.periodic,
    this.settleTimeout = defaultSettleTimeout,
  });

  /// Lo máximo que espera un grupo a que la llamada nativa de una foto acabe
  /// tras agotarse su tiempo o cancelarse, antes de empezar la siguiente
  /// (`cancelTimeout` + 1 s, CA-016-04).
  static const defaultSettleTimeout = Duration(seconds: 3);
  final Duration settleTimeout;

  final ImageImporter importer;
  final AttachmentJanitor janitor;
  final IdGenerator ids;

  /// Reloj y temporizador del [ImportBudget] (se inyectan en los tests).
  final Clock clock;
  final PeriodicTimerFactory? periodic;

  /// Un presupuesto nuevo: 20 s por foto y 2 minutos en total (CA-007-14,
  /// CA-016-04). Una foto suelta usa uno propio; un grupo, uno para todas.
  ImportBudget newBudget() => ImportBudget(clock: clock, periodic: periodic);

  /// Devuelve null si el usuario cancela la cámara o el selector. Lanza
  /// [ImageImportFailure] (`noCamera`).
  Future<ImportJob?> pick(AttachmentOrigin origin) async {
    final id = ids.newId();
    janitor.registry.add(id);
    try {
      final picked = await importer.pick(origin, id);
      if (picked == null) {
        await janitor.discardStaging(id);
        return null;
      }
      return ImportJob._(this, id, picked);
    } on Object {
      await janitor.discardStaging(id);
      rethrow;
    }
  }

  /// Abre el selector múltiple (spec 016, CA-016-02) y devuelve el grupo de lo
  /// elegido, **como mucho 10** (el resto ni se abre ni se toca), o null si el
  /// usuario cancela. Un id por foto, todos registrados **al volver el
  /// selector** (antes de copiar nada: el barrido no los toca). Si el selector
  /// falla, no queda nada registrado.
  Future<ImportGroup?> pickMany() async {
    final picked = await importer.pickMany(max: ImageLimits.maxGroup);
    if (picked == null) return null;
    final items = picked.items.take(ImageLimits.maxGroup).toList();
    if (items.isEmpty) return null;
    final groupIds = [for (final _ in items) ids.newId()];
    groupIds.forEach(janitor.registry.add);
    return ImportGroup._(
      this,
      groupIds,
      items,
      limited:
          picked.total > ImageLimits.maxGroup ||
          picked.items.length > ImageLimits.maxGroup,
    );
  }
}

/// En qué punto está la preparación de un grupo (CA-016-04). Un solo estado:
/// tras `cancelled` o `expired` no se empieza ninguna foto más, en ningún
/// momento.
enum GroupState { running, cancelled, expired }

/// Lo que sale de preparar un grupo.
class GroupResult {
  const GroupResult({
    required this.staged,
    required this.failed,
    required this.limited,
  });

  /// Las fotos preparadas, **en su orden**.
  final List<StagedImage> staged;

  /// Por qué falló cada foto omitida: **solo el código**, nunca el texto de
  /// una excepción (CL-016-16).
  final List<ImageImportError> failed;

  /// El sistema devolvió más de 10 y se usaron las 10 primeras.
  final bool limited;
}

/// Un grupo de imágenes elegidas con el selector múltiple (spec 016): una
/// secuencia de importaciones de **una** foto ([ImportJob]) bajo un único
/// [ImportBudget] y un único [state].
///
/// Tiene **una única salida**: o las preparadas pasan al editor
/// (`prepareAll` con éxito: suelta del registro todo id que no esté en
/// `staged`) o se descarta todo (cancelar, cerrar el editor, `noSpace`, fallan
/// todas, un error inesperado): nada queda registrado ni en la zona temporal.
class ImportGroup {
  ImportGroup._(this._owner, this._ids, this._items, {required this.limited});

  final ImportImage _owner;
  final List<String> _ids;
  final List<PickedImage> _items;

  /// El sistema devolvió más de [ImageLimits.maxGroup] (CA-016-02).
  final bool limited;

  var _state = GroupState.running;
  var _started = false;
  var _handedOver = false;
  Future<void>? _exiting;
  ImportJob? _current;
  final _staged = <StagedImage>[];
  final _cancelSignal = Completer<void>();

  /// Cuántas fotos hay en el grupo (de 1 a 10).
  int get length => _items.length;

  GroupState get state => _state;

  /// Prepara las fotos **una tras otra**: copia → tipo por contenido →
  /// limpieza, con el original borrado antes de empezar la siguiente.
  /// [onProgress] recibe `(i, n)` al empezar cada foto, con `i` desde 1.
  ///
  /// Una foto que falla se omite y se anota su código; **`noSpace` detiene
  /// todo y lo descarta todo**; si el total (2 min) vence, se conservan las
  /// preparadas y las que no llegaron cuentan como fallidas; si fallan todas,
  /// lanza el [ImageImportFailure] de la primera; si se cancela, lanza
  /// [ImageImportCancelled] y no queda nada.
  ///
  /// Con 2 o más fotos, antes de empezar se exige espacio libre: 30 MB + 10
  /// fotos guardadas + lo que ya ocupa el grupo que se reemplaza
  /// ([reservedBytes] de lo guardado y lo preparado en [replacedStagedIds]).
  /// Con una sola es el camino de la 007 (sin esa comprobación).
  Future<GroupResult> prepareAll({
    void Function(int index, int total)? onProgress,
    int reservedBytes = 0,
    Iterable<String> replacedStagedIds = const [],
  }) async {
    if (_started) throw StateError('prepareAll can only run once');
    _started = true;
    try {
      return await _prepare(onProgress, reservedBytes, replacedStagedIds);
    } finally {
      if (_handedOver) {
        await _releaseUnstaged();
      } else {
        // Que la llamada nativa de la foto en curso acabe (o 3 s) antes de
        // borrar lo suyo: lo que escriba después lo recoge el barrido.
        await _settle(_current);
        await _exit();
      }
    }
  }

  /// El usuario pulsa «Cancelar» (o se cierra el editor): descarta todo el
  /// grupo, también lo ya preparado, y no se empieza ninguna foto más. Si las
  /// preparadas ya son del editor, no hace nada.
  Future<void> cancel() async {
    if (_handedOver) return;
    _state = GroupState.cancelled;
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
    final job = _current;
    if (job != null) {
      await job.cancel();
      await _settle(job);
    }
    await _exit();
  }

  /// El editor se cierra con el grupo a medias: igual que [cancel].
  Future<void> dispose() => cancel();

  Future<GroupResult> _prepare(
    void Function(int, int)? onProgress,
    int reservedBytes,
    Iterable<String> replacedStagedIds,
  ) async {
    _checkNotCancelled();
    final total = _items.length;
    if (total >= 2) await _checkSpace(reservedBytes, replacedStagedIds);
    _checkNotCancelled();

    final budget = _owner.newBudget();
    final failed = <ImageImportError>[];
    for (var i = 0; i < total; i++) {
      if (_state == GroupState.running && budget.totalExpired) {
        _state = GroupState.expired;
      }
      _checkNotCancelled();
      if (_state == GroupState.expired) {
        // Las que no llegaron cuentan como fallidas (CA-016-04).
        failed.add(ImageImportError.unreadable);
        continue;
      }
      onProgress?.call(i + 1, total);
      _checkNotCancelled(); // el aviso de avance también puede cancelar

      final job = _current = ImportJob._(_owner, _ids[i], _items[i]);
      try {
        _staged.add(
          await Future.any<StagedImage>([
            job.prepare(budget: budget),
            _cancelSignal.future.then<StagedImage>(
              (_) => throw const ImageImportCancelled(),
            ),
          ]),
        );
        _checkNotCancelled();
      } on ImageImportFailure catch (failure) {
        // Sin espacio no es el fallo de una foto: se detiene todo.
        if (failure.error == ImageImportError.noSpace) rethrow;
        failed.add(failure.error);
      } on ImageImportCancelled {
        _checkNotCancelled();
        failed.add(ImageImportError.unreadable);
      }
      // Nunca dos fotos a la vez: la llamada nativa de esta ha de terminar
      // (o pasar 3 s) antes de la siguiente.
      await _settle(job);
    }

    _checkNotCancelled();
    if (_staged.isEmpty) throw ImageImportFailure(failed.first);
    _handedOver = true;
    return GroupResult(
      staged: List.unmodifiable(_staged),
      failed: List.unmodifiable(failed),
      limited: limited,
    );
  }

  void _checkNotCancelled() {
    if (_state == GroupState.cancelled) throw const ImageImportCancelled();
  }

  /// Hace falta el de un original (30 MB) más 10 fotos guardadas, sumando el
  /// grupo que se reemplaza: los dos conviven hasta guardar (CA-016-04). Si el
  /// espacio no se puede medir, no bloquea (CL-016-6).
  Future<void> _checkSpace(
    int reservedBytes,
    Iterable<String> replacedStagedIds,
  ) async {
    int? free;
    try {
      free = await _owner.importer.freeSpace();
    } on Object {
      return;
    }
    if (free == null) return;
    var reserved = reservedBytes;
    for (final id in replacedStagedIds) {
      reserved += await stagedSizeOrEstimate(_owner.janitor.store, id);
    }
    final needed =
        ImageLimits.maxBytes +
        ImageLimits.maxGroup * ImageLimits.storedPhotoEstimate +
        reserved;
    if (free < needed) {
      throw const ImageImportFailure(ImageImportError.noSpace);
    }
  }

  /// Espera a que acabe la llamada nativa de [job], como mucho
  /// [ImportImage.settleTimeout].
  Future<void> _settle(ImportJob? job) async {
    if (job == null) return;
    await job.settled.timeout(_owner.settleTimeout, onTimeout: () {});
  }

  /// Salida sin éxito: descarta **todas** las preparaciones y las suelta del
  /// registro. Idempotente.
  Future<void> _exit() => _exiting ??= () async {
    for (final id in _ids) {
      await _owner.janitor.discardStaging(id);
    }
  }();

  /// Salida con éxito: las preparadas siguen protegidas hasta que se guarden;
  /// el resto (fallidas, las que no llegaron) se suelta.
  Future<void> _releaseUnstaged() => _exiting ??= () async {
    final kept = {for (final s in _staged) s.id};
    for (final id in _ids) {
      if (!kept.contains(id)) await _owner.janitor.discardStaging(id);
    }
  }();
}

/// Una imagen elegida que se está preparando.
class ImportJob {
  ImportJob._(this._owner, this.id, this.picked);

  final ImportImage _owner;
  final String id;
  final PickedImage picked;
  var _cancelled = false;
  Future<void>? _native;

  /// Se completa cuando la llamada nativa de [prepare] ha terminado (sola o
  /// tras cancelarla); nunca falla. Un grupo no empieza otra foto antes.
  Future<void> get settled => _native ?? Future<void>.value();

  AttachmentOrigin get origin => picked.origin;

  /// Copia, decide el tipo **por el contenido** y limpia (CA-007-07/13/14),
  /// con 20 s como máximo de tiempo activo ([ImportBudget]; el del grupo, si se
  /// da [budget]). Si falla o se cancela, no queda nada: lanza
  /// [ImageImportFailure] o [ImageImportCancelled].
  ///
  /// **Nunca deja salir el texto de otra excepción** (ruta, nombre, URI):
  /// cualquier fallo inesperado es `unreadable` (CL-016-16).
  Future<StagedImage> prepare({ImportBudget? budget}) async {
    final importer = _owner.importer;
    try {
      return await (budget ?? _owner.newBudget()).runPhoto(
        () {
          final work = _run(importer);
          _native = work.then<void>((_) {}, onError: (Object _) {});
          return work;
        },
        onExpired: (_) {
          _cancelled = true;
          // No se espera: si la copia está colgada, el aviso sale igual.
          unawaited(_cancelNative(importer));
          throw const ImageImportFailure(ImageImportError.unreadable);
        },
      );
    } on ImageImportFailure {
      await _owner.janitor.discardStaging(id);
      rethrow;
    } on ImageImportCancelled {
      await _owner.janitor.discardStaging(id);
      rethrow;
    } on Object {
      await _owner.janitor.discardStaging(id);
      throw const ImageImportFailure(ImageImportError.unreadable);
    }
  }

  Future<StagedImage> _run(ImageImporter importer) async {
    final copied = await importer.copy(
      picked,
      id,
      maxBytes: ImageLimits.maxBytes,
    );
    _checkCancelled();
    final type = sniffImageType(
      copied.head,
      heicSupported: importer.heicSupported,
    );
    if (type == null) {
      throw const ImageImportFailure(ImageImportError.unsupportedType);
    }
    final staged = await importer.sanitize(
      id,
      type,
      picked.origin,
      maxPixels: ImageLimits.maxPixels,
      storedMaxPixels: ImageLimits.storedMaxPixels,
    );
    _checkCancelled();
    return staged;
  }

  void _checkCancelled() {
    if (_cancelled) throw const ImageImportCancelled();
  }

  /// Cancela la preparación y la borra (CA-007-15).
  Future<void> cancel() async {
    _cancelled = true;
    await _cancelNative(_owner.importer);
    await _owner.janitor.discardStaging(id);
  }

  /// Cancelar nunca deja el editor esperando: como mucho [cancelTimeout]; lo
  /// que quede en la preparación lo borra `discardStaging` o el barrido.
  Future<void> _cancelNative(ImageImporter importer) => importer
      .cancel(id)
      .timeout(cancelTimeout, onTimeout: () {})
      .catchError((Object _) {});

  static const cancelTimeout = Duration(seconds: 2);
}
