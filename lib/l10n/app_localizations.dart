import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @problemInitializing.
  ///
  /// In en, this message translates to:
  /// **'Problem initializing AndSafe'**
  String get problemInitializing;

  /// No description provided for @setupPassword.
  ///
  /// In en, this message translates to:
  /// **'Setup encryption password'**
  String get setupPassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password for encrypting your notes'**
  String get enterPassword;

  /// No description provided for @enterSamePasswordAgain.
  ///
  /// In en, this message translates to:
  /// **'Enter the same password again for verification'**
  String get enterSamePasswordAgain;

  /// No description provided for @passwordCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty'**
  String get passwordCannotBeEmpty;

  /// No description provided for @twoPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The two passwords do not match'**
  String get twoPasswordsDoNotMatch;

  /// No description provided for @generatingEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Generating encryption key...'**
  String get generatingEncryptionKey;

  /// No description provided for @failedGeneratingEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate encryption key'**
  String get failedGeneratingEncryptionKey;

  /// No description provided for @saveSetupPassword.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveSetupPassword;

  /// No description provided for @problemLoadingNotes.
  ///
  /// In en, this message translates to:
  /// **'Problem loading notes'**
  String get problemLoadingNotes;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @changeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get changeSettingsTitle;

  /// No description provided for @themeSetting.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSetting;

  /// No description provided for @swipeToDeleteSetting.
  ///
  /// In en, this message translates to:
  /// **'Swipe to delete note'**
  String get swipeToDeleteSetting;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @currentPasswordCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Current password cannot be empty'**
  String get currentPasswordCannotBeEmpty;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @newPasswordCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'New password cannot be empty'**
  String get newPasswordCannotBeEmpty;

  /// No description provided for @newPassword2.
  ///
  /// In en, this message translates to:
  /// **'Enter the new password again'**
  String get newPassword2;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The two new passwords do not match'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @failedToChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to change password'**
  String get failedToChangePassword;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changePasswordButton;

  /// No description provided for @reEncrypting.
  ///
  /// In en, this message translates to:
  /// **'Re-encrypting...'**
  String get reEncrypting;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @passwordNotChanged.
  ///
  /// In en, this message translates to:
  /// **'Password not changed'**
  String get passwordNotChanged;

  /// No description provided for @importNotes.
  ///
  /// In en, this message translates to:
  /// **'Import notes'**
  String get importNotes;

  /// No description provided for @importNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Load previously exported notes'**
  String get importNotesHint;

  /// No description provided for @exportNotes.
  ///
  /// In en, this message translates to:
  /// **'Export notes'**
  String get exportNotes;

  /// No description provided for @exportNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Backup notes to a file'**
  String get exportNotesHint;

  /// No description provided for @failedToExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export'**
  String get failedToExport;

  /// No description provided for @exportedToFile.
  ///
  /// In en, this message translates to:
  /// **'Exported to file '**
  String get exportedToFile;

  /// No description provided for @visitWebSite.
  ///
  /// In en, this message translates to:
  /// **'Visit web site'**
  String get visitWebSite;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @goingToDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Going to delete note...'**
  String get goingToDeleteNote;

  /// No description provided for @enterYourPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// No description provided for @passwordToDecryptYourNotes.
  ///
  /// In en, this message translates to:
  /// **'Password to decrypt your notes'**
  String get passwordToDecryptYourNotes;

  /// No description provided for @failedToVerifyPassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify password'**
  String get failedToVerifyPassword;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search title...'**
  String get searchTitle;

  /// No description provided for @importNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Import notes'**
  String get importNotesTitle;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifying;

  /// No description provided for @importing.
  ///
  /// In en, this message translates to:
  /// **'Importing...'**
  String get importing;

  /// No description provided for @passwordToDecryptImportedNotes.
  ///
  /// In en, this message translates to:
  /// **'Password to decrypt imported notes'**
  String get passwordToDecryptImportedNotes;

  /// No description provided for @importPasswordCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty'**
  String get importPasswordCannotBeEmpty;

  /// No description provided for @clickToChooseImportFile.
  ///
  /// In en, this message translates to:
  /// **'Click to choose the import file'**
  String get clickToChooseImportFile;

  /// No description provided for @pleaseSelectFileToImport.
  ///
  /// In en, this message translates to:
  /// **'Please select a file to import'**
  String get pleaseSelectFileToImport;

  /// No description provided for @incorrectImportPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect import password'**
  String get incorrectImportPassword;

  /// No description provided for @failedToImport.
  ///
  /// In en, this message translates to:
  /// **'Failed to import notes'**
  String get failedToImport;

  /// No description provided for @importButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importButton;

  /// No description provided for @createNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Create note'**
  String get createNoteTitle;

  /// No description provided for @editNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get editNoteTitle;

  /// No description provided for @errorLoadingNote.
  ///
  /// In en, this message translates to:
  /// **'Problem loading the note'**
  String get errorLoadingNote;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'Title of your note (not encrypted)'**
  String get titleHint;

  /// No description provided for @titleCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter some text for the title'**
  String get titleCannotBeEmpty;

  /// No description provided for @textToBeEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Notes to be encrypted'**
  String get textToBeEncrypted;

  /// No description provided for @failedToSaveTheNote.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the note'**
  String get failedToSaveTheNote;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitApp;

  /// No description provided for @upgradingData.
  ///
  /// In en, this message translates to:
  /// **'Upgrading your data'**
  String get upgradingData;

  /// No description provided for @doNotCloseApp.
  ///
  /// In en, this message translates to:
  /// **'Do not close the app'**
  String get doNotCloseApp;

  /// No description provided for @migratingNote.
  ///
  /// In en, this message translates to:
  /// **'Migrating note {current} of {total}'**
  String migratingNote(int current, int total);

  /// No description provided for @fingerprintUnlockSetting.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unlock'**
  String get fingerprintUnlockSetting;

  /// No description provided for @enableFingerprintPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enable fingerprint unlock?'**
  String get enableFingerprintPrompt;

  /// No description provided for @enableFingerprintDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint to unlock AndSafe without typing your password each time.'**
  String get enableFingerprintDescription;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @fingerprintReason.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock AndSafe'**
  String get fingerprintReason;

  /// No description provided for @fingerprintEnabled.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unlock enabled'**
  String get fingerprintEnabled;

  /// No description provided for @fingerprintDisabled.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint unlock disabled'**
  String get fingerprintDisabled;

  /// No description provided for @fingerprintNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint not available on this device'**
  String get fingerprintNotAvailable;

  /// No description provided for @fingerprintFailed.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint authentication failed'**
  String get fingerprintFailed;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
