// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get welcomeTitle => 'Ya puedes crear tu primera tarea';

  @override
  String get editorTagFirst => 'Tu primera tarea';

  @override
  String get editorPlaceholder =>
      '¿Qué es eso que tienes que hacer y no has hecho?';

  @override
  String get editorSaveFirst => 'Guardar';

  @override
  String editorCharsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count caracteres',
      one: 'Queda 1 carácter',
    );
    return '$_temp0';
  }

  @override
  String currentTaskSemantics(String text) {
    return 'Tarea actual: $text';
  }

  @override
  String get menuButton => 'Menú de la tarea';

  @override
  String get completeButton => 'Mantén pulsado para completar';

  @override
  String get storageErrorTitle => 'No hemos podido abrir tus tareas';

  @override
  String get storageErrorNoSpace => 'Tu teléfono no tiene espacio libre';

  @override
  String get retry => 'Reintentar';

  @override
  String get skipIntroHint => 'continuar';

  @override
  String get editorSaveError => 'No hemos podido guardar la tarea';
}
