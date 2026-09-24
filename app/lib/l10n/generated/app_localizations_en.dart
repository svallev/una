// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeTitle => 'You can now create your first task';

  @override
  String get editorTagFirst => 'Your first task';

  @override
  String get editorPlaceholder =>
      'What\'s that thing you need to do and haven\'t done yet?';

  @override
  String get editorSaveFirst => 'Save';

  @override
  String editorCharsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters left',
      one: '1 character left',
    );
    return '$_temp0';
  }

  @override
  String currentTaskSemantics(String text) {
    return 'Current task: $text';
  }

  @override
  String get menuButton => 'Task menu';

  @override
  String get completeButton => 'Press to complete';

  @override
  String get storageErrorTitle => 'We couldn\'t open your tasks';

  @override
  String get storageErrorNoSpace => 'Your phone is out of storage';

  @override
  String get retry => 'Try again';

  @override
  String get skipIntroHint => 'continue';

  @override
  String get attachButton => 'Add a photo, image or file';

  @override
  String get webPreviewBanner =>
      'Test version · data is erased when you reload';

  @override
  String get editorSaveError => 'We couldn\'t save your task';
}
