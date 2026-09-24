import '../domain/ports/task_repository.dart';
import 'repository_factory_native.dart'
    if (dart.library.js_interop) 'repository_factory_web.dart'
    as impl;

/// Repositorios de la plataforma: SQLite en móvil; en memoria en la web de pruebas (D4, ADR-0010).
typedef Repositories = ({TaskRepository tasks, SettingsRepository settings});

Future<Repositories> openRepositories() => impl.openRepositories();
