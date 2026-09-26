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

  @override
  String get deleteTitle => 'Delete this task?';

  @override
  String deleteBody(String label) {
    return '“$label” will disappear without being marked as done.';
  }

  @override
  String get deleteConfirm => 'Delete';

  @override
  String get deleteA11yAction => 'Delete task';

  @override
  String a11yDeletedNext(String text) {
    return 'Task deleted. Next: $text';
  }

  @override
  String get a11yDeletedAllDone => 'Task deleted. All done.';

  @override
  String get deleteError => 'We couldn\'t delete the task';

  @override
  String get listTitle => 'All tasks';

  @override
  String get listBack => 'Back to the task';

  @override
  String get listHelp =>
      'The first one is the one you have now. Drag another above it to take its place. Double-tap a task to edit it.';

  @override
  String get listHelpScreenReader =>
      'The first one is the one you have now. Use each task\'s actions to change the order, edit it or delete it.';

  @override
  String get listEdit => 'Edit task';

  @override
  String get listEditHint => 'edit';

  @override
  String get listNewTask => 'New task';

  @override
  String get listMove => 'Move task';

  @override
  String get listMakeCurrent => 'Make current';

  @override
  String get listMoveUp => 'Move up';

  @override
  String get listMoveDown => 'Move down';

  @override
  String get listMoveError => 'We couldn\'t move the task';

  @override
  String a11yRowPosition(int position, int total, String text) {
    return '$position of $total: $text';
  }

  @override
  String a11yRowCurrent(int total, String text) {
    return '1 of $total. Current task: $text';
  }

  @override
  String a11yMovedTo(int position, int total) {
    return 'Moved to position $position of $total';
  }

  @override
  String get a11yNowCurrent => 'It\'s now the current task';

  @override
  String a11yAddedAt(int position, int total) {
    return 'Task added at position $position of $total';
  }

  @override
  String a11yDeletedFromList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Task deleted. $count left',
      one: 'Task deleted. 1 left',
    );
    return '$_temp0';
  }
}
