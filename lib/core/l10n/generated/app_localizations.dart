import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DeCare HMS'**
  String get appTitle;

  /// No description provided for @commonHeader.
  ///
  /// In en, this message translates to:
  /// **'DeCare HMS'**
  String get commonHeader;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonDiscard;

  /// No description provided for @commonPressBackAgain.
  ///
  /// In en, this message translates to:
  /// **'App: Press back again to exit'**
  String get commonPressBackAgain;

  /// No description provided for @errorCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the server'**
  String get errorCannotConnect;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to respond'**
  String get errorTimeout;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Session expired'**
  String get errorUnauthorized;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get errorServer;

  /// No description provided for @errorRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get errorRejected;

  /// No description provided for @errorBadData.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response from server'**
  String get errorBadData;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid username or password'**
  String get errorInvalidCredentials;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired, please sign in again'**
  String get errorSessionExpired;

  /// No description provided for @configureUrlHeading.
  ///
  /// In en, this message translates to:
  /// **'Connect to your server'**
  String get configureUrlHeading;

  /// No description provided for @configureUrlBody.
  ///
  /// In en, this message translates to:
  /// **'Input server URL of your self-hosted DeCare-HMS installation.'**
  String get configureUrlBody;

  /// No description provided for @configureUrlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Eg: http://your-hms-server-url.com'**
  String get configureUrlPlaceholder;

  /// No description provided for @configureUrlConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get configureUrlConnect;

  /// No description provided for @configureUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid URL: Please provide a valid URL'**
  String get configureUrlInvalid;

  /// No description provided for @configureUrlInvalidField.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid server address'**
  String get configureUrlInvalidField;

  /// No description provided for @configureUrlHostError.
  ///
  /// In en, this message translates to:
  /// **'Host: {message}'**
  String configureUrlHostError(String message);

  /// No description provided for @loginHeading.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginHeading;

  /// No description provided for @loginUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get loginUsername;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginChangeUrl.
  ///
  /// In en, this message translates to:
  /// **'Change server'**
  String get loginChangeUrl;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login: {message}'**
  String loginError(String message);

  /// No description provided for @dashboardModules.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get dashboardModules;

  /// No description provided for @dashboardMorePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'More modules coming'**
  String get dashboardMorePlaceholder;

  /// No description provided for @dashboardChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get dashboardChecking;

  /// No description provided for @dashboardConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get dashboardConnected;

  /// No description provided for @dashboardUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable'**
  String get dashboardUnreachable;

  /// No description provided for @tomogramModuleTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomogram'**
  String get tomogramModuleTitle;

  /// No description provided for @tomogramModuleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload skin photos to a patient record'**
  String get tomogramModuleSubtitle;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'There is no patient selected.'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Once you choose a patient, they\'ll appear here.'**
  String get homeEmptyBody;

  /// No description provided for @homeSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter OP Number'**
  String get homeSearchPlaceholder;

  /// No description provided for @homeGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get homeGo;

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get homeRecent;

  /// No description provided for @homeClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get homeClear;

  /// No description provided for @homeRemoveRecent.
  ///
  /// In en, this message translates to:
  /// **'Remove from recent'**
  String get homeRemoveRecent;

  /// No description provided for @homePatientError.
  ///
  /// In en, this message translates to:
  /// **'Patient: {message}'**
  String homePatientError(String message);

  /// No description provided for @tomogramAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get tomogramAddPhoto;

  /// No description provided for @tomogramChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get tomogramChooseGallery;

  /// No description provided for @tomogramTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get tomogramTakePhoto;

  /// No description provided for @tomogramDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get tomogramDescription;

  /// No description provided for @tomogramEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'There is no tomogram added.'**
  String get tomogramEmptyTitle;

  /// No description provided for @tomogramEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You can add tomogram photos with the \'+\' button. They will appear here as you add them.'**
  String get tomogramEmptyBody;

  /// No description provided for @tomogramUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get tomogramUpload;

  /// No description provided for @tomogramUploaded.
  ///
  /// In en, this message translates to:
  /// **'Tomogram: Uploaded'**
  String get tomogramUploaded;

  /// No description provided for @tomogramUploadError.
  ///
  /// In en, this message translates to:
  /// **'Tomogram Upload: {message}'**
  String tomogramUploadError(String message);

  /// No description provided for @tomogramOnlyJpeg.
  ///
  /// In en, this message translates to:
  /// **'Tomogram: Only JPEG images are supported'**
  String get tomogramOnlyJpeg;

  /// No description provided for @tomogramPickLimit.
  ///
  /// In en, this message translates to:
  /// **'Tomogram: Only {limit} images per pick'**
  String tomogramPickLimit(int limit);

  /// No description provided for @tomogramDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard photos?'**
  String get tomogramDiscardTitle;

  /// No description provided for @tomogramDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The photos you added will be removed.'**
  String get tomogramDiscardBody;

  /// No description provided for @tomogramCounter.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String tomogramCounter(int index, int total);

  /// No description provided for @tomogramHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Already uploaded'**
  String get tomogramHistoryTitle;

  /// No description provided for @tomogramHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 set} other{{count} sets}}'**
  String tomogramHistoryCount(int count);

  /// No description provided for @tomogramHistoryLast.
  ///
  /// In en, this message translates to:
  /// **'Last {date}'**
  String tomogramHistoryLast(String date);

  /// No description provided for @tomogramHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get tomogramHistoryError;

  /// No description provided for @tomogramHistoryNoNarration.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get tomogramHistoryNoNarration;

  /// No description provided for @permissionTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get permissionTitleBar;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission to access {name}'**
  String permissionTitle(String name);

  /// No description provided for @permissionBody.
  ///
  /// In en, this message translates to:
  /// **'It looks like you have turned off permissions required for this feature. It can be enabled under Phone Settings > Apps > HMS > Permissions'**
  String get permissionBody;

  /// No description provided for @permissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant Permission'**
  String get permissionGrant;

  /// No description provided for @permissionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permissionCamera;

  /// No description provided for @permissionPhotos.
  ///
  /// In en, this message translates to:
  /// **'Files and media'**
  String get permissionPhotos;

  /// No description provided for @settingsGroupServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get settingsGroupServer;

  /// No description provided for @settingsGroupAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsGroupAccount;

  /// No description provided for @settingsGroupHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsGroupHelp;

  /// No description provided for @settingsChangeUrl.
  ///
  /// In en, this message translates to:
  /// **'Change Installation URL'**
  String get settingsChangeUrl;

  /// No description provided for @settingsChangeUrlBody.
  ///
  /// In en, this message translates to:
  /// **'Re-configure the connection URL of your self-hosted DeCare HMS. This process will log you out of the app.'**
  String get settingsChangeUrlBody;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get settingsSignedInAs;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again.'**
  String get settingsSignOutBody;

  /// No description provided for @settingsTabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get settingsTabHome;

  /// No description provided for @settingsTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTabSettings;

  /// No description provided for @aboutHeader.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutHeader;

  /// No description provided for @aboutTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get aboutTerms;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get aboutContact;

  /// No description provided for @aboutPhone.
  ///
  /// In en, this message translates to:
  /// **'+91 80863 58930'**
  String get aboutPhone;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'website (decare.team)'**
  String get aboutWebsite;

  /// No description provided for @aboutCopyright.
  ///
  /// In en, this message translates to:
  /// **'DecareHMS is copyrighted © {year} by Decare Software Solution. All rights reserved.'**
  String aboutCopyright(int year);

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'DecareHMS is licensed to Cutis Hospital as a part of the DeCare\'s Hospital ERP software, and its support is tied to the support license for the ERP. Support for DeCareHMS app is available only as long as the ERP\'s support license is active.'**
  String get aboutLicense;

  /// No description provided for @aboutParaIntro.
  ///
  /// In en, this message translates to:
  /// **'Decare Software Solution is a company that specializes in developing innovative and user-friendly software solutions for the health care sector. We have a team of experienced and qualified software engineers, designers, and testers who are passionate about creating products that can improve the quality and efficiency of health care services.'**
  String get aboutParaIntro;

  /// No description provided for @aboutParaTwo.
  ///
  /// In en, this message translates to:
  /// **'Our mobile app, DecareHMS, is one of our flagship products that aims to help clinics diagnose and treat skin diseases more effectively. DecareHMS is a simple and convenient app that allows clinics to upload skin disease images to their DeCare\'s Hospital ERP software with just a few clicks. The app also integrates seamlessly with the ERP software (that manage their patient records, inventory, billing, appointments, etc in one place). The app provides an easy-to-use interface for doctors to review the images and make accurate diagnoses.'**
  String get aboutParaTwo;

  /// No description provided for @aboutParaThree.
  ///
  /// In en, this message translates to:
  /// **'DecareHMS is designed to be compatible with all major mobile platforms and devices. The app is secure, fast, and easy to use. With DecareHMS, clinics can save time and money, enhance their reputation, and provide better care for their patients.'**
  String get aboutParaThree;

  /// No description provided for @aboutParaFinale.
  ///
  /// In en, this message translates to:
  /// **'If you want to learn more about our company or products, please visit our website or contact us. We would be happy to answer any questions you may have.'**
  String get aboutParaFinale;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
