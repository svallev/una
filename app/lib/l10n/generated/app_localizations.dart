import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Bienvenida (máquina de escribir). Spec 001, CA-001-01
  ///
  /// In es, this message translates to:
  /// **'Ya puedes crear tu primera tarea'**
  String get welcomeTitle;

  /// Etiqueta del editor de la primera tarea. CA-001-02
  ///
  /// In es, this message translates to:
  /// **'Tu primera tarea'**
  String get editorTagFirst;

  /// Placeholder del editor de texto. DEV-07
  ///
  /// In es, this message translates to:
  /// **'¿Qué es eso que tienes que hacer y no has hecho?'**
  String get editorPlaceholder;

  /// Botón para guardar la primera tarea. CA-001-04
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get editorSaveFirst;

  /// Contador a partir de 9000 caracteres. CL-001-2
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Queda 1 carácter} other{Quedan {count} caracteres}}'**
  String editorCharsLeft(int count);

  /// Lectura de la tarea actual para lectores de pantalla. Sección 6
  ///
  /// In es, this message translates to:
  /// **'Tarea actual: {text}'**
  String currentTaskSemantics(String text);

  /// Etiqueta del botón de menú (icono)
  ///
  /// In es, this message translates to:
  /// **'Menú de la tarea'**
  String get menuButton;

  /// Botón de completar, siempre en una sola línea (texto del prototipo; DEV-06 revocada). El gesto (mantener) está en la spec 003
  ///
  /// In es, this message translates to:
  /// **'Pulsa para completar'**
  String get completeButton;

  /// Error de almacenamiento. CL-001-6
  ///
  /// In es, this message translates to:
  /// **'No hemos podido abrir tus tareas'**
  String get storageErrorTitle;

  /// Error por falta de espacio. CL-001-6
  ///
  /// In es, this message translates to:
  /// **'Tu teléfono no tiene espacio libre'**
  String get storageErrorNoSpace;

  /// Botón de reintentar
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// Acción del lector de pantalla para saltar la bienvenida; se lee tras «Toca dos veces para». Sección 6
  ///
  /// In es, this message translates to:
  /// **'continuar'**
  String get skipIntroHint;

  /// Botón + del editor (nombre accesible). Funciona a partir de las specs 007–009
  ///
  /// In es, this message translates to:
  /// **'Añadir foto, imagen o archivo'**
  String get attachButton;

  /// Aviso fijo de la web de pruebas (ADR-0010). Los datos viven en memoria
  ///
  /// In es, this message translates to:
  /// **'Versión de pruebas · los datos se borran al recargar'**
  String get webPreviewBanner;

  /// Error al escribir la tarea en el editor. Sección 5
  ///
  /// In es, this message translates to:
  /// **'No hemos podido guardar la tarea'**
  String get editorSaveError;

  /// Acción del lector de pantalla para completar sin mantener pulsado. CA-003-07
  ///
  /// In es, this message translates to:
  /// **'Completar tarea'**
  String get completeA11yAction;

  /// Pista del botón de completar para el lector. Spec 003 §6
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsado o usa las acciones para completar'**
  String get completeA11yHint;

  /// Enhorabuena tras completar. CA-003-03b
  ///
  /// In es, this message translates to:
  /// **'¡Enhorabuena!'**
  String get successTitle1;

  /// Segunda línea, en el color de la tarea. CA-003-03b
  ///
  /// In es, this message translates to:
  /// **'Tarea completada.'**
  String get successTitle2;

  /// Solo si quedan tareas. CA-003-03b
  ///
  /// In es, this message translates to:
  /// **'Ahora a por la siguiente →'**
  String get successNext;

  /// Anuncio único al completar. CA-003-07
  ///
  /// In es, this message translates to:
  /// **'Tarea completada. Siguiente: {text}'**
  String a11yCompletedNext(String text);

  /// Anuncio al completar la última. CA-003-07
  ///
  /// In es, this message translates to:
  /// **'Tarea completada. Todo hecho.'**
  String get a11yCompletedAllDone;

  /// Estado vacío, primera línea. CA-003-05
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get emptyDoneTitle1;

  /// Estado vacío, segunda línea. CA-003-05
  ///
  /// In es, this message translates to:
  /// **'hecho.'**
  String get emptyDoneTitle2;

  /// Estado vacío. CA-003-05
  ///
  /// In es, this message translates to:
  /// **'No queda nada pendiente. Disfrútalo, o apunta lo siguiente.'**
  String get emptyDoneBody;

  /// Botón del estado vacío. CA-003-10
  ///
  /// In es, this message translates to:
  /// **'Crear una tarea'**
  String get emptyCreate;

  /// Error al guardar al completar. CA-003-12
  ///
  /// In es, this message translates to:
  /// **'No hemos podido completar la tarea'**
  String get completeError;

  /// Nombre accesible del campo al crear (no se ve). CA-002-01
  ///
  /// In es, this message translates to:
  /// **'Nueva tarea'**
  String get editorTagNew;

  /// Nombre accesible del campo al editar (no se ve). CA-005-04
  ///
  /// In es, this message translates to:
  /// **'Editar tarea'**
  String get editorTagEdit;

  /// Enlace para descartar (CA-002-07) y botón de la confirmación de eliminar (CA-004-01)
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get editorCancel;

  /// Botón del editor al crear, con flecha. CA-002-02
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get editorContinue;

  /// Botón del editor al editar. CA-005-05
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get editorSaveChanges;

  /// Título de la hoja de posición. CA-002-02
  ///
  /// In es, this message translates to:
  /// **'¿Dónde la pones?'**
  String get placementTitle;

  /// Texto de la tarea bajo el título. CA-002-02
  ///
  /// In es, this message translates to:
  /// **'“{text}”'**
  String placementQuoted(String text);

  /// Opción de posición. CA-002-03
  ///
  /// In es, this message translates to:
  /// **'Arriba del todo'**
  String get placementTop;

  /// Descripción de Arriba del todo
  ///
  /// In es, this message translates to:
  /// **'Pasa a ser la única visible. La actual espera.'**
  String get placementTopHint;

  /// Opción de posición. CA-002-04
  ///
  /// In es, this message translates to:
  /// **'A la cola'**
  String get placementEnd;

  /// Descripción de A la cola
  ///
  /// In es, this message translates to:
  /// **'No la verás hasta completar las anteriores.'**
  String get placementEndHint;

  /// Cierra la hoja. CA-002-05
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get placementKeepEditing;

  /// Solo lector de pantalla. CA-002-04
  ///
  /// In es, this message translates to:
  /// **'Tarea añadida a la cola'**
  String get a11yQueued;

  /// Encabezado del bloque del menú. CA-005-01
  ///
  /// In es, this message translates to:
  /// **'Esta tarea'**
  String get menuSectionThisTask;

  /// Menú. CA-005-04
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get menuEdit;

  /// Menú (spec 004). CA-005-11
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get menuDelete;

  /// Menú (spec 006). CA-005-03
  ///
  /// In es, this message translates to:
  /// **'Todas mis tareas'**
  String get menuAllTasks;

  /// Descripción accesible con una sola tarea. CA-005-03
  ///
  /// In es, this message translates to:
  /// **'Solo tienes esta tarea'**
  String get menuAllTasksOnlyOne;

  /// Botón principal del menú. CA-005-09
  ///
  /// In es, this message translates to:
  /// **'Nueva tarea'**
  String get menuNewTask;

  /// Texto del menú, sin interacción hasta la spec de Configuración y perfil. CA-005-09, CL-010-7
  ///
  /// In es, this message translates to:
  /// **'Configuración y perfil'**
  String get menuSettings;

  /// Botón X y fondo del menú. CA-005-02
  ///
  /// In es, this message translates to:
  /// **'Cerrar menú'**
  String get menuClose;

  /// Lectura del total junto a Todas mis tareas. CA-005-12
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 tarea} other{{count} tareas}}'**
  String menuAllTasksCount(int count);

  /// Título de la confirmación de eliminar. CA-004-01
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta tarea?'**
  String get deleteTitle;

  /// Cuerpo de la confirmación de eliminar, con comillas tipográficas del prototipo. CA-004-01
  ///
  /// In es, this message translates to:
  /// **'“{label}” desaparecerá sin marcarse como hecha.'**
  String deleteBody(String label);

  /// Botón rojo que elimina de forma definitiva. CA-004-01
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteConfirm;

  /// Acción del lector de pantalla que abre la confirmación de eliminar. CA-004-10
  ///
  /// In es, this message translates to:
  /// **'Eliminar tarea'**
  String get deleteA11yAction;

  /// Anuncio único al eliminar. CA-004-11
  ///
  /// In es, this message translates to:
  /// **'Tarea eliminada. Siguiente: {text}'**
  String a11yDeletedNext(String text);

  /// Anuncio al eliminar la última pendiente. CA-004-11
  ///
  /// In es, this message translates to:
  /// **'Tarea eliminada. Todo hecho.'**
  String get a11yDeletedAllDone;

  /// Aviso con Reintentar si falla la eliminación. CA-004-13
  ///
  /// In es, this message translates to:
  /// **'No hemos podido eliminar la tarea'**
  String get deleteError;

  /// Título y nombre de la pantalla del listado. CA-006-02, CA-006-17
  ///
  /// In es, this message translates to:
  /// **'Todas las tareas'**
  String get listTitle;

  /// Nombre accesible del botón con flecha del listado. CA-006-03
  ///
  /// In es, this message translates to:
  /// **'Volver a la tarea'**
  String get listBack;

  /// Ayuda del listado (prototipo). CA-006-02
  ///
  /// In es, this message translates to:
  /// **'La primera es la que tienes ahora. Arrastra otra por encima para que ocupe su lugar. Toca dos veces una tarea para editarla.'**
  String get listHelp;

  /// Ayuda del listado con el lector de pantalla activo (DEV-33). CA-006-18
  ///
  /// In es, this message translates to:
  /// **'La primera es la que tienes ahora. Usa las acciones de cada tarea para cambiar el orden, editarla o eliminarla.'**
  String get listHelpScreenReader;

  /// Botón Editar de cada fila y acción del lector. CA-006-13, CA-006-16
  ///
  /// In es, this message translates to:
  /// **'Editar tarea'**
  String get listEdit;

  /// Pista de activación de la fila; TalkBack dice 'Toca dos veces para editar'. CA-006-18
  ///
  /// In es, this message translates to:
  /// **'editar'**
  String get listEditHint;

  /// Botón inferior del listado. CA-006-15
  ///
  /// In es, this message translates to:
  /// **'Nueva tarea'**
  String get listNewTask;

  /// Nombre del asa (botón) y etiqueta de la hoja Mover (DEV-28). CA-006-08
  ///
  /// In es, this message translates to:
  /// **'Mover tarea'**
  String get listMove;

  /// Opción de mover a la posición 1. CA-006-09
  ///
  /// In es, this message translates to:
  /// **'Hacer actual'**
  String get listMakeCurrent;

  /// Opción de mover una posición arriba. CA-006-09
  ///
  /// In es, this message translates to:
  /// **'Mover arriba'**
  String get listMoveUp;

  /// Opción de mover una posición abajo. CA-006-09
  ///
  /// In es, this message translates to:
  /// **'Mover abajo'**
  String get listMoveDown;

  /// Aviso con Reintentar si falla el reordenado. Spec 006 §5
  ///
  /// In es, this message translates to:
  /// **'No hemos podido mover la tarea'**
  String get listMoveError;

  /// Lectura de las filas 2…N del listado. CA-006-18
  ///
  /// In es, this message translates to:
  /// **'{position} de {total}: {text}'**
  String a11yRowPosition(int position, int total, String text);

  /// Lectura de la primera fila del listado. CA-006-18
  ///
  /// In es, this message translates to:
  /// **'1 de {total}. Tarea actual: {text}'**
  String a11yRowCurrent(int total, String text);

  /// Anuncio tras mover una tarea sin llegar a la primera. CA-006-17
  ///
  /// In es, this message translates to:
  /// **'Movida a la posición {position} de {total}'**
  String a11yMovedTo(int position, int total);

  /// Anuncio cuando una tarea llega a la posición 1. CA-006-17
  ///
  /// In es, this message translates to:
  /// **'Ahora es la tarea actual'**
  String get a11yNowCurrent;

  /// Anuncio al crear desde el listado. CA-006-17
  ///
  /// In es, this message translates to:
  /// **'Tarea añadida en la posición {position} de {total}'**
  String a11yAddedAt(int position, int total);

  /// Anuncio al eliminar desde el listado una tarea que no es la primera. CA-006-17
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Tarea eliminada. Queda 1} other{Tarea eliminada. Quedan {count}}}'**
  String a11yDeletedFromList(int count);

  /// Título y nombre de la hoja "Añadir". CA-007-01
  ///
  /// In es, this message translates to:
  /// **'Añadir a la tarea'**
  String get attachSheetTitle;

  /// X de la hoja "Añadir". CA-007-01
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get attachSheetClose;

  /// Fila de la hoja "Añadir". CA-007-01
  ///
  /// In es, this message translates to:
  /// **'Hacer foto'**
  String get attachTakePhoto;

  /// Segunda línea de "Hacer foto"; el lector la lee tras una coma
  ///
  /// In es, this message translates to:
  /// **'Con la cámara · va arriba del todo'**
  String get attachTakePhotoHint;

  /// Fila de la hoja "Añadir". CA-007-01
  ///
  /// In es, this message translates to:
  /// **'Subir imagen'**
  String get attachPickImage;

  /// Segunda línea de "Subir imagen"
  ///
  /// In es, this message translates to:
  /// **'Desde tu galería · va arriba del todo'**
  String get attachPickImageHint;

  /// Fila de la hoja "Añadir": sube un PDF (spec 008)
  ///
  /// In es, this message translates to:
  /// **'Subir archivo'**
  String get attachPickFile;

  /// Segunda línea de "Subir archivo": solo PDF en la v1 (DEV-02, ADR-0014)
  ///
  /// In es, this message translates to:
  /// **'PDF · va arriba del todo'**
  String get attachPickFileHint;

  /// Fila de la hoja "Añadir", solo en tareas nuevas: abre la hoja "Cargar URL" (spec 009, CA-009-01)
  ///
  /// In es, this message translates to:
  /// **'Cargar URL'**
  String get attachUrl;

  /// Segunda línea de "Cargar URL"
  ///
  /// In es, this message translates to:
  /// **'Una página web · va arriba del todo'**
  String get attachUrlHint;

  /// Indicador de importación lenta (> 400 ms). CA-007-15
  ///
  /// In es, this message translates to:
  /// **'Preparando imagen…'**
  String get imagePreparing;

  /// Cancela la importación. CA-007-15
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get imagePreparingCancel;

  /// Tarea sin texto con foto de la cámara (listado, eliminar, anuncios); insignia FOTO. CA-007-20
  ///
  /// In es, this message translates to:
  /// **'Foto'**
  String get attachmentPhoto;

  /// Tarea sin texto con imagen de la galería; insignia IMAGEN. CA-007-20
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get attachmentImage;

  /// Lectura de una tarea con texto y foto. CA-007-21
  ///
  /// In es, this message translates to:
  /// **'{text}. Con foto'**
  String a11yWithPhoto(String text);

  /// Lectura de una tarea con texto e imagen. CA-007-21
  ///
  /// In es, this message translates to:
  /// **'{text}. Con imagen'**
  String a11yWithImage(String text);

  /// Anuncio al volver de la cámara. CA-007-22
  ///
  /// In es, this message translates to:
  /// **'Foto añadida'**
  String get a11yPhotoAdded;

  /// Anuncio al volver del selector. CA-007-22
  ///
  /// In es, this message translates to:
  /// **'Imagen añadida'**
  String get a11yImageAdded;

  /// Anuncio tras "Quitar adjunto". CA-007-22
  ///
  /// In es, this message translates to:
  /// **'Adjunto quitado'**
  String get a11yAttachmentRemoved;

  /// Campo de texto del editor con imagen: el texto es opcional. CA-007-04 (spec 005)
  ///
  /// In es, this message translates to:
  /// **'Añade un texto (opcional)'**
  String get editorAttachmentPlaceholder;

  /// Botón X sobre la vista previa del editor. CA-007-04 (spec 005)
  ///
  /// In es, this message translates to:
  /// **'Quitar adjunto'**
  String get editorRemoveAttachment;

  /// Error de importación. Spec 007 §5
  ///
  /// In es, this message translates to:
  /// **'Este tipo de imagen no se admite. Prueba con una foto JPEG, PNG o HEIC.'**
  String get errImageType;

  /// Error de importación. Spec 007 §5
  ///
  /// In es, this message translates to:
  /// **'La imagen es demasiado grande (máx. {max} MB).'**
  String errImageTooBig(int max);

  /// Error de importación. Spec 007 §5
  ///
  /// In es, this message translates to:
  /// **'La imagen tiene demasiada resolución (máx. {max} megapíxeles).'**
  String errImageTooManyPixels(int max);

  /// Error de importación (ilegible, corrupta o tiempo agotado). Spec 007 §5
  ///
  /// In es, this message translates to:
  /// **'No hemos podido leer esta imagen. Prueba con otra.'**
  String get errImageUnreadable;

  /// Sin app de cámara. CL-007-1
  ///
  /// In es, this message translates to:
  /// **'No hay ninguna app de cámara disponible.'**
  String get errNoCamera;

  /// Tarjeta de adjunto perdido. CA-007-19
  ///
  /// In es, this message translates to:
  /// **'Adjunto no disponible'**
  String get attachmentMissing;

  /// Lectura de la tarea actual cuyo adjunto falta: {text} es el texto de la tarea o «Foto»/«Imagen». CA-007-19/21
  ///
  /// In es, this message translates to:
  /// **'{text}. Adjunto no disponible'**
  String a11yAttachmentMissing(String text);

  /// Insignia del listado y lectura de una tarea con PDF. Spec 008 §7
  ///
  /// In es, this message translates to:
  /// **'PDF'**
  String get attachmentPdf;

  /// Tamaño del PDF en la franja y en las lecturas; `size` con un decimal y el separador del idioma. Spec 008 §7
  ///
  /// In es, this message translates to:
  /// **'{size} MB'**
  String docSizeMb(String size);

  /// Tamaño del PDF por debajo de 1 MB (entero), como el prototipo. Spec 008 §7
  ///
  /// In es, this message translates to:
  /// **'{size} KB'**
  String docSizeKb(String size);

  /// Importación de un PDF que tarda más de 400 ms. CA-008-15
  ///
  /// In es, this message translates to:
  /// **'Preparando PDF…'**
  String get pdfPreparing;

  /// Cancela la importación del PDF. CA-008-15
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get pdfPreparingCancel;

  /// Solo lector de pantalla: lectura y anuncio de una página del PDF (no hay indicador visible). CA-008-20/21
  ///
  /// In es, this message translates to:
  /// **'Página {page} de {total}'**
  String pdfPageA11y(int page, int total);

  /// Acción del lector en el PDF. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'Página siguiente'**
  String get pdfNextPage;

  /// Acción del lector en el PDF. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'Página anterior'**
  String get pdfPrevPage;

  /// Acción del lector en el PDF. CA-008-10
  ///
  /// In es, this message translates to:
  /// **'Ampliar'**
  String get pdfZoomIn;

  /// Acción del lector en el PDF. CA-008-10
  ///
  /// In es, this message translates to:
  /// **'Reducir'**
  String get pdfZoomOut;

  /// Acción del lector en el PDF: vuelve a ×1. CA-008-10
  ///
  /// In es, this message translates to:
  /// **'Ajustar al ancho'**
  String get pdfZoomFit;

  /// Lectura de la tarea actual con PDF y texto. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'{text}. Con PDF, {name}, {size}'**
  String a11yWithPdf(String text, String name, String size);

  /// Lectura de la tarea actual con PDF sin texto. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'{name}. PDF, {size}'**
  String a11yPdfOnly(String name, String size);

  /// Lectura de la fila del listado con PDF y texto. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'{text}. Con PDF'**
  String a11yRowWithPdf(String text);

  /// Lectura de la fila del listado con PDF sin texto: el nombre del archivo. CA-008-20
  ///
  /// In es, this message translates to:
  /// **'{name}. PDF'**
  String a11yRowPdfOnly(String name);

  /// Anuncio tras una acción de zoom del PDF. CA-008-10/21
  ///
  /// In es, this message translates to:
  /// **'Zoom {percent} %'**
  String a11yZoomLevel(int percent);

  /// Etiqueta de un enlace web del PDF. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'Enlace a {host}'**
  String pdfLinkWeb(String host);

  /// Etiqueta de un enlace interno del PDF. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'Enlace a la página {page}'**
  String pdfLinkPage(int page);

  /// Etiqueta de un enlace de correo o teléfono del PDF. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'Enlace a {target}'**
  String pdfLinkApp(String target);

  /// Anuncio al volver del selector con un PDF. CA-008-21
  ///
  /// In es, this message translates to:
  /// **'PDF añadido'**
  String get a11yPdfAdded;

  /// Error de importación: el contenido no es un PDF. Spec 008 §5
  ///
  /// In es, this message translates to:
  /// **'Solo se pueden subir archivos PDF.'**
  String get errPdfType;

  /// Error de importación. Spec 008 §5
  ///
  /// In es, this message translates to:
  /// **'El PDF es demasiado grande (máx. {max} MB).'**
  String errPdfTooBig(int max);

  /// Error de importación. Spec 008 §5
  ///
  /// In es, this message translates to:
  /// **'El PDF tiene demasiadas páginas (máx. {max}).'**
  String errPdfTooManyPages(int max);

  /// Error de importación: pide contraseña para abrirse. CL-008-1
  ///
  /// In es, this message translates to:
  /// **'Este PDF está protegido con contraseña.'**
  String get errPdfProtected;

  /// Error de importación (ilegible, sin páginas o tiempo agotado). Spec 008 §5
  ///
  /// In es, this message translates to:
  /// **'No hemos podido leer este PDF.'**
  String get errPdfUnreadable;

  /// Enlace del PDF sin navegador ni app que lo abra. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'No hay ninguna app para abrir este enlace.'**
  String get errNoAppForLink;

  /// Confirmación de un enlace web (PDF, spec 008; también la 009)
  ///
  /// In es, this message translates to:
  /// **'¿Abrir {host} en el navegador?'**
  String openInBrowserConfirm(String host);

  /// Confirmación de un enlace mailto: o tel: del PDF. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'¿Abrir {target} con otra app?'**
  String openInAppConfirm(String target);

  /// Botón de la confirmación de un enlace. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get linkConfirmOpen;

  /// Botón de la confirmación de un enlace. CA-008-12
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get linkConfirmCancel;

  /// Título de la hoja "Cargar URL". CA-009-01
  ///
  /// In es, this message translates to:
  /// **'Cargar URL'**
  String get urlSheetTitle;

  /// Marcador del campo de la dirección. CA-009-01
  ///
  /// In es, this message translates to:
  /// **'https://'**
  String get urlPlaceholder;

  /// Ayuda bajo el campo de la hoja "Cargar URL". CA-009-01
  ///
  /// In es, this message translates to:
  /// **'Se abre como tarea, arriba del todo.'**
  String get urlHelp;

  /// Botón de la hoja "Cargar URL": crea (o sustituye) la tarea web. CA-009-03/05
  ///
  /// In es, this message translates to:
  /// **'Abrir'**
  String get urlOpen;

  /// Error de la hoja: campo vacío. CA-009-02
  ///
  /// In es, this message translates to:
  /// **'Escribe una dirección web.'**
  String get urlErrEmpty;

  /// Error de la hoja: esquema que no es http ni https. CA-009-02
  ///
  /// In es, this message translates to:
  /// **'Solo se admiten direcciones web (http o https).'**
  String get urlErrScheme;

  /// Error de la hoja: dirección no válida. CA-009-02
  ///
  /// In es, this message translates to:
  /// **'Esa dirección no parece válida.'**
  String get urlErrInvalid;

  /// Aviso de la tarea web sin conexión, con "Reintentar" y "Abrir en el navegador". CA-009-08
  ///
  /// In es, this message translates to:
  /// **'Necesitas conexión para ver esta página.'**
  String get urlNeedsConnection;

  /// Aviso de la tarea web cuando el servidor no admite https. CA-009-09
  ///
  /// In es, this message translates to:
  /// **'Esta página no usa conexión segura. Ábrela en el navegador.'**
  String get urlInsecure;

  /// Aviso de la tarea web con el motivo (p. ej. urlReasonCertificate). CA-009-10
  ///
  /// In es, this message translates to:
  /// **'No se ha podido cargar la página ({reason}).'**
  String urlLoadFailed(String reason);

  /// Motivo de urlLoadFailed: certificado no válido. CA-009-10
  ///
  /// In es, this message translates to:
  /// **'certificado no válido'**
  String get urlReasonCertificate;

  /// Motivo de urlLoadFailed: la página intenta ir a otra dos veces seguidas y se deja de recargar (propietario, 2026-09-29). CA-009-11
  ///
  /// In es, this message translates to:
  /// **'intenta abrir otra página'**
  String get urlReasonKeepsLeaving;

  /// Aviso de la tarea web cuando la dirección descarga un archivo (p. ej. un PDF). CL-009-4
  ///
  /// In es, this message translates to:
  /// **'Esta dirección no es una página web. Ábrela en el navegador.'**
  String get urlNotAPage;

  /// Aviso único cuando la carga inicial acaba en otro sitio. CL-009-1
  ///
  /// In es, this message translates to:
  /// **'Esta dirección te ha llevado a {host}.'**
  String urlRedirected(String host);

  /// Botón de los avisos de la tarea web. CA-009-08/09/10
  ///
  /// In es, this message translates to:
  /// **'Abrir en el navegador'**
  String get urlOpenInBrowser;

  /// Solo lector de pantalla: lectura y anuncio del indicador de carga de la tarea web. CA-009-06/20
  ///
  /// In es, this message translates to:
  /// **'Cargando página'**
  String get urlLoadingA11y;

  /// Lectura de la tarea web (barra o logotipo en horizontal), con el prefijo currentTaskSemantics. CA-009-18
  ///
  /// In es, this message translates to:
  /// **'Página web de {host}'**
  String urlA11yBar(String host);

  /// Insignia de la barra y del listado de una tarea web. Spec 009 §7
  ///
  /// In es, this message translates to:
  /// **'WEB'**
  String get attachmentWeb;

  /// Lectura de la fila del listado de una tarea web. CA-009-17/18
  ///
  /// In es, this message translates to:
  /// **'{host}. Página web'**
  String a11yRowWeb(String host);

  /// Solo web de pruebas: abre la dirección en una pestaña nueva. CL-009-5
  ///
  /// In es, this message translates to:
  /// **'Abrir página →'**
  String get urlOpenPageWeb;

  /// Icono del nivel 1 de Configuración y perfil. Propia, distinta de attachSheetClose y menuClose (cada una con su contexto). CA-012-01/11
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get settingsClose;

  /// Opción del nivel 1 que abre la lista de licencias. CA-012-01/03
  ///
  /// In es, this message translates to:
  /// **'Licencias de código abierto'**
  String get settingsLicenses;

  /// Opción del nivel 1 que abre la política en el navegador, tras confirmar. CA-012-01/04
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get settingsPrivacy;

  /// Pista del lector de pantalla de Política de privacidad. CA-012-11
  ///
  /// In es, this message translates to:
  /// **'Abre una página web en el navegador'**
  String get settingsPrivacyHint;

  /// Encabezado del nivel 2 (lista de licencias). CA-012-03/11
  ///
  /// In es, this message translates to:
  /// **'Licencias de código abierto'**
  String get licensesTitle;

  /// Estado de carga del nivel 2; se anuncia al lector. CA-012-15
  ///
  /// In es, this message translates to:
  /// **'Cargando licencias…'**
  String get licensesLoading;

  /// Bajo el nombre de cada elemento de la lista de licencias; el lector dice "nombre, N licencias". CA-012-03/11
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 licencia} other{{count} licencias}}'**
  String licensesCount(int count);

  /// Botón de volver de los niveles 2 y 3. CA-012-02/11
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get licensesBack;

  /// Error de lectura de las licencias, con Reintentar. CA-012-15
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las licencias.'**
  String get licensesError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
