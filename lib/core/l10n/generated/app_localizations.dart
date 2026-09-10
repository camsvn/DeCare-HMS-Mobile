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

  /// No description provided for @dashboardRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check connection again'**
  String get dashboardRecheck;

  /// No description provided for @dashboardPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending} other{{count} pending}}'**
  String dashboardPending(int count);

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

  /// No description provided for @tomogramRemovePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from this upload.'**
  String get tomogramRemovePhotoBody;

  /// No description provided for @tomogramSameAsPrevious.
  ///
  /// In en, this message translates to:
  /// **'Same as previous photo: {text}'**
  String tomogramSameAsPrevious(String text);

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

  /// No description provided for @tomogramHistoryMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{and 1 more} other{and {count} more}}'**
  String tomogramHistoryMore(int count);

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

  /// No description provided for @tomogramSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get tomogramSuggestions;

  /// No description provided for @tomogramQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved offline. It will upload when the server is reachable.'**
  String get tomogramQueued;

  /// No description provided for @tomogramPendingLine.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo waiting to upload} other{{count} photos waiting to upload}}'**
  String tomogramPendingLine(int count);

  /// No description provided for @captureDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get captureDone;

  /// No description provided for @captureShutter.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get captureShutter;

  /// No description provided for @captureCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos yet} =1{1 photo} other{{count} photos}}'**
  String captureCount(int count);

  /// No description provided for @captureTorchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn torch on'**
  String get captureTorchOn;

  /// No description provided for @captureTorchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn torch off'**
  String get captureTorchOff;

  /// No description provided for @captureRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this photo?'**
  String get captureRemoveTitle;

  /// No description provided for @captureRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'It has not been added yet and will be deleted.'**
  String get captureRemoveBody;

  /// No description provided for @captureRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get captureRemove;

  /// No description provided for @captureErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get captureErrorTitle;

  /// No description provided for @captureErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Could not start the camera. Check that no other app is using it and try again.'**
  String get captureErrorBody;

  /// No description provided for @captureRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get captureRetry;

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not take the photo. Try again.'**
  String get captureFailed;

  /// No description provided for @captureLimit.
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} photos per session'**
  String captureLimit(int limit);

  /// No description provided for @captureAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add a label'**
  String get captureAddLabel;

  /// No description provided for @captureLabelNext.
  ///
  /// In en, this message translates to:
  /// **'Label next photos'**
  String get captureLabelNext;

  /// No description provided for @captureNextPhotos.
  ///
  /// In en, this message translates to:
  /// **'Next photos: {label}'**
  String captureNextPhotos(String label);

  /// No description provided for @captureLabelTitle.
  ///
  /// In en, this message translates to:
  /// **'Label these photos'**
  String get captureLabelTitle;

  /// No description provided for @captureLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Left forearm'**
  String get captureLabelHint;

  /// No description provided for @captureLabelUse.
  ///
  /// In en, this message translates to:
  /// **'Use label'**
  String get captureLabelUse;

  /// No description provided for @captureLabelClear.
  ///
  /// In en, this message translates to:
  /// **'Clear label'**
  String get captureLabelClear;

  /// No description provided for @captureZoomLevel.
  ///
  /// In en, this message translates to:
  /// **'{level}×'**
  String captureZoomLevel(String level);

  /// No description provided for @captureGridOn.
  ///
  /// In en, this message translates to:
  /// **'Show grid'**
  String get captureGridOn;

  /// No description provided for @captureGridOff.
  ///
  /// In en, this message translates to:
  /// **'Hide grid'**
  String get captureGridOff;

  /// No description provided for @captureLabelled.
  ///
  /// In en, this message translates to:
  /// **'Labelled {label}'**
  String captureLabelled(String label);

  /// No description provided for @suggestionForgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget this suggestion?'**
  String get suggestionForgetTitle;

  /// No description provided for @suggestionForgetBody.
  ///
  /// In en, this message translates to:
  /// **'It will no longer be offered on this device.'**
  String get suggestionForgetBody;

  /// No description provided for @suggestionForget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get suggestionForget;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending uploads'**
  String get queueTitle;

  /// No description provided for @queueRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry now'**
  String get queueRetry;

  /// No description provided for @queueDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get queueDiscard;

  /// No description provided for @queueDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard pending upload?'**
  String get queueDiscardTitle;

  /// No description provided for @queueDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The photos will be deleted from this device.'**
  String get queueDiscardBody;

  /// No description provided for @queueFailedLine.
  ///
  /// In en, this message translates to:
  /// **'Failed {attempts} times: {error}'**
  String queueFailedLine(int attempts, String error);

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

  /// No description provided for @settingsGroupAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsGroupAppearance;

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

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

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

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appearanceSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get appearanceSelected;

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
