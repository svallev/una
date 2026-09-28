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

  @override
  String get attachSheetTitle => 'Add to the task';

  @override
  String get attachSheetClose => 'Close';

  @override
  String get attachTakePhoto => 'Take photo';

  @override
  String get attachTakePhotoHint => 'With the camera · goes on top';

  @override
  String get attachPickImage => 'Upload image';

  @override
  String get attachPickImageHint => 'From your gallery · goes on top';

  @override
  String get attachPickFile => 'Upload file';

  @override
  String get attachPickFileHint => 'PDF · goes on top';

  @override
  String get attachUrl => 'Load URL';

  @override
  String get attachUrlHint => 'A web page · goes on top';

  @override
  String get imagePreparing => 'Preparing image…';

  @override
  String get imagePreparingCancel => 'Cancel';

  @override
  String get attachmentPhoto => 'Photo';

  @override
  String get attachmentImage => 'Image';

  @override
  String a11yWithPhoto(String text) {
    return '$text. With photo';
  }

  @override
  String a11yWithImage(String text) {
    return '$text. With image';
  }

  @override
  String get a11yPhotoAdded => 'Photo added';

  @override
  String get a11yImageAdded => 'Image added';

  @override
  String get a11yAttachmentRemoved => 'Attachment removed';

  @override
  String get editorAttachmentPlaceholder => 'Add some text (optional)';

  @override
  String get editorRemoveAttachment => 'Remove attachment';

  @override
  String get errImageType =>
      'This image type isn\'t supported. Try a JPEG, PNG or HEIC photo.';

  @override
  String errImageTooBig(int max) {
    return 'The image is too large (max $max MB).';
  }

  @override
  String errImageTooManyPixels(int max) {
    return 'The image resolution is too high (max $max megapixels).';
  }

  @override
  String get errImageUnreadable =>
      'We couldn\'t read this image. Try another one.';

  @override
  String get errNoCamera => 'There\'s no camera app available.';

  @override
  String get attachmentMissing => 'Attachment unavailable';

  @override
  String a11yAttachmentMissing(String text) {
    return '$text. Attachment unavailable';
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
  String get pdfPreparing => 'Preparing PDF…';

  @override
  String get pdfPreparingCancel => 'Cancel';

  @override
  String pdfPageA11y(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get pdfNextPage => 'Next page';

  @override
  String get pdfPrevPage => 'Previous page';

  @override
  String get pdfZoomIn => 'Zoom in';

  @override
  String get pdfZoomOut => 'Zoom out';

  @override
  String get pdfZoomFit => 'Fit to width';

  @override
  String a11yWithPdf(String text, String name, String size) {
    return '$text. With PDF, $name, $size';
  }

  @override
  String a11yPdfOnly(String name, String size) {
    return '$name. PDF, $size';
  }

  @override
  String a11yRowWithPdf(String text) {
    return '$text. With PDF';
  }

  @override
  String a11yRowPdfOnly(String name) {
    return '$name. PDF';
  }

  @override
  String a11yZoomLevel(int percent) {
    return 'Zoom $percent%';
  }

  @override
  String pdfLinkWeb(String host) {
    return 'Link to $host';
  }

  @override
  String pdfLinkPage(int page) {
    return 'Link to page $page';
  }

  @override
  String pdfLinkApp(String target) {
    return 'Link to $target';
  }

  @override
  String get a11yPdfAdded => 'PDF added';

  @override
  String get errPdfType => 'Only PDF files can be uploaded.';

  @override
  String errPdfTooBig(int max) {
    return 'The PDF is too large (max $max MB).';
  }

  @override
  String errPdfTooManyPages(int max) {
    return 'The PDF has too many pages (max $max).';
  }

  @override
  String get errPdfProtected => 'This PDF is password-protected.';

  @override
  String get errPdfUnreadable => 'We couldn\'t read this PDF.';

  @override
  String get errNoAppForLink => 'There\'s no app to open this link.';

  @override
  String openInBrowserConfirm(String host) {
    return 'Open $host in the browser?';
  }

  @override
  String openInAppConfirm(String target) {
    return 'Open $target with another app?';
  }

  @override
  String get linkConfirmOpen => 'Open';

  @override
  String get linkConfirmCancel => 'Cancel';

  @override
  String get urlSheetTitle => 'Load URL';

  @override
  String get urlPlaceholder => 'https://';

  @override
  String get urlHelp => 'It opens as a task, on top.';

  @override
  String get urlOpen => 'Open';

  @override
  String get urlErrEmpty => 'Enter a web address.';

  @override
  String get urlErrScheme =>
      'Only web addresses (http or https) are supported.';

  @override
  String get urlErrInvalid => 'That address doesn\'t look valid.';

  @override
  String get urlNeedsConnection => 'You need a connection to view this page.';

  @override
  String get urlInsecure =>
      'This page doesn\'t use a secure connection. Open it in the browser.';

  @override
  String urlLoadFailed(String reason) {
    return 'Couldn\'t load the page ($reason).';
  }

  @override
  String get urlReasonCertificate => 'invalid certificate';

  @override
  String get urlNotAPage =>
      'This address isn\'t a web page. Open it in the browser.';

  @override
  String urlRedirected(String host) {
    return 'This address took you to $host.';
  }

  @override
  String get urlOpenInBrowser => 'Open in browser';

  @override
  String get urlLoadingA11y => 'Loading page';

  @override
  String urlA11yBar(String host) {
    return 'Web page from $host';
  }

  @override
  String get attachmentWeb => 'WEB';

  @override
  String a11yRowWeb(String host) {
    return '$host. Web page';
  }

  @override
  String get urlOpenPageWeb => 'Open page ↗';
}
