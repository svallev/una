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

  @override
  String menuAllTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas',
      one: '1 tarea',
    );
    return '$_temp0';
  }

  @override
  String get deleteTitle => '¿Eliminar esta tarea?';

  @override
  String deleteBody(String label) {
    return '“$label” desaparecerá sin marcarse como hecha.';
  }

  @override
  String get deleteConfirm => 'Eliminar';

  @override
  String get deleteA11yAction => 'Eliminar tarea';

  @override
  String a11yDeletedNext(String text) {
    return 'Tarea eliminada. Siguiente: $text';
  }

  @override
  String get a11yDeletedAllDone => 'Tarea eliminada. Todo hecho.';

  @override
  String get deleteError => 'No hemos podido eliminar la tarea';

  @override
  String get listTitle => 'Todas las tareas';

  @override
  String get listBack => 'Volver a la tarea';

  @override
  String get listHelp =>
      'La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla.';

  @override
  String get listHelpScreenReader =>
      'La primera es la que tienes ahora. Usa las acciones de cada tarea para cambiar el orden, editarla o eliminarla.';

  @override
  String get listEdit => 'Editar tarea';

  @override
  String get listEditHint => 'editar';

  @override
  String get listNewTask => 'Nueva tarea';

  @override
  String get listMove => 'Mover tarea';

  @override
  String get listMakeCurrent => 'Hacer actual';

  @override
  String get listMoveUp => 'Mover arriba';

  @override
  String get listMoveDown => 'Mover abajo';

  @override
  String get listMoveError => 'No hemos podido mover la tarea';

  @override
  String a11yRowPosition(int position, int total, String text) {
    return '$position de $total: $text';
  }

  @override
  String a11yRowCurrent(int total, String text) {
    return '1 de $total. Tarea actual: $text';
  }

  @override
  String a11yMovedTo(int position, int total) {
    return 'Movida a la posición $position de $total';
  }

  @override
  String get a11yNowCurrent => 'Ahora es la tarea actual';

  @override
  String a11yAddedAt(int position, int total) {
    return 'Tarea añadida en la posición $position de $total';
  }

  @override
  String a11yDeletedFromList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tarea eliminada. Quedan $count',
      one: 'Tarea eliminada. Queda 1',
    );
    return '$_temp0';
  }

  @override
  String get attachSheetTitle => 'Añadir a la tarea';

  @override
  String get attachSheetClose => 'Cerrar';

  @override
  String get attachTakePhoto => 'Hacer foto';

  @override
  String get attachTakePhotoHint => 'Con la cámara · va arriba del todo';

  @override
  String get attachPickImage => 'Subir imagen';

  @override
  String get attachPickImageHint => 'Desde tu galería · va arriba del todo';

  @override
  String get attachPickFile => 'Subir archivo';

  @override
  String get attachPickFileHint => 'PDF · va arriba del todo';

  @override
  String get attachUrl => 'Cargar URL';

  @override
  String get attachUrlHint => 'Una página web · va arriba del todo';

  @override
  String get imagePreparing => 'Preparando imagen…';

  @override
  String get imagePreparingCancel => 'Cancelar';

  @override
  String get attachmentPhoto => 'Foto';

  @override
  String get attachmentImage => 'Imagen';

  @override
  String a11yWithPhoto(String text) {
    return '$text. Con foto';
  }

  @override
  String a11yWithImage(String text) {
    return '$text. Con imagen';
  }

  @override
  String get a11yPhotoAdded => 'Foto añadida';

  @override
  String get a11yImageAdded => 'Imagen añadida';

  @override
  String get a11yAttachmentRemoved => 'Adjunto quitado';

  @override
  String get editorAttachmentPlaceholder => 'Añade un texto (opcional)';

  @override
  String get editorRemoveAttachment => 'Quitar adjunto';

  @override
  String get errImageType =>
      'Este tipo de imagen no se admite. Prueba con una foto JPEG, PNG o HEIC.';

  @override
  String errImageTooBig(int max) {
    return 'La imagen es demasiado grande (máx. $max MB).';
  }

  @override
  String errImageTooManyPixels(int max) {
    return 'La imagen tiene demasiada resolución (máx. $max megapíxeles).';
  }

  @override
  String get errImageUnreadable =>
      'No hemos podido leer esta imagen. Prueba con otra.';

  @override
  String get errNoCamera => 'No hay ninguna app de cámara disponible.';

  @override
  String get attachmentMissing => 'Adjunto no disponible';

  @override
  String a11yAttachmentMissing(String text) {
    return '$text. Adjunto no disponible';
  }

  @override
  String get attachmentPdf => 'PDF';

  @override
  String docSizeMb(String size) {
    return '$size MB';
  }

  @override
  String docSizeKb(String size) {
    return '$size KB';
  }

  @override
  String get pdfPreparing => 'Preparando PDF…';

  @override
  String get pdfPreparingCancel => 'Cancelar';

  @override
  String pdfPageA11y(int page, int total) {
    return 'Página $page de $total';
  }

  @override
  String get pdfNextPage => 'Página siguiente';

  @override
  String get pdfPrevPage => 'Página anterior';

  @override
  String get pdfZoomIn => 'Ampliar';

  @override
  String get pdfZoomOut => 'Reducir';

  @override
  String get pdfZoomFit => 'Ajustar al ancho';

  @override
  String a11yWithPdf(String text, String name, String size) {
    return '$text. Con PDF, $name, $size';
  }

  @override
  String a11yPdfOnly(String name, String size) {
    return '$name. PDF, $size';
  }

  @override
  String a11yRowWithPdf(String text) {
    return '$text. Con PDF';
  }

  @override
  String a11yRowPdfOnly(String name) {
    return '$name. PDF';
  }

  @override
  String a11yZoomLevel(int percent) {
    return 'Zoom $percent %';
  }

  @override
  String pdfLinkWeb(String host) {
    return 'Enlace a $host';
  }

  @override
  String pdfLinkPage(int page) {
    return 'Enlace a la página $page';
  }

  @override
  String pdfLinkApp(String target) {
    return 'Enlace a $target';
  }

  @override
  String get a11yPdfAdded => 'PDF añadido';

  @override
  String get errPdfType => 'Solo se pueden subir archivos PDF.';

  @override
  String errPdfTooBig(int max) {
    return 'El PDF es demasiado grande (máx. $max MB).';
  }

  @override
  String errPdfTooManyPages(int max) {
    return 'El PDF tiene demasiadas páginas (máx. $max).';
  }

  @override
  String get errPdfProtected => 'Este PDF está protegido con contraseña.';

  @override
  String get errPdfUnreadable => 'No hemos podido leer este PDF.';

  @override
  String get errNoAppForLink => 'No hay ninguna app para abrir este enlace.';

  @override
  String openInBrowserConfirm(String host) {
    return '¿Abrir $host en el navegador?';
  }

  @override
  String openInAppConfirm(String target) {
    return '¿Abrir $target con otra app?';
  }

  @override
  String get linkConfirmOpen => 'Abrir';

  @override
  String get linkConfirmCancel => 'Cancelar';

  @override
  String get urlSheetTitle => 'Cargar URL';

  @override
  String get urlPlaceholder => 'https://';

  @override
  String get urlHelp => 'Se abre como tarea, arriba del todo.';

  @override
  String get urlOpen => 'Abrir';

  @override
  String get urlErrEmpty => 'Escribe una dirección web.';

  @override
  String get urlErrScheme => 'Solo se admiten direcciones web (http o https).';

  @override
  String get urlErrInvalid => 'Esa dirección no parece válida.';

  @override
  String get urlNeedsConnection => 'Necesitas conexión para ver esta página.';

  @override
  String get urlInsecure =>
      'Esta página no usa conexión segura. Ábrela en el navegador.';

  @override
  String urlLoadFailed(String reason) {
    return 'No se ha podido cargar la página ($reason).';
  }

  @override
  String get urlReasonCertificate => 'certificado no válido';

  @override
  String get urlReasonKeepsLeaving => 'intenta abrir otra página';

  @override
  String get urlNotAPage =>
      'Esta dirección no es una página web. Ábrela en el navegador.';

  @override
  String urlRedirected(String host) {
    return 'Esta dirección te ha llevado a $host.';
  }

  @override
  String get urlOpenInBrowser => 'Abrir en el navegador';

  @override
  String get urlLoadingA11y => 'Cargando página';

  @override
  String urlA11yBar(String host) {
    return 'Página web de $host';
  }

  @override
  String get attachmentWeb => 'WEB';

  @override
  String a11yRowWeb(String host) {
    return '$host. Página web';
  }

  @override
  String get urlOpenPageWeb => 'Abrir página →';
}
