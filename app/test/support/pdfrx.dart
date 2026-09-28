import 'dart:io';

import 'package:pdfrx/pdfrx.dart';

/// Arranca pdfrx (PDFium de escritorio) en `flutter test`. Sin canal de
/// `path_provider`, la caché va a un temporal (T-008-04).
Future<void> initPdfrxForTests() async {
  Pdfrx.cacheDirectoryPath ??= Directory.systemTemp
      .createTempSync('una_pdfrx_')
      .path;
  await pdfrxFlutterInitialize();
}
