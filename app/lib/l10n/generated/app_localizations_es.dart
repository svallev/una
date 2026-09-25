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
  String get completeButton => 'Pulsa para completar';

  @override
  String get storageErrorTitle => 'No hemos podido abrir tus tareas';

  @override
  String get storageErrorNoSpace => 'Tu teléfono no tiene espacio libre';

  @override
  String get retry => 'Reintentar';

  @override
  String get skipIntroHint => 'continuar';

  @override
  String get attachButton => 'Añadir foto, imagen o archivo';

  @override
  String get webPreviewBanner =>
      'Versión de pruebas · los datos se borran al recargar';

  @override
  String get editorSaveError => 'No hemos podido guardar la tarea';

  @override
  String get completeA11yAction => 'Completar tarea';

  @override
  String get completeA11yHint =>
      'Mantén pulsado o usa las acciones para completar';

  @override
  String get successTitle1 => '¡Enhorabuena!';

  @override
  String get successTitle2 => 'Tarea completada.';

  @override
  String get successNext => 'Ahora a por la siguiente →';

  @override
  String a11yCompletedNext(String text) {
    return 'Tarea completada. Siguiente: $text';
  }

  @override
  String get a11yCompletedAllDone => 'Tarea completada. Todo hecho.';

  @override
  String get emptyDoneTitle1 => 'Todo';

  @override
  String get emptyDoneTitle2 => 'hecho.';

  @override
  String get emptyDoneBody =>
      'No queda nada pendiente. Disfrútalo, o apunta lo siguiente.';

  @override
  String get emptyCreate => 'Crear una tarea';

  @override
  String get completeError => 'No hemos podido completar la tarea';

  @override
  String get editorTagNew => 'Nueva tarea';

  @override
  String get editorTagEdit => 'Editar tarea';

  @override
  String get editorCancel => 'Cancelar';

  @override
  String get editorContinue => 'Continuar';

  @override
  String get editorSaveChanges => 'Guardar cambios';

  @override
  String get placementTitle => '¿Dónde la pones?';

  @override
  String placementQuoted(String text) {
    return '“$text”';
  }

  @override
  String get placementTop => 'Arriba del todo';

  @override
  String get placementTopHint =>
      'Pasa a ser la única visible. La actual espera.';

  @override
  String get placementEnd => 'A la cola';

  @override
  String get placementEndHint => 'No la verás hasta completar las anteriores.';

  @override
  String get placementKeepEditing => 'Seguir editando';

  @override
  String get a11yQueued => 'Tarea añadida a la cola';

  @override
  String get menuSectionThisTask => 'Esta tarea';

  @override
  String get menuEdit => 'Editar';

  @override
  String get menuDelete => 'Eliminar';

  @override
  String get menuAllTasks => 'Todas mis tareas';

  @override
  String get menuAllTasksOnlyOne => 'Solo tienes esta tarea';

  @override
  String get menuNewTask => 'Nueva tarea';

  @override
  String get menuSettings => 'Configuración y perfil';

  @override
  String get menuClose => 'Cerrar menú';
}
