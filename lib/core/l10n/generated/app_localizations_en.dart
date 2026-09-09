import 'app_localizations.dart';

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DeCare HMS';

  @override
  String get commonHeader => 'DeCare HMS';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonPleaseWait => 'Please wait';

  @override
  String get commonConfirmTitle => 'Are you sure?';

  @override
  String get commonConfirmNo => 'No, I\'m Not';

  @override
  String get commonConfirmYes => 'Yes, I am';

  @override
  String get commonPressBackAgain => 'App: Press back again to exit';

  @override
  String get commonCannotGoBack => 'Can\'t go back';

  @override
  String get errorCannotConnect => 'Could not reach the server';

  @override
  String get errorTimeout => 'The server took too long to respond';

  @override
  String get errorUnauthorized => 'Session expired';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorRejected => 'Request rejected';

  @override
  String get errorBadData => 'Unexpected response from server';

  @override
  String get errorInvalidCredentials => 'Invalid username or password';

  @override
  String get configureUrlTitle => 'Installation URL';

  @override
  String get configureUrlHeading => 'Connect to your server';

  @override
  String get configureUrlBody => 'Input server URL of your self-hosted DeCare-HMS installation.';

  @override
  String get configureUrlPlaceholder => 'Eg: http://your-hms-server-url.com';

  @override
  String get configureUrlConnect => 'Connect';

  @override
  String get configureUrlInvalid => 'Invalid URL: Please provide a valid URL';

  @override
  String get configureUrlInvalidField => 'Enter a valid server address';

  @override
  String configureUrlHostError(String message) {
    return 'Host: $message';
  }

  @override
  String get loginHeading => 'Sign in';

  @override
  String get loginUsername => 'Username';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginSignIn => 'Sign In';

  @override
  String get loginChangeUrl => 'Change server';

  @override
  String loginError(String message) {
    return 'Login: $message';
  }

  @override
  String get dashboardModules => 'Modules';

  @override
  String get dashboardMorePlaceholder => 'More modules coming';

  @override
  String get dashboardChecking => 'Checking…';

  @override
  String get dashboardConnected => 'Connected';

  @override
  String get dashboardUnreachable => 'Server unreachable';

  @override
  String get tomogramModuleTitle => 'Tomogram';

  @override
  String get tomogramModuleSubtitle => 'Upload skin photos to a patient record';

  @override
  String tomogramRecentBadge(int count) {
    return '$count recent';
  }

  @override
  String get homeRecentSearches => 'Recent Searches:';

  @override
  String get homeClearAll => 'clear all';

  @override
  String homeRecentRow(String name, int opid) {
    return '$name, $opid';
  }

  @override
  String get homeEmptyTitle => 'There is no patient selected.';

  @override
  String get homeEmptyBody => 'Once you choose a patient, they\'ll appear here.';

  @override
  String get homeSearchPlaceholder => 'Enter OP Number';

  @override
  String get homeGo => 'Go';

  @override
  String get homeRecent => 'Recent';

  @override
  String get homeClear => 'Clear';

  @override
  String get homeFetchingPatient => 'Fetching Patient';

  @override
  String homePatientError(String message) {
    return 'Patient: $message';
  }

  @override
  String get tomogramChooseGallery => 'Choose from Gallery';

  @override
  String get tomogramTakePhoto => 'Take Photo';

  @override
  String get tomogramDescription => 'Description';

  @override
  String get tomogramOpNumber => 'Op Number';

  @override
  String get tomogramEmptyTitle => 'There is no tomogram added.';

  @override
  String get tomogramEmptyBody => 'You can add tomogram details using the \'+\' button at top-right, they\'ll appear here as added.';

  @override
  String get tomogramUpload => 'Upload';

  @override
  String get tomogramUploading => 'Uploading';

  @override
  String get tomogramUploaded => 'Tomogram: Uploaded';

  @override
  String tomogramUploadError(String message) {
    return 'Tomogram Upload: $message';
  }

  @override
  String get tomogramOnlyJpeg => 'Tomogram: Only JPEG images are supported';

  @override
  String tomogramPickLimit(int limit) {
    return 'Tomogram: Only $limit images per pick';
  }

  @override
  String get tomogramDiscardTitle => 'Discard photos?';

  @override
  String get tomogramDiscardBody => 'The photos you added will be removed.';

  @override
  String tomogramCounter(int index, int total) {
    return '$index of $total';
  }

  @override
  String permissionTitle(String name) {
    return 'Grant Permission to access $name';
  }

  @override
  String get permissionBody => 'It looks like you have turned off permissions required for this feature. It can be enabled under Phone Settings > Apps > HMS > Permissions';

  @override
  String get permissionGrant => 'Grant Permission';

  @override
  String get permissionCamera => 'Camera';

  @override
  String get permissionPhotos => 'Files and media';

  @override
  String get settingsGroupServer => 'Server';

  @override
  String get settingsGroupAccount => 'Account';

  @override
  String get settingsGroupHelp => 'Help';

  @override
  String get settingsChangeUrl => 'Change Installation URL';

  @override
  String get settingsChangeUrlBody => 'Re-configure the connection URL of your self-hosted DeCare HMS. This process will log you out of the app.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSignOutBody => 'You will need to sign in again.';

  @override
  String get settingsTabHome => 'Home';

  @override
  String get settingsTabSettings => 'Settings';

  @override
  String get aboutHeader => 'About';

  @override
  String get aboutTerms => 'Terms of Service';

  @override
  String get aboutUs => 'About Us';

  @override
  String get aboutContact => 'Contact Us';

  @override
  String get aboutPhone => '+91 80863 58930';

  @override
  String get aboutWebsite => 'website (decare.team)';

  @override
  String aboutCopyright(int year) {
    return 'DecareHMS is copyrighted © $year by Decare Software Solution. All rights reserved.';
  }

  @override
  String get aboutLicense => 'DecareHMS is licensed to Cutis Hospital as a part of the DeCare\'s Hospital ERP software, and its support is tied to the support license for the ERP. Support for DeCareHMS app is available only as long as the ERP\'s support license is active.';

  @override
  String get aboutParaIntro => 'Decare Software Solution is a company that specializes in developing innovative and user-friendly software solutions for the health care sector. We have a team of experienced and qualified software engineers, designers, and testers who are passionate about creating products that can improve the quality and efficiency of health care services.';

  @override
  String get aboutParaTwo => 'Our mobile app, DecareHMS, is one of our flagship products that aims to help clinics diagnose and treat skin diseases more effectively. DecareHMS is a simple and convenient app that allows clinics to upload skin disease images to their DeCare\'s Hospital ERP software with just a few clicks. The app also integrates seamlessly with the ERP software (that manage their patient records, inventory, billing, appointments, etc in one place). The app provides an easy-to-use interface for doctors to review the images and make accurate diagnoses.';

  @override
  String get aboutParaThree => 'DecareHMS is designed to be compatible with all major mobile platforms and devices. The app is secure, fast, and easy to use. With DecareHMS, clinics can save time and money, enhance their reputation, and provide better care for their patients.';

  @override
  String get aboutParaFinale => 'If you want to learn more about our company or products, please visit our website or contact us. We would be happy to answer any questions you may have.';
}
