import 'dart:io';

import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Abre la BD en el isolate principal (decisión I-1: la consulta de arranque no
/// paga el coste de crear un isolate; spike S1). Archivo en el directorio de
/// documentos de la app (`app_flutter/` en Android, incluido en el backup, ADR-0004).
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return openAppDatabaseFile(File('${dir.path}/una.sqlite'));
}

AppDatabase openAppDatabaseFile(File file) => AppDatabase(NativeDatabase(file));

AppDatabase openInMemoryDatabase() => AppDatabase(NativeDatabase.memory());
