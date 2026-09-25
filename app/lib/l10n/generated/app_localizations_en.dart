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

  @override
  String get completeA11yAction => 'Complete task';

  @override
  String get completeA11yHint => 'Press and hold, or use actions, to complete';

  @override
  String get successTitle1 => 'Well done!';

  @override
  String get successTitle2 => 'Task completed.';

  @override
  String get successNext => 'Now on to the next one →';

  @override
  String a11yCompletedNext(String text) {
    return 'Task completed. Next: $text';
  }

  @override
  String get a11yCompletedAllDone => 'Task completed. All done.';

  @override
  String get emptyDoneTitle1 => 'All';

  @override
  String get emptyDoneTitle2 => 'done.';

  @override
  String get emptyDoneBody =>
      'Nothing left to do. Enjoy it, or jot down what\'s next.';

  @override
  String get emptyCreate => 'Create a task';

  @override
  String get completeError => 'We couldn\'t complete the task';

  @override
  String get editorTagNew => 'New task';

  @override
  String get editorTagEdit => 'Edit task';

  @override
  String get editorCancel => 'Cancel';

  @override
  String get editorContinue => 'Continue';

  @override
  String get editorSaveChanges => 'Save changes';

  @override
  String get placementTitle => 'Where does it go?';

  @override
  String placementQuoted(String text) {
    return '“$text”';
  }

  @override
  String get placementTop => 'On top';

  @override
  String get placementTopHint =>
      'It becomes the only one you see. The current one waits.';

  @override
  String get placementEnd => 'At the end';

  @override
  String get placementEndHint =>
      'You won\'t see it until you finish the ones before it.';

  @override
  String get placementKeepEditing => 'Keep editing';

  @override
  String get a11yQueued => 'Task added to the queue';

  @override
  String get menuSectionThisTask => 'This task';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuDelete => 'Delete';

  @override
  String get menuAllTasks => 'All my tasks';

  @override
  String get menuAllTasksOnlyOne => 'This is your only task';

  @override
  String get menuNewTask => 'New task';

  @override
  String get menuSettings => 'Settings and profile';

  @override
  String get menuClose => 'Close menu';

  @override
  String menuAllTasksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
    );
    return '$_temp0';
  }
}
