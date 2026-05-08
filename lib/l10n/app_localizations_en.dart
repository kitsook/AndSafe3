// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get problemInitializing => 'Problem initializing AndSafe';

  @override
  String get setupPassword => 'Setup encryption password';

  @override
  String get enterPassword => 'Enter a password for encrypting your notes';

  @override
  String get enterSamePasswordAgain =>
      'Enter the same password again for verification';

  @override
  String get passwordCannotBeEmpty => 'Password cannot be empty';

  @override
  String get twoPasswordsDoNotMatch => 'The two passwords do not match';

  @override
  String get generatingEncryptionKey => 'Generating encryption key...';

  @override
  String get failedGeneratingEncryptionKey =>
      'Failed to generate encryption key';

  @override
  String get saveSetupPassword => 'Save';

  @override
  String get problemLoadingNotes => 'Problem loading notes';

  @override
  String get loading => 'Loading...';

  @override
  String get settings => 'Settings';

  @override
  String get changeSettingsTitle => 'Settings';

  @override
  String get themeSetting => 'Theme';

  @override
  String get swipeToDeleteSetting => 'Swipe to delete note';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get currentPasswordCannotBeEmpty => 'Current password cannot be empty';

  @override
  String get newPassword => 'New Password';

  @override
  String get newPasswordCannotBeEmpty => 'New password cannot be empty';

  @override
  String get newPassword2 => 'Enter the new password again';

  @override
  String get newPasswordsDoNotMatch => 'The two new passwords do not match';

  @override
  String get failedToChangePassword => 'Failed to change password';

  @override
  String get changePasswordButton => 'Change';

  @override
  String get reEncrypting => 'Re-encrypting...';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get passwordNotChanged => 'Password not changed';

  @override
  String get importNotes => 'Import notes';

  @override
  String get importNotesHint => 'Load previously exported notes';

  @override
  String get exportNotes => 'Export notes';

  @override
  String get exportNotesHint => 'Backup notes to a file';

  @override
  String get failedToExport => 'Failed to export';

  @override
  String get exportedToFile => 'Exported to file ';

  @override
  String get visitWebSite => 'Visit web site';

  @override
  String get undo => 'Undo';

  @override
  String get goingToDeleteNote => 'Going to delete note...';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get passwordToDecryptYourNotes => 'Password to decrypt your notes';

  @override
  String get failedToVerifyPassword => 'Failed to verify password';

  @override
  String get searchTitle => 'Search title...';

  @override
  String get importNotesTitle => 'Import notes';

  @override
  String get verifying => 'Verifying...';

  @override
  String get importing => 'Importing...';

  @override
  String get passwordToDecryptImportedNotes =>
      'Password to decrypt imported notes';

  @override
  String get importPasswordCannotBeEmpty => 'Password cannot be empty';

  @override
  String get clickToChooseImportFile => 'Click to choose the import file';

  @override
  String get pleaseSelectFileToImport => 'Please select a file to import';

  @override
  String get incorrectImportPassword => 'Incorrect import password';

  @override
  String get failedToImport => 'Failed to import notes';

  @override
  String get importButton => 'Import';

  @override
  String get createNoteTitle => 'Create note';

  @override
  String get editNoteTitle => 'Edit note';

  @override
  String get errorLoadingNote => 'Problem loading the note';

  @override
  String get titleHint => 'Title of your note (not encrypted)';

  @override
  String get titleCannotBeEmpty => 'Please enter some text for the title';

  @override
  String get textToBeEncrypted => 'Notes to be encrypted';

  @override
  String get failedToSaveTheNote => 'Failed to save the note';

  @override
  String get saveButton => 'Save';

  @override
  String get exitApp => 'Exit';
}
