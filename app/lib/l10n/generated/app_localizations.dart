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

  /// Botón de completar. DEV-06; comportamiento en la spec 003
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsado para completar'**
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

  /// Error al escribir la tarea en el editor. Sección 5
  ///
  /// In es, this message translates to:
  /// **'No hemos podido guardar la tarea'**
  String get editorSaveError;
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
