import 'package:intl/intl.dart' as intl;

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
  String get commonPressBackAgain => 'App: Press back again to exit';

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
  String get errorSessionExpired => 'Session expired, please sign in again';

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
  String get dashboardRecheck => 'Check connection again';

  @override
  String dashboardPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending',
      one: '1 pending',
    );
    return '$_temp0';
  }

  @override
  String get tomogramModuleTitle => 'Tomogram';

  @override
  String get tomogramModuleSubtitle => 'Upload skin photos to a patient record';

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
  String get homeRemoveRecent => 'Remove from recent';

  @override
  String homePatientError(String message) {
    return 'Patient: $message';
  }

  @override
  String get tomogramAddPhoto => 'Add photo';

  @override
  String get tomogramChooseGallery => 'Choose from Gallery';

  @override
  String get tomogramTakePhoto => 'Take Photo';

  @override
  String get tomogramDescription => 'Description';

  @override
  String tomogramSameAsPrevious(String text) {
    return 'Same as previous photo: $text';
  }

  @override
  String get tomogramEmptyTitle => 'There is no tomogram added.';

  @override
  String get tomogramEmptyBody => 'You can add tomogram photos with the \'+\' button. They will appear here as you add them.';

  @override
  String get tomogramUpload => 'Upload';

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
  String get tomogramHistoryTitle => 'Already uploaded';

  @override
  String tomogramHistoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String tomogramHistoryLast(String date) {
    return 'Last $date';
  }

  @override
  String tomogramHistoryMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get tomogramHistoryError => 'Could not load history';

  @override
  String get tomogramHistoryNoNarration => 'No description';

  @override
  String get tomogramSuggestions => 'Suggestions';

  @override
  String get tomogramQueued => 'Saved offline. It will upload when the server is reachable.';

  @override
  String tomogramPendingLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos waiting to upload',
      one: '1 photo waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String get captureDone => 'Done';

  @override
  String get captureShutter => 'Take photo';

  @override
  String captureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'No photos yet',
    );
    return '$_temp0';
  }

  @override
  String get captureTorchOn => 'Turn torch on';

  @override
  String get captureTorchOff => 'Turn torch off';

  @override
  String get captureRemoveTitle => 'Remove this photo?';

  @override
  String get captureRemoveBody => 'It has not been added yet and will be deleted.';

  @override
  String get captureRemove => 'Remove';

  @override
  String get captureErrorTitle => 'Camera unavailable';

  @override
  String get captureErrorBody => 'Could not start the camera. Check that no other app is using it and try again.';

  @override
  String get captureRetry => 'Try again';

  @override
  String get captureFailed => 'Could not take the photo. Try again.';

  @override
  String captureLimit(int limit) {
    return 'Up to $limit photos per session';
  }

  @override
  String get captureAddLabel => 'Add a label';

  @override
  String get captureLabelNext => 'Label next photos';

  @override
  String captureNextPhotos(String label) {
    return 'Next photos: $label';
  }

  @override
  String get captureLabelTitle => 'Label these photos';

  @override
  String get captureLabelHint => 'e.g. Left forearm';

  @override
  String get captureLabelUse => 'Use label';

  @override
  String get captureLabelClear => 'Clear label';

  @override
  String captureLabelled(String label) {
    return 'Labelled $label';
  }

  @override
  String get queueTitle => 'Pending uploads';

  @override
  String get queueRetry => 'Retry now';

  @override
  String get queueDiscard => 'Discard';

  @override
  String get queueDiscardTitle => 'Discard pending upload?';

  @override
  String get queueDiscardBody => 'The photos will be deleted from this device.';

  @override
  String queueFailedLine(int attempts, String error) {
    return 'Failed $attempts times: $error';
  }

  @override
  String get permissionTitleBar => 'Permission';

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
  String get settingsGroupAppearance => 'Appearance';

  @override
  String get settingsGroupHelp => 'Help';

  @override
  String get settingsChangeUrl => 'Change Installation URL';

  @override
  String get settingsChangeUrlBody => 'Re-configure the connection URL of your self-hosted DeCare HMS. This process will log you out of the app.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsSignedInAs => 'Signed in as';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutTitle => 'Sign out?';

  @override
  String get settingsSignOutBody => 'You will need to sign in again.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsTabHome => 'Home';

  @override
  String get settingsTabSettings => 'Settings';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceSelected => 'Selected';

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
