# DeCare HMS Flutter Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the DeCare HMS uploader (React Native, `E:\Projects\personal\deCare\hms\HMSUploader`) as a Flutter app in this repository with identical behaviour and API contract.

**Architecture:** Feature-first layout (`lib/features/<name>/{data,application,presentation}`) over a shared `lib/core`. Riverpod for state, go_router for navigation with a redirect that gates on saved server URL and JWT validity, Dio for HTTP. `core` never imports `features`; features talk to each other only through barrel files. Two Riverpod providers in `core` (`serverUrlProvider`, `accessTokenProvider`) are overridden in `main.dart` with feature state so `core` stays independent.

**Tech Stack:** Flutter 3.19.0 / Dart 3.3.0, flutter_riverpod 2.6, go_router 14.6, dio 5.11, shared_preferences, flutter_secure_storage, image_picker 1.0, permission_handler 11, path_provider, uuid, url_launcher, flutter_svg 2.0, flutter_localizations + ARB, mocktail, flutter_native_splash.

**Spec:** `docs/superpowers/specs/2026-09-08-flutter-port-design.md`

## Global Constraints

- SDK: Flutter 3.19.0 / Dart 3.3.0 as installed. `environment: sdk: '>=3.3.0 <4.0.0'`. Do not run `flutter upgrade`.
- Dart package name `hms_uploader`; Android applicationId and namespace `com.decare.hmsuploader`; launcher label `HMS`; version `1.0.0+1`; `minSdkVersion 21`; portrait only; cleartext HTTP allowed; `allowBackup="false"`.
- iOS bundle id `com.decare.hmsuploader`, portrait only, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSAppTransportSecurity/NSAllowsArbitraryLoads = true`. Not built in this session.
- No code generation packages (no freezed, json_serializable, riverpod_generator, build_runner). Only `flutter gen-l10n` output is generated, into `lib/core/l10n/generated/` (committed).
- `core` must not import anything under `features/`. Features import other features only via `lib/features/<name>/<name>.dart`.
- All user-visible strings live in `lib/core/l10n/app_en.arb`. No hard-coded UI copy in widgets except test files.
- API contract (verbatim): `GET /auth/healthcheck`, `POST /auth/login` JSON `{username,password}`, `GET /opregister?opid=<n>`, `POST /tomogram` multipart with `opid`, repeated `images`, `narrations[i]`. Base URL is `<serverUrl>/api`. Responses are JSend: `{status:"success",data}`, `{status:"fail",data:<message or object>}`, `{status:"error",message}`.
- Timeouts: 10 s connect/receive for JSON calls; 60 s send and receive for the upload.
- Every task ends with `flutter analyze` reporting no issues and `flutter test` green, then a commit. Run all commands from `E:\Projects\personal\deCare\hms\HMSFlutter`.
- Windows shell: use Git Bash syntax in the Bash tool. Paths with spaces must be quoted.

---

## File map

| Path | Responsibility |
|---|---|
| `pubspec.yaml`, `l10n.yaml`, `analysis_options.yaml` | project config |
| `lib/main.dart` | eager-load prefs and secure storage, build `ProviderScope` overrides, `runApp` |
| `lib/app/app.dart` | `MaterialApp.router` with theme and localization delegates |
| `lib/app/router.dart` | `GoRouter` provider, `computeRedirect`, `RouterRefreshNotifier`, route tree |
| `lib/app/app_shell.dart` | shell scaffold for the two tabs with custom `AppTabBar` |
| `lib/app/tab_bar.dart` | custom two-tab bar, hidden with keyboard |
| `lib/core/network/api_failure.dart` | sealed `ApiFailure` and `ApiFailure.from` |
| `lib/core/network/api_envelope.dart` | JSend unwrap |
| `lib/core/network/dio_client.dart` | `serverUrlProvider`, `accessTokenProvider`, `dioProvider`, `buildDio` |
| `lib/core/network/auth_interceptor.dart` | Bearer header interceptor |
| `lib/core/storage/prefs_store.dart` | `sharedPreferencesProvider` (overridden in main) |
| `lib/core/storage/secure_store.dart` | `SecureStore` wrapper + provider |
| `lib/core/utils/url_validator.dart` | regex + `normalizeServerUrl` |
| `lib/core/utils/jwt.dart` | `jwtExpiry` decode |
| `lib/core/utils/jpeg.dart` | `isJpegFile` magic-byte check |
| `lib/core/utils/temp_files.dart` | `deleteFiles` |
| `lib/core/theme/*.dart` | colors, spacing, text styles, `ThemeData` |
| `lib/core/l10n/app_en.arb` | all strings |
| `lib/core/widgets/*.dart` | shared widgets (see Task 5) |
| `lib/features/server_config/**` | URL configuration |
| `lib/features/auth/**` | login / session |
| `lib/features/patient_lookup/**` | OP search, recent searches, Home |
| `lib/features/tomogram/**` | drafts, picker, upload, Tomogram and Permission screens |
| `lib/features/settings/**` | Settings and About |
| `assets/images/` | `hms_square.png`, `hms_circle.svg`, `decare_logo.jpeg`, `installation_url.png`, `blank_canvas.svg`, `add_tomogram.svg` |
| `test/**` | mirrors `lib/` |

---

### Task 1: Scaffold the project, platform config, theme and strings

**Files:**
- Create: everything `flutter create` produces, then edit `pubspec.yaml`, `l10n.yaml`, `analysis_options.yaml`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/decare/hmsuploader/MainActivity.kt`, `ios/Runner/Info.plist`, `lib/core/l10n/app_en.arb`, `lib/core/theme/app_colors.dart`, `lib/core/theme/app_spacing.dart`, `lib/core/theme/app_text_styles.dart`, `lib/core/theme/app_theme.dart`, `lib/main.dart` (placeholder), `.gitignore` additions, `assets/images/*`.

**Interfaces:**
- Produces: `AppColors`, `AppSpacing`, `AppTextStyles`, `buildAppTheme()`, `AppLocalizations` (generated, import `package:hms_uploader/core/l10n/generated/app_localizations.dart`).

- [ ] **Step 1: Generate the project into the existing repo folder**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
flutter create --org com.decare --project-name hms_uploader --platforms android,ios --no-pub .
rm -rf test/widget_test.dart
```

- [ ] **Step 2: Replace `pubspec.yaml`**

```yaml
name: hms_uploader
description: DeCare HMS tomogram uploader.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.2
  dio: ^5.11.1
  shared_preferences: ^2.2.3
  flutter_secure_storage: ^9.2.4
  image_picker: ^1.0.0
  permission_handler: ^11.3.1
  path_provider: ^2.1.4
  uuid: ^4.6.0
  url_launcher: ^6.3.1
  flutter_svg: ^2.0.10

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  mocktail: ^1.0.5
  flutter_native_splash: ^2.4.0

flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/images/

flutter_native_splash:
  color: "#16142a"
  image: assets/images/hms_square.png
  android_12:
    color: "#16142a"
    image: assets/images/hms_square.png
  android: true
  ios: true
  web: false
```

- [ ] **Step 3: Create `l10n.yaml`**

```yaml
arb-dir: lib/core/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
output-dir: lib/core/l10n/generated
nullable-getter: false
```

- [ ] **Step 4: Create `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - lib/core/l10n/generated/**

linter:
  rules:
    prefer_single_quotes: true
    always_use_package_imports: true
```

- [ ] **Step 5: Create `lib/core/l10n/app_en.arb`**

```json
{
  "@@locale": "en",
  "appTitle": "DeCare HMS",
  "commonHeader": "DeCare HMS",
  "commonCancel": "Cancel",
  "commonPleaseWait": "Please wait",
  "commonConfirmTitle": "Are you sure?",
  "commonConfirmNo": "No, I'm Not",
  "commonConfirmYes": "Yes, I am",
  "commonPressBackAgain": "App: Press back again to exit",
  "commonCannotGoBack": "Can't go back",

  "errorCannotConnect": "Could not reach the server",
  "errorTimeout": "The server took too long to respond",
  "errorUnauthorized": "Session expired",
  "errorNotFound": "Not found",
  "errorServer": "Server error",
  "errorRejected": "Request rejected",
  "errorBadData": "Unexpected response from server",
  "errorInvalidCredentials": "Invalid username or password",

  "configureUrlTitle": "Installation URL",
  "configureUrlBody": "Input server URL of your self-hosted DeCare-HMS installation.",
  "configureUrlPlaceholder": "Eg: http://your-hms-server-url.com",
  "configureUrlConnect": "Connect",
  "configureUrlInvalid": "Invalid URL: Please provide a valid URL",
  "configureUrlHostError": "Host: {message}",
  "@configureUrlHostError": {"placeholders": {"message": {"type": "String"}}},

  "loginUsername": "Username",
  "loginPassword": "Password",
  "loginSignIn": "Sign In",
  "loginChangeUrl": "Change URL",
  "loginError": "Login: {message}",
  "@loginError": {"placeholders": {"message": {"type": "String"}}},

  "homeRecentSearches": "Recent Searches:",
  "homeClearAll": "clear all",
  "homeRecentRow": "{name}, {opid}",
  "@homeRecentRow": {"placeholders": {"name": {"type": "String"}, "opid": {"type": "int"}}},
  "homeEmptyTitle": "There is no patient selected.",
  "homeEmptyBody": "Once you choose a patient, they'll appear here.",
  "homeSearchPlaceholder": "Enter OP Number",
  "homeFetchingPatient": "Fetching Patient",
  "homePatientError": "Patient: {message}",
  "@homePatientError": {"placeholders": {"message": {"type": "String"}}},

  "tomogramChooseGallery": "Choose from Gallery",
  "tomogramTakePhoto": "Take Photo",
  "tomogramDescription": "Description",
  "tomogramOpNumber": "Op Number",
  "tomogramEmptyTitle": "There is no tomogram added.",
  "tomogramEmptyBody": "You can add tomogram details using the '+' button at top-right, they'll appear here as added.",
  "tomogramUploading": "Uploading",
  "tomogramUploaded": "Tomogram: Uploaded",
  "tomogramUploadError": "Tomogram Upload: {message}",
  "@tomogramUploadError": {"placeholders": {"message": {"type": "String"}}},
  "tomogramOnlyJpeg": "Tomogram: Only JPEG images are supported",

  "permissionTitle": "Grant Permission to access {name}",
  "@permissionTitle": {"placeholders": {"name": {"type": "String"}}},
  "permissionBody": "It looks like you have turned off permissions required for this feature. It can be enabled under Phone Settings > Apps > HMS > Permissions",
  "permissionGrant": "Grant Permission",
  "permissionCamera": "Camera",
  "permissionPhotos": "Files and media",

  "settingsChangeUrl": "Change Installation URL",
  "settingsChangeUrlBody": "Re-configure the connection URL of your self-hosted DeCare HMS. This process will log you out of the app.",
  "settingsAbout": "About",
  "settingsLogout": "Logout",
  "settingsTabHome": "Home",
  "settingsTabSettings": "Settings",

  "aboutHeader": "About",
  "aboutTerms": "Terms of Service",
  "aboutUs": "About Us",
  "aboutContact": "Contact Us",
  "aboutOr": "or",
  "aboutPhone": "+91 80863 58930",
  "aboutWebsite": "website (decare.team)",
  "aboutCopyright": "DecareHMS is copyrighted © {year} by Decare Software Solution. All rights reserved.",
  "@aboutCopyright": {"placeholders": {"year": {"type": "int"}}},
  "aboutLicense": "DecareHMS is licensed to Cutis Hospital as a part of the DeCare's Hospital ERP software, and its support is tied to the support license for the ERP. Support for DeCareHMS app is available only as long as the ERP's support license is active.",
  "aboutParaIntro": "Decare Software Solution is a company that specializes in developing innovative and user-friendly software solutions for the health care sector. We have a team of experienced and qualified software engineers, designers, and testers who are passionate about creating products that can improve the quality and efficiency of health care services.",
  "aboutParaTwo": "Our mobile app, DecareHMS, is one of our flagship products that aims to help clinics diagnose and treat skin diseases more effectively. DecareHMS is a simple and convenient app that allows clinics to upload skin disease images to their DeCare's Hospital ERP software with just a few clicks. The app also integrates seamlessly with the ERP software (that manage their patient records, inventory, billing, appointments, etc in one place). The app provides an easy-to-use interface for doctors to review the images and make accurate diagnoses.",
  "aboutParaThree": "DecareHMS is designed to be compatible with all major mobile platforms and devices. The app is secure, fast, and easy to use. With DecareHMS, clinics can save time and money, enhance their reputation, and provide better care for their patients.",
  "aboutParaFinale": "If you want to learn more about our company or products, please visit our website or contact us. We would be happy to answer any questions you may have."
}
```

- [ ] **Step 6: Copy raster and vector assets from the React Native repo**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
mkdir -p assets/images
RN="E:/Projects/personal/deCare/hms/HMSUploader"
cp "$RN/assets/images/drawable-xxhdpi/hms_square.png" assets/images/hms_square.png
cp "$RN/assets/images/hms_circle.svg" assets/images/hms_circle.svg
cp "$RN/app/screens/about/decare-logo.jpeg" assets/images/decare_logo.jpeg
cp "$RN/app/screens/configURL/installationurl.png" assets/images/installation_url.png
```

The two empty-state illustrations (`blank_canvas.svg`, `add_tomogram.svg`) are produced in Task 10.

- [ ] **Step 7: Android config**

Edit `android/app/build.gradle`:
- `namespace "com.decare.hmsuploader"`
- `applicationId "com.decare.hmsuploader"`
- `minSdkVersion 21`

Move `android/app/src/main/kotlin/com/decare/hms_uploader/MainActivity.kt` to `android/app/src/main/kotlin/com/decare/hmsuploader/MainActivity.kt` and change its first line to `package com.decare.hmsuploader`. Delete the old folder.

Replace `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>

    <application
        android:label="HMS"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false"
        android:usesCleartextTraffic="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:screenOrientation="portrait"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
    </queries>
</manifest>
```

- [ ] **Step 8: iOS config**

In `ios/Runner/Info.plist`, inside the top-level `<dict>` add:

```xml
<key>NSCameraUsageDescription</key>
<string>DeCare HMS uses the camera to photograph tomograms for a patient record.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>DeCare HMS reads photos you choose to attach to a patient record.</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

and replace the `UISupportedInterfaceOrientations` array (both the iPhone one and `~ipad` one) with only `<string>UIInterfaceOrientationPortrait</string>`. Set `CFBundleDisplayName` to `HMS`.

- [ ] **Step 9: Theme files**

`lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF151D28);
  static const text = Color(0xFF120E2C);
  static const dimText = Color(0xFFBAB6C8);
  static const dim = Color(0xFF939AA4);
  static const offWhite = Color(0xFFE6E6E6);
  static const background = Color(0xFFFFFFFF);
  static const error = Color(0xFFDD3333);
  static const errorRed = Color(0xFFFF6C63);
  static const goGreen = Color(0xFF63FF6C);
  static const orange = Color(0xFFFBA928);
  static const splash = Color(0xFF16142A);
  static const rowGrey = Color(0xFFE8E8E8);
  static const searchBorder = Color(0xFFC5C5C5);
  static const divider = Color(0xFFEFEFEF);
  static const gradientStart = Color(0xFFE6E6E6);
  static const scrim = Color(0x80000000);
}
```

`lib/core/theme/app_spacing.dart`:

```dart
abstract final class AppSpacing {
  static const double none = 0;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}
```

`lib/core/theme/app_text_styles.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';

abstract final class AppTextStyles {
  static const body = TextStyle(fontSize: 15, color: AppColors.text);
  static const bold = TextStyle(fontSize: 15, color: AppColors.text, fontWeight: FontWeight.bold);
  static const header = TextStyle(fontSize: 24, color: AppColors.text, fontWeight: FontWeight.bold);
  static const fieldLabel = TextStyle(fontSize: 13, color: AppColors.dim);
  static const secondary = TextStyle(fontSize: 9, color: AppColors.dim);
  static const brandLarge = TextStyle(fontSize: 40, color: AppColors.text, fontWeight: FontWeight.w700);
  static const headerBar = TextStyle(fontSize: 28, color: AppColors.background, fontWeight: FontWeight.w700);
  static const onPrimary = TextStyle(fontSize: 15, color: AppColors.background);
}
```

`lib/core/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.orange,
      error: AppColors.error,
      surface: AppColors.background,
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.background,
      titleTextStyle: AppTextStyles.headerBar,
    ),
    dividerColor: AppColors.divider,
  );
}
```

- [ ] **Step 10: Placeholder `lib/main.dart` so the project compiles**

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_theme.dart';

void main() {
  runApp(MaterialApp(theme: buildAppTheme(), home: const Scaffold(body: SizedBox.shrink())));
}
```

- [ ] **Step 11: Fetch packages, generate strings, analyze**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
flutter pub get
flutter gen-l10n
flutter analyze
```

Expected: `No issues found!`. `lib/core/l10n/generated/app_localizations.dart` and `app_localizations_en.dart` now exist.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project with platform config, theme and strings"
```

---

### Task 2: `ApiFailure` and JSend envelope

**Files:**
- Create: `lib/core/network/api_failure.dart`, `lib/core/network/api_envelope.dart`
- Test: `test/core/network/api_failure_test.dart`, `test/core/network/api_envelope_test.dart`

**Interfaces:**
- Produces: `sealed class ApiFailure implements Exception { final String? detail; String describe(AppLocalizations l10n); }` with subclasses `CannotConnectFailure`, `TimeoutFailure`, `UnauthorizedFailure`, `NotFoundFailure`, `ServerFailure`, `RejectedFailure`, `BadDataFailure`, each with `const X([String? detail])`. `detail` is the server-supplied message when there was one; `describe` returns `detail` or the localized default (`l10n.errorCannotConnect` etc.). Also `ApiFailure.from(Object error)`, `String? serverMessage(dynamic body)`, `dynamic unwrapEnvelope(dynamic body)`.

- [ ] **Step 1: Write failing tests**

`test/core/network/api_failure_test.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations_en.dart';
import 'package:hms_uploader/core/network/api_failure.dart';

final l10n = AppLocalizationsEn();

DioException _dio(DioExceptionType type, {int? status, dynamic data, Object? error}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: type,
    error: error,
    response: status == null ? null : Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('ApiFailure.from', () {
    test('passes through an existing ApiFailure', () {
      const f = TimeoutFailure();
      expect(ApiFailure.from(f), same(f));
    });
    test('maps timeouts', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(ApiFailure.from(_dio(t)), isA<TimeoutFailure>());
      }
    });
    test('maps connection errors', () {
      expect(ApiFailure.from(_dio(DioExceptionType.connectionError)), isA<CannotConnectFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badCertificate)), isA<CannotConnectFailure>());
      expect(
        ApiFailure.from(_dio(DioExceptionType.unknown, error: const SocketException('x'))),
        isA<CannotConnectFailure>(),
      );
    });
    test('maps unknown without socket error to bad data', () {
      expect(ApiFailure.from(_dio(DioExceptionType.unknown)), isA<BadDataFailure>());
    });
    test('maps status codes', () {
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 401)), isA<UnauthorizedFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 403)), isA<UnauthorizedFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 404)), isA<NotFoundFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 500)), isA<ServerFailure>());
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 400)), isA<RejectedFailure>());
    });
    test('uses JSend messages from the body', () {
      final notFound = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 404, data: {'status': 'fail', 'data': 'Invalid OP Number'}));
      expect(notFound.detail, 'Invalid OP Number');
      expect(notFound.describe(l10n), 'Invalid OP Number');
      final server = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 500, data: {'status': 'error', 'message': 'Internal Server Error'}));
      expect(server.detail, 'Internal Server Error');
      final nested = ApiFailure.from(_dio(DioExceptionType.badResponse,
          status: 400, data: {'status': 'fail', 'data': {'message': 'nested'}}));
      expect(nested.detail, 'nested');
    });
    test('falls back to localized default messages', () {
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 404)).describe(l10n), 'Not found');
      expect(ApiFailure.from(_dio(DioExceptionType.badResponse, status: 503)).describe(l10n), 'Server error');
      expect(const CannotConnectFailure().describe(l10n), 'Could not reach the server');
      expect(const TimeoutFailure().describe(l10n), 'The server took too long to respond');
      expect(const UnauthorizedFailure().describe(l10n), 'Session expired');
      expect(const RejectedFailure().describe(l10n), 'Request rejected');
      expect(const BadDataFailure().describe(l10n), 'Unexpected response from server');
    });
    test('maps arbitrary errors to bad data', () {
      expect(ApiFailure.from(const FormatException('bad')), isA<BadDataFailure>());
    });
  });
}
```

`test/core/network/api_envelope_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';

void main() {
  test('returns data on success', () {
    expect(unwrapEnvelope({'status': 'success', 'data': {'a': 1}}), {'a': 1});
  });
  test('returns null data on success with null', () {
    expect(unwrapEnvelope({'status': 'success', 'data': null}), isNull);
  });
  test('throws RejectedFailure with message on fail', () {
    expect(
      () => unwrapEnvelope({'status': 'fail', 'data': 'Invalid opid'}),
      throwsA(isA<RejectedFailure>().having((f) => f.detail, 'detail', 'Invalid opid')),
    );
  });
  test('throws RejectedFailure with message on error', () {
    expect(
      () => unwrapEnvelope({'status': 'error', 'message': 'boom'}),
      throwsA(isA<RejectedFailure>().having((f) => f.detail, 'detail', 'boom')),
    );
  });
  test('throws BadDataFailure when body is not a map', () {
    expect(() => unwrapEnvelope('nope'), throwsA(isA<BadDataFailure>()));
    expect(() => unwrapEnvelope(null), throwsA(isA<BadDataFailure>()));
  });
}
```

- [ ] **Step 2: Run tests, expect compile failure**

```bash
flutter test test/core/network
```
Expected: FAIL (missing imports).

- [ ] **Step 3: Implement `lib/core/network/api_failure.dart`**

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

/// All errors the data layer surfaces to the UI.
///
/// [detail] is the message the server supplied, if any. [describe] returns
/// that or a localized default, so screens never show raw error codes.
sealed class ApiFailure implements Exception {
  const ApiFailure([this.detail]);

  final String? detail;

  String describe(AppLocalizations l10n);

  /// Map any thrown object to an [ApiFailure]. Existing failures pass through.
  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException) return _fromDio(error);
    return const BadDataFailure();
  }

  static ApiFailure _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutFailure();
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const CannotConnectFailure();
      case DioExceptionType.cancel:
        return const RejectedFailure('Request cancelled');
      case DioExceptionType.unknown:
        return e.error is SocketException ? const CannotConnectFailure() : const BadDataFailure();
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final msg = serverMessage(e.response?.data);
        if (status == 401 || status == 403) return UnauthorizedFailure(msg);
        if (status == 404) return NotFoundFailure(msg);
        if (status >= 500) return ServerFailure(msg);
        return RejectedFailure(msg);
    }
  }

  @override
  String toString() => '$runtimeType(${detail ?? ''})';
}

/// Extract a message from a JSend body: `{status:'error', message}` or
/// `{status:'fail', data: <string | {message}>}`.
String? serverMessage(dynamic body) {
  if (body is! Map) return null;
  final message = body['message'];
  if (message is String && message.isNotEmpty) return message;
  final data = body['data'];
  if (data is String && data.isNotEmpty) return data;
  if (data is Map) {
    final nested = data['message'];
    if (nested is String && nested.isNotEmpty) return nested;
  }
  return null;
}

class CannotConnectFailure extends ApiFailure {
  const CannotConnectFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorCannotConnect;
}

class TimeoutFailure extends ApiFailure {
  const TimeoutFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorTimeout;
}

class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorUnauthorized;
}

class NotFoundFailure extends ApiFailure {
  const NotFoundFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorNotFound;
}

class ServerFailure extends ApiFailure {
  const ServerFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorServer;
}

class RejectedFailure extends ApiFailure {
  const RejectedFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorRejected;
}

class BadDataFailure extends ApiFailure {
  const BadDataFailure([super.detail]);
  @override
  String describe(AppLocalizations l10n) => detail ?? l10n.errorBadData;
}
```

- [ ] **Step 4: Implement `lib/core/network/api_envelope.dart`**

```dart
import 'package:hms_uploader/core/network/api_failure.dart';

/// Unwrap a JSend response body. Returns the `data` payload on success and
/// throws an [ApiFailure] otherwise.
dynamic unwrapEnvelope(dynamic body) {
  if (body is! Map) throw const BadDataFailure();
  if (body['status'] == 'success') return body['data'];
  throw RejectedFailure(serverMessage(body));
}
```

- [ ] **Step 5: Run tests and analyzer**

```bash
flutter test test/core/network && flutter analyze
```
Expected: all pass, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/network test/core/network
git commit -m "feat(core): ApiFailure mapping and JSend envelope"
```

---

### Task 3: Core utilities: URL validation, JWT expiry, JPEG check, temp files

**Files:**
- Create: `lib/core/utils/url_validator.dart`, `lib/core/utils/jwt.dart`, `lib/core/utils/jpeg.dart`, `lib/core/utils/temp_files.dart`
- Test: `test/core/utils/url_validator_test.dart`, `test/core/utils/jwt_test.dart`, `test/core/utils/jpeg_test.dart`, `test/core/utils/temp_files_test.dart`

**Interfaces:**
- Produces: `bool isValidServerUrl(String)`, `String? normalizeServerUrl(String)` (null when invalid; adds `http://` when scheme missing; strips trailing `/`), `DateTime? jwtExpiry(String token)`, `bool isJwtValid(String? token, {DateTime? now})`, `Future<bool> isJpegFile(String path)`, `Future<void> deleteFiles(Iterable<String> paths)`.

- [ ] **Step 1: Write failing tests**

`test/core/utils/url_validator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/url_validator.dart';

void main() {
  group('isValidServerUrl', () {
    for (final ok in [
      'http://cutis.decare.team',
      'https://www.decare.team',
      'decare.team',
      'my-hms.example.com',
      'http://192.168.1.10:3000',
      'localhost:3000',
      'http://localhost',
      'http://10.0.0.5:8080/hms',
      'HTTP://DECARE.TEAM',
    ]) {
      test('accepts $ok', () => expect(isValidServerUrl(ok), isTrue, reason: ok));
    }
    for (final bad in ['', 'not a url', 'http://', 'ftp://x.com', 'foo', 'http://exa mple.com']) {
      test('rejects "$bad"', () => expect(isValidServerUrl(bad), isFalse, reason: bad));
    }
  });

  group('normalizeServerUrl', () {
    test('adds http scheme when missing', () {
      expect(normalizeServerUrl('decare.team'), 'http://decare.team');
    });
    test('keeps https', () {
      expect(normalizeServerUrl('https://decare.team'), 'https://decare.team');
    });
    test('trims whitespace and trailing slash', () {
      expect(normalizeServerUrl('  http://decare.team/  '), 'http://decare.team');
    });
    test('returns null for invalid input', () {
      expect(normalizeServerUrl('not a url'), isNull);
    });
  });
}
```

`test/core/utils/jwt_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/jwt.dart';

String _token(Map<String, dynamic> payload) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.sig';
}

void main() {
  test('decodes exp', () {
    final exp = DateTime.utc(2030, 1, 1);
    final t = _token({'exp': exp.millisecondsSinceEpoch ~/ 1000});
    expect(jwtExpiry(t), exp);
  });
  test('returns null for malformed token', () {
    expect(jwtExpiry('abc'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
    expect(jwtExpiry(_token({'foo': 1})), isNull);
  });
  test('isJwtValid compares against now', () {
    final now = DateTime.utc(2026, 9, 8);
    final live = _token({'exp': now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000});
    final dead = _token({'exp': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000});
    expect(isJwtValid(live, now: now), isTrue);
    expect(isJwtValid(dead, now: now), isFalse);
    expect(isJwtValid(null, now: now), isFalse);
    expect(isJwtValid('garbage', now: now), isFalse);
  });
}
```

`test/core/utils/jpeg_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/jpeg.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('jpeg_test'));
  tearDown(() async => dir.delete(recursive: true));

  test('detects JPEG magic bytes', () async {
    final f = File('${dir.path}/a.bin');
    await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
    expect(await isJpegFile(f.path), isTrue);
  });
  test('rejects PNG', () async {
    final f = File('${dir.path}/a.png');
    await f.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0, 0]);
    expect(await isJpegFile(f.path), isFalse);
  });
  test('rejects missing or tiny file', () async {
    expect(await isJpegFile('${dir.path}/missing'), isFalse);
    final f = File('${dir.path}/tiny');
    await f.writeAsBytes([0xFF]);
    expect(await isJpegFile(f.path), isFalse);
  });
}
```

`test/core/utils/temp_files_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';

void main() {
  test('deletes existing files and ignores missing ones', () async {
    final dir = await Directory.systemTemp.createTemp('tmp_files');
    final a = File('${dir.path}/a')..writeAsStringSync('a');
    await deleteFiles([a.path, '${dir.path}/missing']);
    expect(a.existsSync(), isFalse);
    await dir.delete(recursive: true);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/core/utils
```

- [ ] **Step 3: Implement**

`lib/core/utils/url_validator.dart` (regex verbatim from the React Native app):

```dart
final RegExp _serverUrlPattern = RegExp(
  r'^(https?:\/\/)?((localhost|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d{1,5})?|(www\.)?[\w\-]+\.[a-z]{2,}|([A-Za-z0-9_-]+\.?[A-Za-z0-9_-]*:[0-9]+))(\/\S*)?$',
  caseSensitive: false,
);

bool isValidServerUrl(String input) {
  final s = input.trim();
  if (s.isEmpty) return false;
  return _serverUrlPattern.hasMatch(s);
}

/// Returns a usable base URL (scheme present, no trailing slash) or null.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (!isValidServerUrl(s)) return null;
  final lower = s.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    s = 'http://$s';
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}
```

`lib/core/utils/jwt.dart`:

```dart
import 'dart:convert';

/// Decode the `exp` claim of a JWT without verifying its signature.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final map = jsonDecode(payload);
    if (map is! Map) return null;
    final exp = map['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
  } on FormatException {
    return null;
  }
}

bool isJwtValid(String? token, {DateTime? now}) {
  if (token == null || token.isEmpty) return false;
  final exp = jwtExpiry(token);
  if (exp == null) return false;
  return exp.isAfter(now ?? DateTime.now().toUtc());
}
```

`lib/core/utils/jpeg.dart`:

```dart
import 'dart:io';

/// True when the file starts with the JPEG SOI marker `FF D8 FF`.
Future<bool> isJpegFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final bytes = await raf.read(3);
    return bytes.length == 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  } finally {
    await raf.close();
  }
}
```

`lib/core/utils/temp_files.dart`:

```dart
import 'dart:io';

/// Best-effort deletion of local files. Missing files and IO errors are ignored.
Future<void> deleteFiles(Iterable<String> paths) async {
  for (final p in paths) {
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // ignore: best effort cleanup
    }
  }
}
```

- [ ] **Step 4: Run tests and analyzer**

```bash
flutter test test/core/utils && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils test/core/utils
git commit -m "feat(core): url validation, jwt expiry, jpeg check, temp file cleanup"
```

---

### Task 4: Storage providers and Dio client with Bearer interceptor

**Files:**
- Create: `lib/core/storage/prefs_store.dart`, `lib/core/storage/secure_store.dart`, `lib/core/network/dio_client.dart`, `lib/core/network/auth_interceptor.dart`
- Test: `test/core/network/dio_client_test.dart`, `test/core/storage/secure_store_test.dart`

**Interfaces:**
- Produces:
  - `final sharedPreferencesProvider = Provider<SharedPreferences>` (throws until overridden in `main.dart`/tests).
  - `abstract class SecureStore { Future<String?> read(String key); Future<void> write(String key, String? value); Future<void> delete(String key); }`, `class FlutterSecureStore implements SecureStore`, `class InMemorySecureStore implements SecureStore`, `final secureStoreProvider = Provider<SecureStore>`.
  - `final serverUrlProvider = Provider<String?>` and `final accessTokenProvider = Provider<String?>` (both throw `UnimplementedError` until overridden by `main.dart`).
  - `Dio buildDio({required String baseUrl, required String? Function() tokenReader})`, `final dioProvider = Provider<Dio>`, `const Duration jsonTimeout = Duration(seconds: 10)`, `const Duration uploadTimeout = Duration(seconds: 60)`.
  - `String apiBaseUrl(String serverUrl) => '$serverUrl/api'`.

- [ ] **Step 1: Write failing tests**

`test/core/network/dio_client_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

void main() {
  test('apiBaseUrl appends /api', () {
    expect(apiBaseUrl('http://decare.team'), 'http://decare.team/api');
  });

  test('buildDio sets base url, accept header and timeouts', () {
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => null);
    expect(dio.options.baseUrl, 'http://x/api');
    expect(dio.options.headers['Accept'], 'application/json');
    expect(dio.options.connectTimeout, jsonTimeout);
    expect(dio.options.receiveTimeout, jsonTimeout);
  });

  test('interceptor adds Bearer header only when a token exists', () async {
    String? token;
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => token);
    late RequestOptions seen;
    dio.httpClientAdapter = _CapturingAdapter((o) => seen = o);

    await dio.get('/a');
    expect(seen.headers.containsKey('Authorization'), isFalse);

    token = 'abc';
    await dio.get('/a');
    expect(seen.headers['Authorization'], 'Bearer abc');
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onRequest);
  final void Function(RequestOptions) onRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    onRequest(options);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
```

`test/core/storage/secure_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';

void main() {
  test('InMemorySecureStore round-trips and deletes', () async {
    final s = InMemorySecureStore();
    expect(await s.read('k'), isNull);
    await s.write('k', 'v');
    expect(await s.read('k'), 'v');
    await s.write('k', null);
    expect(await s.read('k'), isNull);
    await s.write('k', 'v2');
    await s.delete('k');
    expect(await s.read('k'), isNull);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/core/network/dio_client_test.dart test/core/storage
```

- [ ] **Step 3: Implement storage**

`lib/core/storage/prefs_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main.dart with the awaited instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);
```

`lib/core/storage/secure_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      value == null ? _storage.delete(key: key) : _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureStore implements SecureStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

final secureStoreProvider = Provider<SecureStore>((ref) => FlutterSecureStore());
```

- [ ] **Step 4: Implement network client**

`lib/core/network/auth_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

/// Adds `Authorization: Bearer <token>` when [tokenReader] returns a token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.tokenReader);

  final String? Function() tokenReader;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenReader();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

`lib/core/network/dio_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/auth_interceptor.dart';

const Duration jsonTimeout = Duration(seconds: 10);
const Duration uploadTimeout = Duration(seconds: 60);

String apiBaseUrl(String serverUrl) => '$serverUrl/api';

/// Current server URL. Overridden in main.dart with the server_config feature state.
final serverUrlProvider = Provider<String?>(
  (ref) => throw UnimplementedError('serverUrlProvider must be overridden in main.dart'),
);

/// Current access token. Overridden in main.dart with the auth feature state.
final accessTokenProvider = Provider<String?>(
  (ref) => throw UnimplementedError('accessTokenProvider must be overridden in main.dart'),
);

Dio buildDio({required String baseUrl, required String? Function() tokenReader}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: jsonTimeout,
    receiveTimeout: jsonTimeout,
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(tokenReader));
  return dio;
}

/// Shared client for the configured server. Rebuilds whenever the URL changes.
/// Throws [StateError] if no server URL is configured; callers only reach it
/// after the redirect gate has ensured one exists.
final dioProvider = Provider<Dio>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null || url.isEmpty) {
    throw StateError('No server URL configured');
  }
  final dio = buildDio(
    baseUrl: apiBaseUrl(url),
    tokenReader: () => ref.read(accessTokenProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});
```

- [ ] **Step 5: Create `lib/core/navigation/route_paths.dart`**

Every feature and the router refer to these; nothing else hard-codes a path.

```dart
/// Route locations shared by features and the router.
abstract final class RoutePaths {
  static const configure = '/configure';
  static const login = '/login';
  static const home = '/app/home';
  static const tomogramPattern = 'tomogram/:opid';
  static String tomogram(int opid) => '$home/tomogram/$opid';
  static const permissionPattern = 'permission';
  static const permission = '$home/permission';
  static const settings = '/app/settings';
  static const aboutPattern = 'about';
  static const about = '$settings/about';
}
```

- [ ] **Step 6: Run tests and analyzer**

```bash
flutter test test/core && flutter analyze
```

- [ ] **Step 7: Commit**

```bash
git add lib/core test/core
git commit -m "feat(core): storage providers, Dio client with Bearer interceptor, route paths"
```

---

### Task 5: Shared widgets

**Files:**
- Create: `lib/core/widgets/flash_banner.dart`, `lib/core/widgets/loader_modal.dart`, `lib/core/widgets/confirm_dialog.dart`, `lib/core/widgets/app_bottom_sheet.dart`, `lib/core/widgets/app_header.dart`, `lib/core/widgets/app_text_field.dart`, `lib/core/widgets/app_buttons.dart`, `lib/core/widgets/keyboard_visibility.dart`, `lib/core/widgets/exit_on_double_back.dart`, `lib/core/widgets/l10n_ext.dart`
- Test: `test/core/widgets/flash_banner_test.dart`, `test/core/widgets/confirm_dialog_test.dart`, `test/core/widgets/exit_on_double_back_test.dart`

**Interfaces:**
- Produces:
  - `enum FlashType { danger, warning, success, info }`; `void showFlash(BuildContext context, String message, {FlashType type = FlashType.info})`.
  - `class LoaderModal extends StatelessWidget { const LoaderModal({required this.visible, required this.text, required this.child}); }` (overlays a blocking dialog-like card over `child`).
  - `Future<bool> showConfirmDialog(BuildContext context)` (true = confirmed).
  - `Future<T?> showAppBottomSheet<T>(BuildContext context, {required List<Widget> children})`.
  - `class AppHeader extends StatelessWidget { const AppHeader({required this.title, this.leftIcon, this.onLeftTap, this.rightIcon, this.onRightTap, this.rightIconColor}); }` (`leftIcon`/`rightIcon` are `IconData?`).
  - `class AppTextField extends StatelessWidget` with `controller`, `label`, `hint`, `obscureText`, `readOnly`, `keyboardType`, `maxLength`, `maxLines`, `suffix` (Widget?), `onSubmitted`, `textInputAction`, `onChanged`.
  - `class PrimaryButton extends StatelessWidget { const PrimaryButton({required this.label, required this.onPressed, this.loading = false, this.color}); }`, `class LinkButton extends StatelessWidget { const LinkButton({required this.label, required this.onPressed, this.color}); }`.
  - `bool isKeyboardVisible(BuildContext context)`; `class HideWithKeyboard extends StatelessWidget { const HideWithKeyboard({required this.child}); }`.
  - `class ExitOnDoubleBack extends StatefulWidget { const ExitOnDoubleBack({required this.child, this.exit, this.window = const Duration(seconds: 3)}); }` where `exit` defaults to `SystemNavigator.pop`.
  - `extension L10nX on BuildContext { AppLocalizations get l10n; }`.

- [ ] **Step 1: Write failing tests**

`test/core/widgets/flash_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';

void main() {
  testWidgets('shows message then auto-dismisses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFlash(context, 'Hello', type: FlashType.danger),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Hello'), findsNothing);
  });
}
```

`test/core/widgets/confirm_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/widgets/confirm_dialog.dart';

void main() {
  testWidgets('returns true on confirm and false on cancel', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showConfirmDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('Yes, I am'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("No, I'm Not"));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
```

`test/core/widgets/exit_on_double_back_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';

void main() {
  testWidgets('first back shows flash, second within window exits', (tester) async {
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ExitOnDoubleBack(exit: () => exits++, child: const Scaffold(body: Text('home'))),
    ));
    final dynamic state = tester.state(find.byType(ExitOnDoubleBack));
    state.handleBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('App: Press back again to exit'), findsOneWidget);
    expect(exits, 0);
    state.handleBack();
    expect(exits, 1);
  });

  testWidgets('second back after window does not exit', (tester) async {
    var exits = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: ExitOnDoubleBack(
        exit: () => exits++,
        window: const Duration(milliseconds: 100),
        child: const Scaffold(body: Text('home')),
      ),
    ));
    final dynamic state = tester.state(find.byType(ExitOnDoubleBack));
    state.handleBack();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    state.handleBack();
    expect(exits, 0);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/core/widgets
```

- [ ] **Step 3: Implement widgets**

`lib/core/widgets/l10n_ext.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

`lib/core/widgets/flash_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';

enum FlashType { danger, warning, success, info }

OverlayEntry? _current;

/// Top-anchored transient banner, equivalent to react-native-flash-message.
void showFlash(BuildContext context, String message, {FlashType type = FlashType.info}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  _current = null;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlashBanner(
      message: message,
      type: type,
      onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _FlashBanner extends StatefulWidget {
  const _FlashBanner({required this.message, required this.type, required this.onDone});

  final String message;
  final FlashType type;
  final VoidCallback onDone;

  @override
  State<_FlashBanner> createState() => _FlashBannerState();
}

class _FlashBannerState extends State<_FlashBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.type) {
        FlashType.danger => AppColors.error,
        FlashType.warning => AppColors.orange,
        FlashType.success => const Color(0xFF2E7D32),
        FlashType.info => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Material(
          color: _color,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, top + AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
```

`lib/core/widgets/loader_modal.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Blocks [child] with a "Please wait" card while [visible] is true.
class LoaderModal extends StatelessWidget {
  const LoaderModal({super.key, required this.visible, required this.text, required this.child});

  final bool visible;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: AppColors.scrim,
                alignment: Alignment.center,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 200,
                    height: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(context.l10n.commonPleaseWait),
                        const SizedBox(height: AppSpacing.xs),
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('. . . $text . . .', style: const TextStyle(fontSize: 13, color: AppColors.dim)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

`lib/core/widgets/confirm_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// "Are you sure?" with No / Yes. Resolves true when confirmed.
Future<bool> showConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.commonConfirmTitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.commonConfirmNo, style: const TextStyle(color: AppColors.dim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.commonConfirmYes, style: const TextStyle(color: AppColors.errorRed)),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

`lib/core/widgets/app_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';

Future<T?> showAppBottomSheet<T>(BuildContext context, {required List<Widget> children}) {
  return showModalBottomSheet<T>(
    context: context,
    barrierColor: AppColors.scrim,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}
```

`lib/core/widgets/app_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

/// Dark header bar with a centred title and optional icon buttons.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.leftIcon,
    this.onLeftTap,
    this.rightIcon,
    this.onRightTap,
    this.rightIconColor,
  });

  final String title;
  final IconData? leftIcon;
  final VoidCallback? onLeftTap;
  final IconData? rightIcon;
  final VoidCallback? onRightTap;
  final Color? rightIconColor;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
      ),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(title, style: AppTextStyles.headerBar),
            if (leftIcon != null)
              Positioned(
                left: 4,
                child: IconButton(
                  icon: Icon(leftIcon, color: Colors.white),
                  onPressed: onLeftTap,
                ),
              ),
            if (rightIcon != null)
              Positioned(
                right: 4,
                child: IconButton(
                  icon: Icon(rightIcon, color: rightIconColor ?? AppColors.goGreen),
                  onPressed: onRightTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

`lib/core/widgets/app_text_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.dim),
            counterText: '',
            isDense: true,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: AppColors.searchBorder),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
      ],
    );
  }
}
```

`lib/core/widgets/app_buttons.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
    );
  }
}

class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
      child: Text(label, style: TextStyle(color: color ?? AppColors.text, fontSize: 15)),
    );
  }
}
```

`lib/core/widgets/keyboard_visibility.dart`:

```dart
import 'package:flutter/widgets.dart';

bool isKeyboardVisible(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom > 0;

/// Renders [child] only while the soft keyboard is hidden.
class HideWithKeyboard extends StatelessWidget {
  const HideWithKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isKeyboardVisible(context) ? const SizedBox.shrink() : child,
    );
  }
}
```

`lib/core/widgets/exit_on_double_back.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Double-press back to exit, matching the React Native `useBackButtonHandler`.
class ExitOnDoubleBack extends StatefulWidget {
  const ExitOnDoubleBack({
    super.key,
    required this.child,
    this.exit,
    this.window = const Duration(seconds: 3),
  });

  final Widget child;
  final VoidCallback? exit;
  final Duration window;

  @override
  State<ExitOnDoubleBack> createState() => ExitOnDoubleBackState();
}

class ExitOnDoubleBackState extends State<ExitOnDoubleBack> {
  DateTime? _lastPress;

  void handleBack() {
    final now = DateTime.now();
    if (_lastPress != null && now.difference(_lastPress!) < widget.window) {
      _lastPress = null;
      (widget.exit ?? SystemNavigator.pop)();
      return;
    }
    _lastPress = now;
    showFlash(context, context.l10n.commonPressBackAgain, type: FlashType.warning);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) handleBack();
      },
      child: widget.child,
    );
  }
}
```

- [ ] **Step 4: Run tests and analyzer**

```bash
flutter test test/core && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets test/core/widgets
git commit -m "feat(core): shared widgets (flash, loader, confirm, sheet, header, fields, buttons, back-to-exit)"
```

---

### Task 6: Feature `server_config` (URL configuration)

**Files:**
- Create: `lib/features/server_config/server_config.dart`, `lib/features/server_config/data/server_config_repository.dart`, `lib/features/server_config/data/health_check_api.dart`, `lib/features/server_config/application/server_config_controller.dart`, `lib/features/server_config/presentation/configure_url_screen.dart`, `test/helpers/pump_app.dart`
- Test: `test/features/server_config/server_config_controller_test.dart`, `test/features/server_config/configure_url_screen_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `buildDio`, `apiBaseUrl`, `unwrapEnvelope`, `ApiFailure`, `normalizeServerUrl`, `showFlash`, `AppTextField`, `PrimaryButton`, `ExitOnDoubleBack`, `context.l10n`.
- Produces:
  - `class ServerConfigRepository { ServerConfigRepository(SharedPreferences prefs); String? read(); Future<void> save(String url); Future<void> clear(); }`, `serverConfigRepositoryProvider`.
  - `abstract class HealthCheckApi { Future<void> check(String serverUrl); }`, `class DioHealthCheckApi implements HealthCheckApi`, `healthCheckApiProvider`.
  - `class InvalidServerUrlException implements Exception {}`.
  - `class ServerConfigController extends AsyncNotifier<String?> { Future<void> connect(String rawUrl); Future<void> reset(); }`, `serverConfigControllerProvider = AsyncNotifierProvider<ServerConfigController, String?>`.
  - `final GoRoute configureRoute;` (path `RoutePaths.configure`) and `class ConfigureUrlScreen extends ConsumerStatefulWidget`.
  - Test helper `Future<void> pumpApp(WidgetTester tester, Widget child, {List<Override> overrides = const []})`.

- [ ] **Step 1: Create the test helper `test/helpers/pump_app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/theme/app_theme.dart';

Future<void> pumpApp(WidgetTester tester, Widget child, {List<Override> overrides = const []}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    ),
  );
}
```

- [ ] **Step 2: Write failing controller test**

`test/features/server_config/server_config_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

void main() {
  late MockHealthCheckApi api;
  late ProviderContainer container;

  Future<void> setUpWith({String? savedUrl}) async {
    SharedPreferences.setMockInitialValues(savedUrl == null ? {} : {'server_url': savedUrl});
    final prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  }

  test('build reads saved url', () async {
    await setUpWith(savedUrl: 'http://saved');
    expect(await container.read(serverConfigControllerProvider.future), 'http://saved');
  });

  test('connect rejects invalid url without calling the network', () async {
    await setUpWith();
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('not a url');
    final state = container.read(serverConfigControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InvalidServerUrlException>());
    verifyNever(() => api.check(any()));
  });

  test('connect saves normalized url on healthy server', () async {
    await setUpWith();
    when(() => api.check(any())).thenAnswer((_) async {});
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('decare.team/');
    verify(() => api.check('http://decare.team')).called(1);
    expect(container.read(serverConfigControllerProvider).value, 'http://decare.team');
    expect(container.read(serverConfigRepositoryProvider).read(), 'http://decare.team');
  });

  test('connect keeps previous url and exposes failure when health check fails', () async {
    await setUpWith(savedUrl: 'http://old');
    when(() => api.check(any())).thenThrow(const CannotConnectFailure());
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).connect('http://new');
    final state = container.read(serverConfigControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<CannotConnectFailure>());
    expect(state.value, 'http://old');
    expect(container.read(serverConfigRepositoryProvider).read(), 'http://old');
  });

  test('reset clears the url', () async {
    await setUpWith(savedUrl: 'http://old');
    await container.read(serverConfigControllerProvider.future);
    await container.read(serverConfigControllerProvider.notifier).reset();
    expect(container.read(serverConfigControllerProvider).value, isNull);
    expect(container.read(serverConfigRepositoryProvider).read(), isNull);
  });
}
```

- [ ] **Step 3: Run test, expect failure**

```bash
flutter test test/features/server_config
```

- [ ] **Step 4: Implement data layer**

`lib/features/server_config/data/server_config_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigRepository {
  ServerConfigRepository(this._prefs);

  static const _key = 'server_url';
  final SharedPreferences _prefs;

  String? read() {
    final v = _prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> save(String url) => _prefs.setString(_key, url);

  Future<void> clear() => _prefs.remove(_key);
}

final serverConfigRepositoryProvider = Provider<ServerConfigRepository>(
  (ref) => ServerConfigRepository(ref.watch(sharedPreferencesProvider)),
);
```

`lib/features/server_config/data/health_check_api.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

abstract class HealthCheckApi {
  /// Throws an [ApiFailure] unless `GET <serverUrl>/api/auth/healthcheck`
  /// answers with a JSend success carrying an `uptime`.
  Future<void> check(String serverUrl);
}

class DioHealthCheckApi implements HealthCheckApi {
  DioHealthCheckApi({Dio Function(String baseUrl)? dioFactory})
      : _dioFactory = dioFactory ?? ((base) => buildDio(baseUrl: base, tokenReader: () => null));

  final Dio Function(String baseUrl) _dioFactory;

  @override
  Future<void> check(String serverUrl) async {
    final dio = _dioFactory(apiBaseUrl(serverUrl));
    try {
      final response = await dio.get<dynamic>('/auth/healthcheck');
      final data = unwrapEnvelope(response.data);
      if (data is! Map || data['uptime'] is! num) {
        throw const BadDataFailure();
      }
    } catch (e) {
      throw ApiFailure.from(e);
    } finally {
      dio.close();
    }
  }
}

final healthCheckApiProvider = Provider<HealthCheckApi>((ref) => DioHealthCheckApi());
```

- [ ] **Step 5: Implement controller**

`lib/features/server_config/application/server_config_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/url_validator.dart';
import 'package:hms_uploader/features/server_config/data/health_check_api.dart';
import 'package:hms_uploader/features/server_config/data/server_config_repository.dart';

class InvalidServerUrlException implements Exception {
  const InvalidServerUrlException();
}

/// Holds the configured server URL. `isLoading` is true while connecting.
class ServerConfigController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => ref.watch(serverConfigRepositoryProvider).read();

  Future<void> connect(String rawUrl) async {
    final url = normalizeServerUrl(rawUrl);
    if (url == null) {
      state = AsyncError<String?>(const InvalidServerUrlException(), StackTrace.current)
          .copyWithPrevious(state);
      return;
    }
    state = const AsyncLoading<String?>().copyWithPrevious(state);
    try {
      await ref.read(healthCheckApiProvider).check(url);
      await ref.read(serverConfigRepositoryProvider).save(url);
      state = AsyncData(url);
    } catch (e, st) {
      state = AsyncError<String?>(e, st).copyWithPrevious(state);
    }
  }

  Future<void> reset() async {
    await ref.read(serverConfigRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}

final serverConfigControllerProvider =
    AsyncNotifierProvider<ServerConfigController, String?>(ServerConfigController.new);
```

- [ ] **Step 6: Run controller test**

```bash
flutter test test/features/server_config/server_config_controller_test.dart
```
Expected: PASS.

- [ ] **Step 7: Write failing screen test**

`test/features/server_config/configure_url_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

void main() {
  testWidgets('shows copy and flashes on invalid url', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockHealthCheckApi();
    await pumpApp(tester, const ConfigureUrlScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Installation URL'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'not a url');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Invalid URL: Please provide a valid URL'), findsOneWidget);
    verifyNever(() => api.check(any()));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('flashes host error when health check fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockHealthCheckApi();
    when(() => api.check(any())).thenThrow(const CannotConnectFailure());
    await pumpApp(tester, const ConfigureUrlScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'http://decare.team');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Host: Could not reach the server'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
```

Add to the imports of that test: `import 'package:hms_uploader/core/network/api_failure.dart';`.

- [ ] **Step 8: Implement screen and barrel**

`lib/features/server_config/presentation/configure_url_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/server_config/application/server_config_controller.dart';

class ConfigureUrlScreen extends ConsumerStatefulWidget {
  const ConfigureUrlScreen({super.key});

  @override
  ConsumerState<ConfigureUrlScreen> createState() => _ConfigureUrlScreenState();
}

class _ConfigureUrlScreenState extends ConsumerState<ConfigureUrlScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _connect() {
    FocusScope.of(context).unfocus();
    ref.read(serverConfigControllerProvider.notifier).connect(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(serverConfigControllerProvider, (prev, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        final error = next.error;
        if (error is InvalidServerUrlException) {
          showFlash(context, l10n.configureUrlInvalid, type: FlashType.warning);
        } else if (error is ApiFailure) {
          showFlash(context, l10n.configureUrlHostError(error.describe(l10n)), type: FlashType.danger);
        }
        return;
      }
      // A freshly connected URL: continue to login (the redirect gate sends a
      // still-valid session on to home).
      if (next.value != null && prev?.value != next.value) {
        context.go(RoutePaths.login);
      }
    });
    final connecting = ref.watch(serverConfigControllerProvider).isLoading;

    return ExitOnDoubleBack(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Image.asset('assets/images/installation_url.png', height: 220, fit: BoxFit.contain),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.configureUrlTitle, style: AppTextStyles.header, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.configureUrlBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _controller,
                  hint: l10n.configureUrlPlaceholder,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: l10n.configureUrlConnect, loading: connecting, onPressed: _connect),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/features/server_config/server_config.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/server_config/presentation/configure_url_screen.dart';

export 'application/server_config_controller.dart';
export 'data/health_check_api.dart';
export 'data/server_config_repository.dart';
export 'presentation/configure_url_screen.dart';

final GoRoute configureRoute = GoRoute(
  path: RoutePaths.configure,
  builder: (context, state) => const ConfigureUrlScreen(),
);
```

- [ ] **Step 9: Run tests and analyzer**

```bash
flutter test test/features/server_config test/core && flutter analyze
```

- [ ] **Step 10: Commit**

```bash
git add lib/features/server_config test/features/server_config test/helpers
git commit -m "feat(server_config): url configuration with health check"
```

---

### Task 7: Feature `auth` (login and session)

**Files:**
- Create: `lib/features/auth/auth.dart`, `lib/features/auth/data/session.dart`, `lib/features/auth/data/session_repository.dart`, `lib/features/auth/data/auth_api.dart`, `lib/features/auth/application/session_controller.dart`, `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/session_test.dart`, `test/features/auth/session_controller_test.dart`, `test/features/auth/login_screen_test.dart`

**Interfaces:**
- Consumes: `SecureStore`/`secureStoreProvider`, `dioProvider`, `unwrapEnvelope`, `ApiFailure`, `isJwtValid`, widgets from Task 5, `configureRoutePath`.
- Produces:
  - `class Session { const Session({required this.accessToken, required this.refreshToken}); bool isValid({DateTime? now}); }`.
  - `class SessionRepository { SessionRepository(SecureStore store); Future<Session?> read(); Future<void> save(Session s); Future<void> clear(); }`, `sessionRepositoryProvider`.
  - `abstract class AuthApi { Future<Session> login(String username, String password); }`, `class DioAuthApi implements AuthApi { DioAuthApi(Dio dio); }`, `authApiProvider`.
  - `class SessionController extends AsyncNotifier<Session?> { Future<void> login(String u, String p); Future<void> logout(); }`, `sessionControllerProvider`.
  - `final GoRoute loginRoute;` (path `RoutePaths.login`), `class LoginScreen extends ConsumerStatefulWidget`.

- [ ] **Step 1: Write failing tests**

`test/features/auth/session_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';

String token(DateTime exp) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.s';
}

void main() {
  test('isValid follows refresh token expiry', () {
    final now = DateTime.utc(2026, 9, 8);
    final live = Session(accessToken: 'a', refreshToken: token(now.add(const Duration(days: 1))));
    final dead = Session(accessToken: 'a', refreshToken: token(now.subtract(const Duration(days: 1))));
    expect(live.isValid(now: now), isTrue);
    expect(dead.isValid(now: now), isFalse);
  });

  test('repository round-trips through secure store', () async {
    final repo = SessionRepository(InMemorySecureStore());
    expect(await repo.read(), isNull);
    await repo.save(const Session(accessToken: 'a', refreshToken: 'r'));
    final s = await repo.read();
    expect(s?.accessToken, 'a');
    expect(s?.refreshToken, 'r');
    await repo.clear();
    expect(await repo.read(), isNull);
  });
}
```

`test/features/auth/session_controller_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockAuthApi api;
  late InMemorySecureStore store;
  late ProviderContainer container;

  setUp(() {
    api = MockAuthApi();
    store = InMemorySecureStore();
    container = ProviderContainer(overrides: [
      secureStoreProvider.overrideWithValue(store),
      authApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  });

  test('build reads persisted session', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    final s = await container.read(sessionControllerProvider.future);
    expect(s?.accessToken, 'a');
  });

  test('login stores session on success', () async {
    when(() => api.login('u', 'p'))
        .thenAnswer((_) async => const Session(accessToken: 'a', refreshToken: 'r'));
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).login('u', 'p');
    expect(container.read(sessionControllerProvider).value?.refreshToken, 'r');
    expect(await store.read('refresh_token'), 'r');
  });

  test('login exposes failure and keeps session null', () async {
    when(() => api.login(any(), any())).thenThrow(const UnauthorizedFailure());
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).login('u', 'bad');
    final state = container.read(sessionControllerProvider);
    expect(state.error, isA<UnauthorizedFailure>());
    expect(state.value, isNull);
  });

  test('logout clears session and store', () async {
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
    await container.read(sessionControllerProvider.future);
    await container.read(sessionControllerProvider.notifier).logout();
    expect(container.read(sessionControllerProvider).value, isNull);
    expect(await store.read('access_token'), isNull);
  });

  group('DioAuthApi', () {
    test('posts credentials and parses tokens', () async {
      final dio = MockDio();
      when(() => dio.post<dynamic>('/auth/login', data: {'username': 'u', 'password': 'p'}))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/auth/login'),
                statusCode: 200,
                data: {
                  'status': 'success',
                  'data': {'id': 1, 'username': 'u', 'accessToken': 'A', 'refreshToken': 'R'},
                },
              ));
      final s = await DioAuthApi(dio).login('u', 'p');
      expect(s.accessToken, 'A');
      expect(s.refreshToken, 'R');
    });

    test('maps 404 to UnauthorizedFailure', () async {
      final dio = MockDio();
      final req = RequestOptions(path: '/auth/login');
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenThrow(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 404, data: {'status': 'fail', 'data': 'Invalid Credentials'}),
      ));
      expect(() => DioAuthApi(dio).login('u', 'p'), throwsA(isA<UnauthorizedFailure>()));
    });
  });
}
```

`test/features/auth/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockAuthApi extends Mock implements AuthApi {}

void main() {
  testWidgets('renders fields and flashes invalid credentials', (tester) async {
    final api = MockAuthApi();
    when(() => api.login(any(), any())).thenThrow(const UnauthorizedFailure());
    await pumpApp(tester, const LoginScreen(), overrides: [
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      authApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('DeCare HMS'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'doc');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Login: Invalid username or password'), findsOneWidget);
    verify(() => api.login('doc', 'pw')).called(1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('eye icon toggles password visibility', (tester) async {
    await pumpApp(tester, const LoginScreen(), overrides: [
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      authApiProvider.overrideWithValue(MockAuthApi()),
    ]);
    await tester.pumpAndSettle();
    TextField password() => tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/features/auth
```

- [ ] **Step 3: Implement data layer**

`lib/features/auth/data/session.dart`:

```dart
import 'package:hms_uploader/core/utils/jwt.dart';

class Session {
  const Session({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// The React Native app treated a session as restorable while the refresh
  /// token's `exp` was in the future. Same rule here.
  bool isValid({DateTime? now}) => isJwtValid(refreshToken, now: now);
}
```

`lib/features/auth/data/session_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/data/session.dart';

class SessionRepository {
  SessionRepository(this._store);

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  final SecureStore _store;

  Future<Session?> read() async {
    final access = await _store.read(_accessKey);
    final refresh = await _store.read(_refreshKey);
    if (access == null || refresh == null) return null;
    return Session(accessToken: access, refreshToken: refresh);
  }

  Future<void> save(Session s) async {
    await _store.write(_accessKey, s.accessToken);
    await _store.write(_refreshKey, s.refreshToken);
  }

  Future<void> clear() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(secureStoreProvider)),
);
```

`lib/features/auth/data/auth_api.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/auth/data/session.dart';

abstract class AuthApi {
  Future<Session> login(String username, String password);
}

class DioAuthApi implements AuthApi {
  DioAuthApi(this._dio);

  final Dio _dio;

  @override
  Future<Session> login(String username, String password) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = unwrapEnvelope(response.data);
      if (data is! Map) throw const BadDataFailure();
      final access = data['accessToken'];
      final refresh = data['refreshToken'];
      if (access is! String || refresh is! String) throw const BadDataFailure();
      return Session(accessToken: access, refreshToken: refresh);
    } catch (e) {
      final failure = ApiFailure.from(e);
      // The server answers 404 "Invalid Credentials" for a bad login.
      if (failure is NotFoundFailure || failure is UnauthorizedFailure) {
        throw const UnauthorizedFailure();
      }
      throw failure;
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) => DioAuthApi(ref.watch(dioProvider)));
```

- [ ] **Step 4: Implement controller**

`lib/features/auth/application/session_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/auth/data/auth_api.dart';
import 'package:hms_uploader/features/auth/data/session.dart';
import 'package:hms_uploader/features/auth/data/session_repository.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.watch(sessionRepositoryProvider).read();

  Future<void> login(String username, String password) async {
    state = const AsyncLoading<Session?>().copyWithPrevious(state);
    try {
      final session = await ref.read(authApiProvider).login(username, password);
      await ref.read(sessionRepositoryProvider).save(session);
      state = AsyncData(session);
    } catch (e, st) {
      state = AsyncError<Session?>(e, st).copyWithPrevious(state);
    }
  }

  Future<void> logout() async {
    await ref.read(sessionRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
```

- [ ] **Step 5: Implement screen and barrel**

`lib/features/auth/presentation/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/application/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signIn() {
    FocusScope.of(context).unfocus();
    ref.read(sessionControllerProvider.notifier).login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(sessionControllerProvider, (prev, next) {
      if (next.isLoading) return;
      final error = next.error;
      if (next.hasError && error is ApiFailure) {
        final text = (error is UnauthorizedFailure || error is NotFoundFailure)
            ? l10n.errorInvalidCredentials
            : error.describe(l10n);
        showFlash(context, l10n.loginError(text), type: FlashType.danger);
      } else if (next.hasValue && next.value != null && prev?.value == null) {
        _username.clear();
        _password.clear();
      }
    });
    final signingIn = ref.watch(sessionControllerProvider).isLoading;

    return ExitOnDoubleBack(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset('assets/images/hms_circle.svg', width: 60, height: 60),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.appTitle, style: AppTextStyles.brandLarge),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppTextField(
                  controller: _username,
                  label: l10n.loginUsername,
                  textInputAction: TextInputAction.next,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _password,
                  label: l10n.loginPassword,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _signIn(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.searchBorder,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: l10n.loginSignIn, loading: signingIn, onPressed: _signIn),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: LinkButton(
                    label: l10n.loginChangeUrl,
                    color: AppColors.dim,
                    onPressed: () => context.push(RoutePaths.configure),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/features/auth/auth.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/presentation/login_screen.dart';

export 'application/session_controller.dart';
export 'data/auth_api.dart';
export 'data/session.dart';
export 'data/session_repository.dart';
export 'presentation/login_screen.dart';

final GoRoute loginRoute = GoRoute(
  path: RoutePaths.login,
  builder: (context, state) => const LoginScreen(),
);
```

Note: `LoginScreen` uses `context.push`, which requires a `GoRouter` ancestor. In `login_screen_test.dart` the "Change URL" link is not tapped, so no router is needed.

- [ ] **Step 6: Run tests and analyzer**

```bash
flutter test test/features test/core && flutter analyze
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/auth test/features/auth
git commit -m "feat(auth): login, secure session storage and session controller"
```

---

### Task 8: Feature `patient_lookup` (Home: OP search and recent searches) plus SVG illustrations

**Files:**
- Create: `tool/convert_rn_svg.js`, `assets/images/blank_canvas.svg`, `assets/images/add_tomogram.svg`, `lib/features/patient_lookup/patient_lookup.dart`, `lib/features/patient_lookup/data/patient.dart`, `lib/features/patient_lookup/data/op_register_api.dart`, `lib/features/patient_lookup/data/recent_searches_repository.dart`, `lib/features/patient_lookup/application/recent_searches_controller.dart`, `lib/features/patient_lookup/application/patient_lookup_controller.dart`, `lib/features/patient_lookup/presentation/home_screen.dart`, `lib/features/patient_lookup/presentation/widgets/op_search_bar.dart`, `lib/features/patient_lookup/presentation/widgets/recent_search_row.dart`, `lib/features/patient_lookup/presentation/widgets/home_empty_state.dart`
- Test: `test/assets/svg_assets_test.dart`, `test/features/patient_lookup/patient_test.dart`, `test/features/patient_lookup/recent_searches_controller_test.dart`, `test/features/patient_lookup/patient_lookup_controller_test.dart`, `test/features/patient_lookup/home_screen_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `dioProvider`, `unwrapEnvelope`, `ApiFailure`, `RoutePaths`, Task 5 widgets.
- Produces:
  - `class Patient { const Patient({required int id, required int opid, required String name}); factory Patient.fromJson(Map); Map<String, dynamic> toJson(); }` with `==`/`hashCode`.
  - `abstract class OpRegisterApi { Future<Patient> getByOpId(int opid); }`, `class DioOpRegisterApi implements OpRegisterApi { DioOpRegisterApi(Dio dio); }`, `opRegisterApiProvider`.
  - `class RecentSearchesRepository { RecentSearchesRepository(SharedPreferences); List<Patient> read(); Future<void> write(List<Patient>); }`, `recentSearchesRepositoryProvider`.
  - `class RecentSearchesController extends Notifier<List<Patient>> { void add(Patient); void remove(int id); void clear(); }`, `recentSearchesControllerProvider`, `const int recentSearchesCap = 10`.
  - `class PatientLookupController extends AutoDisposeAsyncNotifier<Patient?> { Future<Patient?> search(int opid); }`, `patientLookupControllerProvider`.
  - `GoRoute homeRoute({required List<RouteBase> children})` (path `RoutePaths.home`), `class HomeScreen extends ConsumerStatefulWidget`.

- [ ] **Step 1: Convert the two React Native SVG components to `.svg` files**

Create `tool/convert_rn_svg.js`:

```js
// Converts a react-native-svg JSX component into a plain SVG file.
// Usage: node tool/convert_rn_svg.js <input.tsx> <output.svg>
const fs = require('fs');

const [, , input, output] = process.argv;
let s = fs.readFileSync(input, 'utf8');
const start = s.indexOf('<Svg');
const end = s.indexOf('</Svg>') + '</Svg>'.length;
s = s.slice(start, end);

s = s.replace(/^\s*\/\/.*$/gm, ''); // JSX line comments inside tags
s = s.replace(/\{\.\.\.props\}/g, '');
s = s.replace(/=\{([\d.]+)\}/g, '="$1"'); // width={70.454} -> width="70.454"
s = s.replace(/'/g, '"');

const tags = {
  Svg: 'svg', Path: 'path', Circle: 'circle', G: 'g', Rect: 'rect', Defs: 'defs',
  ClipPath: 'clipPath', Use: 'use', Stop: 'stop', LinearGradient: 'linearGradient',
  Image: 'image', Ellipse: 'ellipse', Line: 'line', Polygon: 'polygon', Polyline: 'polyline',
};
for (const [jsx, svg] of Object.entries(tags)) {
  s = s.replace(new RegExp(`<${jsx}(?=[\\s>/])`, 'g'), `<${svg}`);
  s = s.replace(new RegExp(`</${jsx}>`, 'g'), `</${svg}>`);
}

const attrs = {
  strokeWidth: 'stroke-width', strokeLinecap: 'stroke-linecap', strokeLinejoin: 'stroke-linejoin',
  strokeDasharray: 'stroke-dasharray', strokeMiterlimit: 'stroke-miterlimit',
  fillRule: 'fill-rule', clipRule: 'clip-rule', fillOpacity: 'fill-opacity',
  strokeOpacity: 'stroke-opacity', xlinkHref: 'xlink:href',
};
for (const [jsx, svg] of Object.entries(attrs)) {
  s = s.replace(new RegExp(`\\b${jsx}=`, 'g'), `${svg}=`);
}

// Root <svg>: drop width/height (Flutter sizes by viewBox) and ensure xmlns.
s = s.replace(/<svg([^>]*)>/, (m, inner) => {
  let a = inner.replace(/\s(width|height)="[^"]*"/g, '');
  if (!/xmlns=/.test(a)) a = ` xmlns="http://www.w3.org/2000/svg"${a}`;
  return `<svg${a}>`;
});

fs.writeFileSync(output, s.trim() + '\n');
console.log(`wrote ${output}`);
```

Run:

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
RN="E:/Projects/personal/deCare/hms/HMSUploader/app/screens"
node tool/convert_rn_svg.js "$RN/home/BlankCanvasSvg.tsx" assets/images/blank_canvas.svg
node tool/convert_rn_svg.js "$RN/patient/AddTomogramSvg.tsx" assets/images/add_tomogram.svg
head -c 300 assets/images/blank_canvas.svg
```

Expected: both files start with `<svg xmlns="http://www.w3.org/2000/svg" ... viewBox="...">` and contain only lowercase tags. Open each file and confirm no `{`, `}`, or capitalised tag remains: `grep -nE "[{}]|<[A-Z]" assets/images/*.svg` prints nothing.

- [ ] **Step 2: Add an SVG parse test**

```bash
flutter pub add dev:vector_graphics_compiler
```

`test/assets/svg_assets_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

void main() {
  for (final name in ['blank_canvas.svg', 'add_tomogram.svg', 'hms_circle.svg']) {
    test('$name parses as vector graphics', () {
      final xml = File('assets/images/$name').readAsStringSync();
      final bytes = encodeSvg(xml: xml, debugName: name);
      expect(bytes, isNotEmpty);
    });
  }
}
```

Run `flutter test test/assets`. Expected: PASS. If `hms_circle.svg` fails to parse, inspect the error; the most common cause is an unsupported `<style>` block, in which case inline the styles into attributes.

- [ ] **Step 3: Write failing model and controller tests**

`test/features/patient_lookup/patient_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';

void main() {
  test('json round trip and equality', () {
    const p = Patient(id: 1, opid: 123, name: 'Jane');
    expect(Patient.fromJson(p.toJson()), p);
    expect(Patient.fromJson({'id': 1, 'opid': 123, 'name': 'Jane', 'extra': true}), p);
  });
  test('fromJson tolerates numeric strings', () {
    expect(Patient.fromJson({'id': '1', 'opid': '7', 'name': 'x'}), const Patient(id: 1, opid: 7, name: 'x'));
  });
}
```

`test/features/patient_lookup/recent_searches_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:shared_preferences/shared_preferences.dart';

Patient p(int id) => Patient(id: id, opid: id * 10, name: 'P$id');

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
  });

  test('add puts newest first, dedupes by id and caps at 10', () {
    final c = container.read(recentSearchesControllerProvider.notifier);
    for (var i = 1; i <= 12; i++) {
      c.add(p(i));
    }
    var list = container.read(recentSearchesControllerProvider);
    expect(list.length, recentSearchesCap);
    expect(list.first, p(12));
    expect(list.last, p(3));
    c.add(p(5));
    list = container.read(recentSearchesControllerProvider);
    expect(list.first, p(5));
    expect(list.where((x) => x.id == 5).length, 1);
    expect(list.length, recentSearchesCap);
  });

  test('remove and clear persist', () async {
    final c = container.read(recentSearchesControllerProvider.notifier);
    c.add(p(1));
    c.add(p(2));
    c.remove(1);
    expect(container.read(recentSearchesControllerProvider), [p(2)]);
    expect(container.read(recentSearchesRepositoryProvider).read(), [p(2)]);
    c.clear();
    expect(container.read(recentSearchesControllerProvider), isEmpty);
    expect(container.read(recentSearchesRepositoryProvider).read(), isEmpty);
  });
}
```

`test/features/patient_lookup/patient_lookup_controller_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOpRegisterApi extends Mock implements OpRegisterApi {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockOpRegisterApi api;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = MockOpRegisterApi();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  });

  test('search returns patient and records it in recents', () async {
    const jane = Patient(id: 1, opid: 42, name: 'Jane');
    when(() => api.getByOpId(42)).thenAnswer((_) async => jane);
    final sub = container.listen(patientLookupControllerProvider, (_, __) {});
    final result = await container.read(patientLookupControllerProvider.notifier).search(42);
    expect(result, jane);
    expect(container.read(patientLookupControllerProvider).value, jane);
    expect(container.read(recentSearchesControllerProvider), [jane]);
    sub.close();
  });

  test('search failure exposes error and records nothing', () async {
    when(() => api.getByOpId(any())).thenThrow(const NotFoundFailure('Invalid OP Number'));
    final sub = container.listen(patientLookupControllerProvider, (_, __) {});
    final result = await container.read(patientLookupControllerProvider.notifier).search(1);
    expect(result, isNull);
    expect(container.read(patientLookupControllerProvider).error, isA<NotFoundFailure>());
    expect(container.read(recentSearchesControllerProvider), isEmpty);
    sub.close();
  });

  test('DioOpRegisterApi queries opid and parses patient', () async {
    final dio = MockDio();
    when(() => dio.get<dynamic>('/opregister', queryParameters: {'opid': 42})).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/opregister'),
        statusCode: 200,
        data: {'status': 'success', 'data': {'id': 9, 'opid': 42, 'name': 'Jane'}},
      ),
    );
    expect(await DioOpRegisterApi(dio).getByOpId(42), const Patient(id: 9, opid: 42, name: 'Jane'));
  });
}
```

- [ ] **Step 4: Run tests, expect failure**

```bash
flutter test test/features/patient_lookup
```

- [ ] **Step 5: Implement data layer**

`lib/features/patient_lookup/data/patient.dart`:

```dart
class Patient {
  const Patient({required this.id, required this.opid, required this.name});

  final int id;
  final int opid;
  final String name;

  factory Patient.fromJson(Map<dynamic, dynamic> json) => Patient(
        id: _int(json['id']),
        opid: _int(json['opid']),
        name: (json['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'opid': opid, 'name': name};

  static int _int(dynamic v) => v is int ? v : int.parse(v.toString());

  @override
  bool operator ==(Object other) =>
      other is Patient && other.id == id && other.opid == opid && other.name == name;

  @override
  int get hashCode => Object.hash(id, opid, name);

  @override
  String toString() => 'Patient($id, $opid, $name)';
}
```

`lib/features/patient_lookup/data/op_register_api.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

abstract class OpRegisterApi {
  Future<Patient> getByOpId(int opid);
}

class DioOpRegisterApi implements OpRegisterApi {
  DioOpRegisterApi(this._dio);

  final Dio _dio;

  @override
  Future<Patient> getByOpId(int opid) async {
    try {
      final response = await _dio.get<dynamic>('/opregister', queryParameters: {'opid': opid});
      final data = unwrapEnvelope(response.data);
      if (data is! Map) throw const BadDataFailure();
      return Patient.fromJson(data);
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

final opRegisterApiProvider = Provider<OpRegisterApi>((ref) => DioOpRegisterApi(ref.watch(dioProvider)));
```

`lib/features/patient_lookup/data/recent_searches_repository.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesRepository {
  RecentSearchesRepository(this._prefs);

  static const _key = 'recent_searches';
  final SharedPreferences _prefs;

  List<Patient> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.whereType<Map>().map(Patient.fromJson).toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<Patient> patients) =>
      _prefs.setString(_key, jsonEncode(patients.map((p) => p.toJson()).toList()));
}

final recentSearchesRepositoryProvider = Provider<RecentSearchesRepository>(
  (ref) => RecentSearchesRepository(ref.watch(sharedPreferencesProvider)),
);
```

- [ ] **Step 6: Implement controllers**

`lib/features/patient_lookup/application/recent_searches_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:hms_uploader/features/patient_lookup/data/recent_searches_repository.dart';

const int recentSearchesCap = 10;

class RecentSearchesController extends Notifier<List<Patient>> {
  @override
  List<Patient> build() => ref.watch(recentSearchesRepositoryProvider).read();

  void add(Patient patient) {
    final next = [patient, ...state.where((p) => p.id != patient.id)];
    _set(next.length > recentSearchesCap ? next.sublist(0, recentSearchesCap) : next);
  }

  void remove(int id) => _set(state.where((p) => p.id != id).toList());

  void clear() => _set(const []);

  void _set(List<Patient> next) {
    state = next;
    ref.read(recentSearchesRepositoryProvider).write(next);
  }
}

final recentSearchesControllerProvider =
    NotifierProvider<RecentSearchesController, List<Patient>>(RecentSearchesController.new);
```

`lib/features/patient_lookup/application/patient_lookup_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/patient_lookup/application/recent_searches_controller.dart';
import 'package:hms_uploader/features/patient_lookup/data/op_register_api.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

/// Looks a patient up by OP number. Successful lookups are pushed into recents.
class PatientLookupController extends AutoDisposeAsyncNotifier<Patient?> {
  @override
  Future<Patient?> build() async => null;

  /// Returns the patient on success, null on failure (state carries the error).
  Future<Patient?> search(int opid) async {
    state = const AsyncLoading<Patient?>().copyWithPrevious(state);
    try {
      final patient = await ref.read(opRegisterApiProvider).getByOpId(opid);
      ref.read(recentSearchesControllerProvider.notifier).add(patient);
      state = AsyncData(patient);
      return patient;
    } catch (e, st) {
      state = AsyncError<Patient?>(e, st).copyWithPrevious(state);
      return null;
    }
  }
}

final patientLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<PatientLookupController, Patient?>(PatientLookupController.new);
```

- [ ] **Step 7: Run model and controller tests**

```bash
flutter test test/features/patient_lookup
```
Expected: PASS for the three files written so far.

- [ ] **Step 8: Write failing Home screen test**

`test/features/patient_lookup/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockOpRegisterApi extends Mock implements OpRegisterApi {}

void main() {
  late MockOpRegisterApi api;

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  setUp(() => api = MockOpRegisterApi());

  testWidgets('shows empty state when no recent searches', (tester) async {
    final prefs = await prefsWith({});
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('There is no patient selected.'), findsOneWidget);
    expect(find.text('Enter OP Number'), findsOneWidget);
  });

  testWidgets('lists recent searches and clears them', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"},{"id":2,"opid":34,"name":"Bob"}]',
    });
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('Jane, 12'), findsOneWidget);
    expect(find.text('Bob, 34'), findsOneWidget);
    await tester.tap(find.text('clear all'));
    await tester.pump();
    expect(find.text('Jane, 12'), findsNothing);
    expect(find.text('There is no patient selected.'), findsOneWidget);
  });

  testWidgets('submitting an OP number looks it up and reports the patient', (tester) async {
    final prefs = await prefsWith({});
    const jane = Patient(id: 1, opid: 42, name: 'Jane');
    when(() => api.getByOpId(42)).thenAnswer((_) async => jane);
    Patient? selected;
    await pumpApp(tester, HomeScreen(onPatientSelected: (p) => selected = p), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '42');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(selected, jane);
    expect(find.text('Jane, 42'), findsOneWidget);
  });

  testWidgets('lookup failure flashes Patient error', (tester) async {
    final prefs = await prefsWith({});
    when(() => api.getByOpId(any())).thenThrow(const NotFoundFailure('Invalid OP Number'));
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patient: Invalid OP Number'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 9: Implement presentation**

`lib/features/patient_lookup/presentation/widgets/op_search_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Numeric OP-number field with clear and submit buttons.
class OpSearchBar extends StatefulWidget {
  const OpSearchBar({super.key, required this.onSubmit});

  final ValueChanged<int> onSubmit;

  @override
  State<OpSearchBar> createState() => _OpSearchBarState();
}

class _OpSearchBarState extends State<OpSearchBar> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final opid = int.tryParse(_controller.text.trim());
    if (opid == null) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(opid);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _controller,
              hint: context.l10n.homeSearchPlaceholder,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 7,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              suffix: hasText
                  ? IconButton(icon: const Icon(Icons.close, color: AppColors.dim), onPressed: _controller.clear)
                  : const Icon(Icons.search, color: AppColors.dim),
            ),
          ),
          if (hasText) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.check, color: AppColors.goGreen),
              onPressed: _submit,
            ),
          ],
        ],
      ),
    );
  }
}
```

`lib/features/patient_lookup/presentation/widgets/recent_search_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

class RecentSearchRow extends StatelessWidget {
  const RecentSearchRow({super.key, required this.patient, required this.onTap, required this.onDelete});

  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.rowGrey,
      elevation: 1,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.homeRecentRow(patient.name, patient.opid),
                  style: AppTextStyles.body,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/patient_lookup/presentation/widgets/home_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HideWithKeyboard(
            child: SvgPicture.asset('assets/images/blank_canvas.svg', width: 220, height: 220),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.homeEmptyTitle, style: AppTextStyles.bold, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxs),
          Text(l10n.homeEmptyBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

`lib/features/patient_lookup/presentation/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/widgets/loader_modal.dart';
import 'package:hms_uploader/features/patient_lookup/application/patient_lookup_controller.dart';
import 'package:hms_uploader/features/patient_lookup/application/recent_searches_controller.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/home_empty_state.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/op_search_bar.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/recent_search_row.dart';

/// Home: OP number search plus recent searches. [onPatientSelected] fires
/// after a successful lookup (the route wires it to the tomogram screen).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, required this.onPatientSelected});

  final ValueChanged<Patient> onPatientSelected;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _lookup(int opid) async {
    final patient = await ref.read(patientLookupControllerProvider.notifier).search(opid);
    if (patient != null && mounted) widget.onPatientSelected(patient);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(patientLookupControllerProvider, (prev, next) {
      final error = next.error;
      if (!next.isLoading && next.hasError && error is ApiFailure) {
        showFlash(context, l10n.homePatientError(error.describe(l10n)), type: FlashType.danger);
      }
    });
    final loading = ref.watch(patientLookupControllerProvider).isLoading;
    final recents = ref.watch(recentSearchesControllerProvider);

    return ExitOnDoubleBack(
      child: LoaderModal(
        visible: loading,
        text: l10n.homeFetchingPatient,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              AppHeader(title: l10n.commonHeader),
              Expanded(
                child: recents.isEmpty
                    ? const HomeEmptyState()
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.homeRecentSearches, style: AppTextStyles.bold),
                              LinkButton(
                                label: l10n.homeClearAll,
                                color: AppColors.dim,
                                onPressed: () => ref.read(recentSearchesControllerProvider.notifier).clear(),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          for (final p in recents)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                              child: RecentSearchRow(
                                patient: p,
                                onTap: () => _lookup(p.opid),
                                onDelete: () => ref.read(recentSearchesControllerProvider.notifier).remove(p.id),
                              ),
                            ),
                        ],
                      ),
              ),
              OpSearchBar(onSubmit: _lookup),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/patient_lookup/patient_lookup.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/home_screen.dart';

export 'application/patient_lookup_controller.dart';
export 'application/recent_searches_controller.dart';
export 'data/op_register_api.dart';
export 'data/patient.dart';
export 'data/recent_searches_repository.dart';
export 'presentation/home_screen.dart';

/// Home route. [children] are nested routes (tomogram, permission) supplied by
/// the router so this feature does not depend on them.
GoRoute homeRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.home,
      builder: (context, state) => HomeScreen(
        onPatientSelected: (patient) => context.push(RoutePaths.tomogram(patient.opid), extra: patient),
      ),
      routes: children,
    );
```

- [ ] **Step 10: Run all tests and analyzer**

```bash
flutter test && flutter analyze
```

- [ ] **Step 11: Commit**

```bash
git add tool assets test/assets lib/features/patient_lookup test/features/patient_lookup pubspec.yaml pubspec.lock
git commit -m "feat(patient_lookup): home screen with OP search and recent searches; SVG illustrations"
```

---

### Task 9: Feature `tomogram` data and application layers

**Files:**
- Create: `lib/features/tomogram/data/tomogram_draft.dart`, `lib/features/tomogram/data/upload_result.dart`, `lib/features/tomogram/data/tomogram_api.dart`, `lib/features/tomogram/application/tomogram_controller.dart`, `lib/features/tomogram/application/permission_gateway.dart`, `lib/features/tomogram/application/media_picker_service.dart`
- Test: `test/features/tomogram/tomogram_api_test.dart`, `test/features/tomogram/tomogram_controller_test.dart`, `test/features/tomogram/media_picker_service_test.dart`

**Interfaces:**
- Consumes: `dioProvider`, `uploadTimeout`, `unwrapEnvelope`, `ApiFailure`, `isJpegFile`, `deleteFiles`.
- Produces:
  - `class TomogramDraft { const TomogramDraft({required String id, required String filePath, this.description = ''}); TomogramDraft copyWith({String? description}); }`.
  - `class UploadResult { final int id; final int masterid; final int tomogrampartid; final String narration; factory UploadResult.fromJson(Map); }`.
  - `abstract class TomogramApi { Future<List<UploadResult>> upload(int opid, List<TomogramDraft> drafts); }`, `class DioTomogramApi implements TomogramApi { DioTomogramApi(Dio dio); }`, `tomogramApiProvider`.
  - `class TomogramState { final List<TomogramDraft> drafts; final bool uploading; }`.
  - `class TomogramController extends AutoDisposeFamilyNotifier<TomogramState, int> { void addFiles(List<String> paths); Future<void> remove(String id); void updateDescription(String id, String text); Future<void> clearAll(); Future<void> upload(); }`, `tomogramControllerProvider` (`NotifierProvider.autoDispose.family`), `uuidProvider = Provider<String Function()>`.
  - `abstract class PermissionGateway { Future<bool> request(Permission p); Future<bool> isGranted(Permission p); Future<bool> openSettings(); }`, `class HandlerPermissionGateway implements PermissionGateway`, `permissionGatewayProvider`.
  - `enum MediaSource { camera, gallery }`, `class MediaPickResult { final List<String> accepted; final int rejected; }`, `abstract class MediaPickerService { List<Permission> permissionsFor(MediaSource s); Future<List<Permission>> deniedPermissions(MediaSource s); Future<MediaPickResult> pick(MediaSource s); }`, `class DefaultMediaPickerService implements MediaPickerService { DefaultMediaPickerService({required ImagePicker picker, required PermissionGateway permissions}); }`, `mediaPickerServiceProvider`, `const int galleryPickLimit = 2`.

- [ ] **Step 1: Write failing tests**

`test/features/tomogram/tomogram_api_test.dart`:

```dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tomo'));
  tearDown(() => dir.delete(recursive: true));

  setUpAll(() {
    registerFallbackValue(Options());
  });

  test('upload builds multipart with opid, images and narrations', () async {
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1]);
    final b = File('${dir.path}/b.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 2]);
    final dio = MockDio();
    when(() => dio.post<dynamic>('/tomogram', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/tomogram'),
              statusCode: 200,
              data: {
                'status': 'success',
                'data': [
                  {'id': 1, 'masterid': 7, 'tomogrampartid': 2, 'narration': 'left arm'},
                ],
              },
            ));

    final results = await DioTomogramApi(dio).upload(42, [
      TomogramDraft(id: 'aaa', filePath: a.path, description: 'left arm'),
      TomogramDraft(id: 'bbb', filePath: b.path, description: 'right arm'),
    ]);

    expect(results.single.masterid, 7);
    final captured = verify(() => dio.post<dynamic>('/tomogram',
        data: captureAny(named: 'data'), options: captureAny(named: 'options'))).captured;
    final form = captured[0] as FormData;
    final options = captured[1] as Options;
    expect(form.fields, containsAll([
      const MapEntry('opid', '42'),
      const MapEntry('narrations[0]', 'left arm'),
      const MapEntry('narrations[1]', 'right arm'),
    ]));
    expect(form.files.map((e) => e.key), ['images', 'images']);
    expect(form.files.map((e) => e.value.filename), ['imageaaa.jpg', 'imagebbb.jpg']);
    expect(form.files.first.value.contentType.toString(), 'image/jpeg');
    expect(options.sendTimeout, uploadTimeout);
    expect(options.receiveTimeout, uploadTimeout);
  });

  test('upload maps errors to ApiFailure', () async {
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    final dio = MockDio();
    final req = RequestOptions(path: '/tomogram');
    when(() => dio.post<dynamic>(any(), data: any(named: 'data'), options: any(named: 'options')))
        .thenThrow(DioException(requestOptions: req, type: DioExceptionType.sendTimeout));
    expect(
      () => DioTomogramApi(dio).upload(1, [TomogramDraft(id: 'x', filePath: a.path)]),
      throwsA(isA<TimeoutFailure>()),
    );
  });
}
```

`test/features/tomogram/tomogram_controller_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

void main() {
  late Directory dir;
  late MockTomogramApi api;
  late ProviderContainer container;
  var counter = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_ctrl');
    api = MockTomogramApi();
    counter = 0;
    container = ProviderContainer(overrides: [
      tomogramApiProvider.overrideWithValue(api),
      uuidProvider.overrideWithValue(() => 'id${++counter}'),
    ]);
    addTearDown(container.dispose);
  });
  tearDown(() => dir.delete(recursive: true));

  File make(String name) => File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

  test('addFiles, updateDescription, remove', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path, b.path]);
    expect(container.read(tomogramControllerProvider(42)).drafts.map((d) => d.id), ['id1', 'id2']);
    c.updateDescription('id1', 'left');
    expect(container.read(tomogramControllerProvider(42)).drafts.first.description, 'left');
    await c.remove('id1');
    expect(container.read(tomogramControllerProvider(42)).drafts.map((d) => d.id), ['id2']);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isTrue);
    sub.close();
  });

  test('upload sends drafts, deletes files and clears state', () async {
    final a = make('a.jpg');
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path]);
    await c.upload();
    verify(() => api.upload(42, any(that: hasLength(1)))).called(1);
    expect(container.read(tomogramControllerProvider(42)).drafts, isEmpty);
    expect(container.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isFalse);
    sub.close();
  });

  test('upload failure keeps drafts and files and rethrows', () async {
    final a = make('a.jpg');
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path]);
    await expectLater(c.upload(), throwsA(isA<TimeoutFailure>()));
    expect(container.read(tomogramControllerProvider(42)).drafts, hasLength(1));
    expect(container.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isTrue);
    sub.close();
  });

  test('clearAll deletes files', () async {
    final a = make('a.jpg');
    final sub = container.listen(tomogramControllerProvider(1), (_, __) {});
    final c = container.read(tomogramControllerProvider(1).notifier);
    c.addFiles([a.path]);
    await c.clearAll();
    expect(container.read(tomogramControllerProvider(1)).drafts, isEmpty);
    expect(a.existsSync(), isFalse);
    sub.close();
  });
}
```

`test/features/tomogram/media_picker_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

class MockImagePicker extends Mock implements ImagePicker {}

class MockPermissionGateway extends Mock implements PermissionGateway {}

void main() {
  late Directory dir;
  late MockImagePicker picker;
  late MockPermissionGateway permissions;
  late DefaultMediaPickerService service;

  setUpAll(() => registerFallbackValue(Permission.camera));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('picker');
    picker = MockImagePicker();
    permissions = MockPermissionGateway();
    service = DefaultMediaPickerService(picker: picker, permissions: permissions);
  });
  tearDown(() => dir.delete(recursive: true));

  File jpeg(String n) => File('${dir.path}/$n')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
  File png(String n) => File('${dir.path}/$n')..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

  test('deniedPermissions requests and returns what was refused', () async {
    when(() => permissions.request(Permission.camera)).thenAnswer((_) async => false);
    expect(await service.deniedPermissions(MediaSource.camera), [Permission.camera]);
    when(() => permissions.request(Permission.photos)).thenAnswer((_) async => true);
    expect(await service.deniedPermissions(MediaSource.gallery), isEmpty);
  });

  test('gallery pick keeps at most two JPEGs and counts rejects', () async {
    final a = jpeg('a.jpg');
    final b = png('b.png');
    final c = jpeg('c.jpg');
    final d = jpeg('d.jpg');
    when(() => picker.pickMultiImage()).thenAnswer((_) async => [XFile(a.path), XFile(b.path), XFile(c.path), XFile(d.path)]);
    final result = await service.pick(MediaSource.gallery);
    expect(result.accepted, [a.path, c.path]);
    expect(result.rejected, 1);
  });

  test('camera pick returns single JPEG or nothing', () async {
    final a = jpeg('a.jpg');
    when(() => picker.pickImage(source: ImageSource.camera)).thenAnswer((_) async => XFile(a.path));
    expect((await service.pick(MediaSource.camera)).accepted, [a.path]);
    when(() => picker.pickImage(source: ImageSource.camera)).thenAnswer((_) async => null);
    expect((await service.pick(MediaSource.camera)).accepted, isEmpty);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/features/tomogram
```

- [ ] **Step 3: Implement data layer**

`lib/features/tomogram/data/tomogram_draft.dart`:

```dart
class TomogramDraft {
  const TomogramDraft({required this.id, required this.filePath, this.description = ''});

  final String id;
  final String filePath;
  final String description;

  TomogramDraft copyWith({String? description}) =>
      TomogramDraft(id: id, filePath: filePath, description: description ?? this.description);
}
```

`lib/features/tomogram/data/upload_result.dart`:

```dart
class UploadResult {
  const UploadResult({required this.id, required this.masterid, required this.tomogrampartid, required this.narration});

  final int id;
  final int masterid;
  final int tomogrampartid;
  final String narration;

  factory UploadResult.fromJson(Map<dynamic, dynamic> json) => UploadResult(
        id: _int(json['id']),
        masterid: _int(json['masterid']),
        tomogrampartid: _int(json['tomogrampartid']),
        narration: (json['narration'] ?? '').toString(),
      );

  static int _int(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
}
```

`lib/features/tomogram/data/tomogram_api.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:hms_uploader/features/tomogram/data/upload_result.dart';

abstract class TomogramApi {
  Future<List<UploadResult>> upload(int opid, List<TomogramDraft> drafts);
}

/// `POST /tomogram` multipart: `opid`, repeated `images`, `narrations[i]`.
class DioTomogramApi implements TomogramApi {
  DioTomogramApi(this._dio);

  final Dio _dio;

  @override
  Future<List<UploadResult>> upload(int opid, List<TomogramDraft> drafts) async {
    try {
      final form = FormData();
      form.fields.add(MapEntry('opid', opid.toString()));
      for (var i = 0; i < drafts.length; i++) {
        final d = drafts[i];
        form.files.add(MapEntry(
          'images',
          await MultipartFile.fromFile(
            d.filePath,
            filename: 'image${d.id}.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ));
        form.fields.add(MapEntry('narrations[$i]', d.description));
      }
      final response = await _dio.post<dynamic>(
        '/tomogram',
        data: form,
        options: Options(sendTimeout: uploadTimeout, receiveTimeout: uploadTimeout),
      );
      final data = unwrapEnvelope(response.data);
      if (data is! List) return const [];
      return data.whereType<Map>().map(UploadResult.fromJson).toList();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }
}

final tomogramApiProvider = Provider<TomogramApi>((ref) => DioTomogramApi(ref.watch(dioProvider)));
```

- [ ] **Step 4: Implement application layer**

`lib/features/tomogram/application/permission_gateway.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin seam over permission_handler so controllers and screens are testable.
abstract class PermissionGateway {
  Future<bool> request(Permission permission);
  Future<bool> isGranted(Permission permission);
  Future<bool> openSettings();
}

class HandlerPermissionGateway implements PermissionGateway {
  @override
  Future<bool> request(Permission permission) async {
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}

final permissionGatewayProvider = Provider<PermissionGateway>((ref) => HandlerPermissionGateway());
```

`lib/features/tomogram/application/media_picker_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/jpeg.dart';
import 'package:hms_uploader/features/tomogram/application/permission_gateway.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum MediaSource { camera, gallery }

/// The React Native app allowed two gallery images per pick.
const int galleryPickLimit = 2;

class MediaPickResult {
  const MediaPickResult({required this.accepted, required this.rejected});

  final List<String> accepted;
  final int rejected;

  static const empty = MediaPickResult(accepted: [], rejected: 0);
}

abstract class MediaPickerService {
  List<Permission> permissionsFor(MediaSource source);
  Future<List<Permission>> deniedPermissions(MediaSource source);
  Future<MediaPickResult> pick(MediaSource source);
}

class DefaultMediaPickerService implements MediaPickerService {
  DefaultMediaPickerService({required ImagePicker picker, required PermissionGateway permissions})
      : _picker = picker,
        _permissions = permissions;

  final ImagePicker _picker;
  final PermissionGateway _permissions;

  @override
  List<Permission> permissionsFor(MediaSource source) => switch (source) {
        MediaSource.camera => const [Permission.camera],
        MediaSource.gallery => const [Permission.photos],
      };

  @override
  Future<List<Permission>> deniedPermissions(MediaSource source) async {
    final denied = <Permission>[];
    for (final p in permissionsFor(source)) {
      if (!await _permissions.request(p)) denied.add(p);
    }
    return denied;
  }

  @override
  Future<MediaPickResult> pick(MediaSource source) async {
    final files = switch (source) {
      MediaSource.camera => [await _picker.pickImage(source: ImageSource.camera)],
      MediaSource.gallery => await _picker.pickMultiImage(),
    };
    final accepted = <String>[];
    var rejected = 0;
    for (final f in files) {
      if (f == null) continue;
      if (!await isJpegFile(f.path)) {
        rejected++;
        continue;
      }
      if (accepted.length < galleryPickLimit) accepted.add(f.path);
    }
    return MediaPickResult(accepted: accepted, rejected: rejected);
  }
}

final mediaPickerServiceProvider = Provider<MediaPickerService>(
  (ref) => DefaultMediaPickerService(picker: ImagePicker(), permissions: ref.watch(permissionGatewayProvider)),
);
```

`lib/features/tomogram/application/tomogram_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_api.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:uuid/uuid.dart';

final uuidProvider = Provider<String Function()>((ref) => const Uuid().v4);

class TomogramState {
  const TomogramState({this.drafts = const [], this.uploading = false});

  final List<TomogramDraft> drafts;
  final bool uploading;

  TomogramState copyWith({List<TomogramDraft>? drafts, bool? uploading}) =>
      TomogramState(drafts: drafts ?? this.drafts, uploading: uploading ?? this.uploading);
}

/// Per-patient draft list, keyed by OP number. Lives only while the tomogram
/// screen is mounted; leftover files are deleted on dispose.
class TomogramController extends AutoDisposeFamilyNotifier<TomogramState, int> {
  @override
  TomogramState build(int arg) {
    ref.onDispose(() {
      final paths = state.drafts.map((d) => d.filePath).toList();
      if (paths.isNotEmpty) deleteFiles(paths);
    });
    return const TomogramState();
  }

  void addFiles(List<String> paths) {
    final newId = ref.read(uuidProvider);
    state = state.copyWith(drafts: [
      ...state.drafts,
      for (final p in paths) TomogramDraft(id: newId(), filePath: p),
    ]);
  }

  Future<void> remove(String id) async {
    final target = state.drafts.where((d) => d.id == id).toList();
    state = state.copyWith(drafts: state.drafts.where((d) => d.id != id).toList());
    await deleteFiles(target.map((d) => d.filePath));
  }

  void updateDescription(String id, String text) {
    state = state.copyWith(
      drafts: [for (final d in state.drafts) d.id == id ? d.copyWith(description: text) : d],
    );
  }

  Future<void> clearAll() async {
    final paths = state.drafts.map((d) => d.filePath).toList();
    state = state.copyWith(drafts: const []);
    await deleteFiles(paths);
  }

  /// Uploads all drafts. On success drafts are cleared and files deleted.
  /// Throws [ApiFailure] on failure, leaving drafts intact for a retry.
  Future<void> upload() async {
    final drafts = state.drafts;
    if (drafts.isEmpty) return;
    state = state.copyWith(uploading: true);
    try {
      await ref.read(tomogramApiProvider).upload(arg, drafts);
    } catch (e) {
      state = state.copyWith(uploading: false);
      throw ApiFailure.from(e);
    }
    state = const TomogramState();
    await deleteFiles(drafts.map((d) => d.filePath));
  }
}

final tomogramControllerProvider =
    NotifierProvider.autoDispose.family<TomogramController, TomogramState, int>(TomogramController.new);
```

- [ ] **Step 5: Create a provisional barrel so tests compile**

`lib/features/tomogram/tomogram.dart` (Task 10 adds routes to it):

```dart
export 'application/media_picker_service.dart';
export 'application/permission_gateway.dart';
export 'application/tomogram_controller.dart';
export 'data/tomogram_api.dart';
export 'data/tomogram_draft.dart';
export 'data/upload_result.dart';
```

- [ ] **Step 6: Run tests and analyzer**

```bash
flutter test test/features/tomogram && flutter analyze
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/tomogram test/features/tomogram
git commit -m "feat(tomogram): drafts, multipart upload api, controller, media picker service"
```

---

### Task 10: Feature `tomogram` presentation (Tomogram and Permission screens)

**Files:**
- Create: `lib/features/tomogram/presentation/tomogram_screen.dart`, `lib/features/tomogram/presentation/permission_screen.dart`, `lib/features/tomogram/presentation/widgets/tomogram_card.dart`, `lib/features/tomogram/presentation/widgets/patient_bar.dart`, `lib/features/tomogram/presentation/widgets/add_source_sheet.dart`, `lib/features/tomogram/presentation/widgets/tomogram_empty_state.dart`
- Modify: `lib/features/tomogram/tomogram.dart`
- Test: `test/features/tomogram/tomogram_screen_test.dart`, `test/features/tomogram/permission_screen_test.dart`

**Interfaces:**
- Consumes: Task 9 providers, `Patient` (from `patient_lookup` barrel), `RoutePaths`, Task 5 widgets.
- Produces: `class TomogramScreen extends ConsumerStatefulWidget { const TomogramScreen({required Patient patient}); }`, `class PermissionScreen extends ConsumerStatefulWidget { const PermissionScreen({required List<Permission> permissions}); }`, `final List<RouteBase> tomogramRoutes` (nested under home: `RoutePaths.tomogramPattern`, `RoutePaths.permissionPattern`), `Future<MediaSource?> showAddSourceSheet(BuildContext)`.

- [ ] **Step 1: Write failing screen tests**

`test/features/tomogram/tomogram_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../helpers/pump_app.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

class MockMediaPickerService extends Mock implements MediaPickerService {}

const jane = Patient(id: 1, opid: 42, name: 'Jane Doe');

void main() {
  late Directory dir;
  late MockTomogramApi api;
  late MockMediaPickerService picker;

  setUpAll(() => registerFallbackValue(MediaSource.gallery));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_screen');
    api = MockTomogramApi();
    picker = MockMediaPickerService();
    when(() => picker.deniedPermissions(any())).thenAnswer((_) async => []);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(WidgetTester tester) => pumpApp(tester, const TomogramScreen(patient: jane), overrides: [
        tomogramApiProvider.overrideWithValue(api),
        mediaPickerServiceProvider.overrideWithValue(picker),
        uuidProvider.overrideWithValue(() => 'id'),
      ]);

  testWidgets('shows patient name and empty state', (tester) async {
    await pump(tester);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('plus opens the sheet; gallery pick adds a card and enables upload', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.gallery))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 1));
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Description'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Tomogram: Only JPEG images are supported'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('upload success flashes and clears drafts', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'left forearm');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram: Uploaded'), findsOneWidget);
    final captured = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(captured.single.description, 'left forearm');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('upload failure flashes error and keeps the card', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram Upload: The server took too long to respond'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('denied permission navigates away instead of picking', (tester) async {
    when(() => picker.deniedPermissions(MediaSource.camera)).thenAnswer((_) async => [Permission.camera]);
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    verifyNever(() => picker.pick(any()));
  });
}
```

Because `TomogramScreen` navigates to the permission screen with `context.push`, which needs a router, the screen takes an injectable `onPermissionsDenied` callback with a default that pushes `RoutePaths.permission`. In the last test pass `onPermissionsDenied: (_) {}` via the constructor: change `pump` to accept an optional callback and use `TomogramScreen(patient: jane, onPermissionsDenied: (_) {})` there.

`test/features/tomogram/permission_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../helpers/pump_app.dart';

class MockPermissionGateway extends Mock implements PermissionGateway {}

void main() {
  setUpAll(() => registerFallbackValue(Permission.camera));

  testWidgets('names the first denied permission and opens settings', (tester) async {
    final gateway = MockPermissionGateway();
    when(() => gateway.openSettings()).thenAnswer((_) async => true);
    when(() => gateway.isGranted(any())).thenAnswer((_) async => false);
    await pumpApp(
      tester,
      const PermissionScreen(permissions: [Permission.camera, Permission.photos]),
      overrides: [permissionGatewayProvider.overrideWithValue(gateway)],
    );
    expect(find.text('Grant Permission to access Camera'), findsOneWidget);
    await tester.tap(find.text('Grant Permission'));
    await tester.pump();
    verify(() => gateway.openSettings()).called(1);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/features/tomogram
```

- [ ] **Step 3: Implement widgets**

`lib/features/tomogram/presentation/widgets/add_source_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/app_bottom_sheet.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';

Future<MediaSource?> showAddSourceSheet(BuildContext context) {
  final l10n = context.l10n;
  return showAppBottomSheet<MediaSource>(context, children: [
    ListTile(
      leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
      title: Text(l10n.tomogramChooseGallery),
      onTap: () => Navigator.of(context).pop(MediaSource.gallery),
    ),
    ListTile(
      leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
      title: Text(l10n.tomogramTakePhoto),
      onTap: () => Navigator.of(context).pop(MediaSource.camera),
    ),
    const Divider(height: 1),
    ListTile(
      title: Text(l10n.commonCancel, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dim)),
      onTap: () => Navigator.of(context).pop(),
    ),
  ]);
}
```

`lib/features/tomogram/presentation/widgets/patient_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

/// Patient name over the light gradient with the floating "+" button.
class PatientBar extends StatelessWidget {
  const PatientBar({super.key, required this.name, required this.onAdd});

  final String name;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gradientStart, AppColors.background],
          stops: [0.5, 1],
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: AppTextStyles.header, overflow: TextOverflow.ellipsis)),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

`lib/features/tomogram/presentation/widgets/tomogram_card.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';

class TomogramCard extends StatefulWidget {
  const TomogramCard({super.key, required this.draft, required this.onDelete, required this.onDescriptionChanged});

  final TomogramDraft draft;
  final VoidCallback onDelete;
  final ValueChanged<String> onDescriptionChanged;

  @override
  State<TomogramCard> createState() => _TomogramCardState();
}

class _TomogramCardState extends State<TomogramCard> {
  late final TextEditingController _controller = TextEditingController(text: widget.draft.description);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(widget.draft.filePath),
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.rowGrey,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.dim, size: 48),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _controller,
              label: context.l10n.tomogramDescription,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              onChanged: widget.onDescriptionChanged,
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/tomogram/presentation/widgets/tomogram_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

class TomogramEmptyState extends StatelessWidget {
  const TomogramEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/images/add_tomogram.svg', width: 200, height: 180),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.tomogramEmptyTitle, style: AppTextStyles.bold, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxs),
          Text(l10n.tomogramEmptyBody, style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement screens**

`lib/features/tomogram/presentation/tomogram_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/app_text_field.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/widgets/loader_modal.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/application/media_picker_service.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/add_source_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/patient_bar.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_card.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_empty_state.dart';
import 'package:permission_handler/permission_handler.dart';

class TomogramScreen extends ConsumerStatefulWidget {
  const TomogramScreen({super.key, required this.patient, this.onPermissionsDenied});

  final Patient patient;

  /// Defaults to pushing the permission screen. Injectable for tests.
  final void Function(List<Permission> denied)? onPermissionsDenied;

  @override
  ConsumerState<TomogramScreen> createState() => _TomogramScreenState();
}

class _TomogramScreenState extends ConsumerState<TomogramScreen> {
  int get _opid => widget.patient.opid;
  late final _opController = TextEditingController(text: _opid.toString());

  @override
  void dispose() {
    _opController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final source = await showAddSourceSheet(context);
    if (source == null || !mounted) return;
    final picker = ref.read(mediaPickerServiceProvider);
    final denied = await picker.deniedPermissions(source);
    if (!mounted) return;
    if (denied.isNotEmpty) {
      (widget.onPermissionsDenied ?? _pushPermission)(denied);
      return;
    }
    final result = await picker.pick(source);
    if (!mounted) return;
    ref.read(tomogramControllerProvider(_opid).notifier).addFiles(result.accepted);
    if (result.rejected > 0) {
      showFlash(context, context.l10n.tomogramOnlyJpeg, type: FlashType.warning);
    }
  }

  void _pushPermission(List<Permission> denied) => context.push(RoutePaths.permission, extra: denied);

  Future<void> _upload() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    try {
      await ref.read(tomogramControllerProvider(_opid).notifier).upload();
      if (!mounted) return;
      showFlash(context, l10n.tomogramUploaded, type: FlashType.success);
      Navigator.of(context).maybePop();
    } on ApiFailure catch (e) {
      if (!mounted) return;
      showFlash(context, l10n.tomogramUploadError(e.describe(l10n)), type: FlashType.danger);
    }
  }

  Future<void> _close() async {
    await ref.read(tomogramControllerProvider(_opid).notifier).clearAll();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tomogramControllerProvider(_opid));
    final notifier = ref.read(tomogramControllerProvider(_opid).notifier);

    return LoaderModal(
      visible: state.uploading,
      text: l10n.tomogramUploading,
      child: Scaffold(
        body: Column(
          children: [
            AppHeader(
              title: l10n.commonHeader,
              rightIcon: state.drafts.isEmpty ? null : Icons.check,
              onRightTap: _upload,
            ),
            PatientBar(name: widget.patient.name, onAdd: _add),
            Expanded(
              child: state.drafts.isEmpty
                  ? const TomogramEmptyState()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      children: [
                        for (final d in state.drafts)
                          TomogramCard(
                            key: ValueKey(d.id),
                            draft: d,
                            onDelete: () => notifier.remove(d.id),
                            onDescriptionChanged: (text) => notifier.updateDescription(d.id, text),
                          ),
                      ],
                    ),
            ),
            HideWithKeyboard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppTextField(
                  controller: _opController,
                  label: l10n.tomogramOpNumber,
                  readOnly: true,
                  suffix: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.dim),
                    onPressed: _close,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/tomogram/presentation/permission_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/permission_gateway.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shown when a required permission was denied. Re-checks on resume and pops
/// once everything is granted.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.permissions});

  final List<Permission> permissions;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _recheck() async {
    final gateway = ref.read(permissionGatewayProvider);
    for (final p in widget.permissions) {
      if (!await gateway.isGranted(p)) return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  String _name(BuildContext context, Permission p) =>
      p == Permission.camera ? context.l10n.permissionCamera : context.l10n.permissionPhotos;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = widget.permissions.isEmpty ? Permission.camera : widget.permissions.first;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.permissionTitle(_name(context, first)), style: AppTextStyles.header, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.permissionBody, style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.permissionGrant,
                color: AppColors.errorRed,
                onPressed: () => ref.read(permissionGatewayProvider).openSettings(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Finish the barrel with routes**

Replace `lib/features/tomogram/tomogram.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/presentation/permission_screen.dart';
import 'package:hms_uploader/features/tomogram/presentation/tomogram_screen.dart';
import 'package:permission_handler/permission_handler.dart';

export 'application/media_picker_service.dart';
export 'application/permission_gateway.dart';
export 'application/tomogram_controller.dart';
export 'data/tomogram_api.dart';
export 'data/tomogram_draft.dart';
export 'data/upload_result.dart';
export 'presentation/permission_screen.dart';
export 'presentation/tomogram_screen.dart';

/// Nested under the home route.
final List<RouteBase> tomogramRoutes = [
  GoRoute(
    path: RoutePaths.tomogramPattern,
    builder: (context, state) {
      final extra = state.extra;
      final opid = int.tryParse(state.pathParameters['opid'] ?? '') ?? 0;
      final patient = extra is Patient ? extra : Patient(id: 0, opid: opid, name: '');
      return TomogramScreen(patient: patient);
    },
  ),
  GoRoute(
    path: RoutePaths.permissionPattern,
    builder: (context, state) {
      final extra = state.extra;
      final permissions = extra is List<Permission> ? extra : const <Permission>[];
      return PermissionScreen(permissions: permissions);
    },
  ),
];
```

- [ ] **Step 6: Run all tests and analyzer**

```bash
flutter test && flutter analyze
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/tomogram test/features/tomogram
git commit -m "feat(tomogram): tomogram and permission screens"
```

---

### Task 11: Feature `settings` (Settings and About)

**Files:**
- Create: `lib/features/settings/settings.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/features/settings/presentation/about_screen.dart`, `lib/features/settings/presentation/widgets/settings_row.dart`
- Test: `test/features/settings/settings_screen_test.dart`, `test/features/settings/about_screen_test.dart`

**Interfaces:**
- Consumes: `serverConfigControllerProvider` (via `server_config` barrel), `sessionControllerProvider` (via `auth` barrel), `showConfirmDialog`, `AppHeader`, `RoutePaths`, `url_launcher`.
- Produces: `GoRoute settingsRoute({required List<RouteBase> children})` (path `RoutePaths.settings`), `final GoRoute aboutRoute` (path `RoutePaths.aboutPattern`), `class SettingsScreen extends ConsumerWidget { const SettingsScreen({this.onAbout}); }`, `class AboutScreen extends StatelessWidget`.

- [ ] **Step 1: Write failing tests**

`test/features/settings/settings_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;
  late InMemorySecureStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://x'});
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
  });

  Future<void> pump(WidgetTester tester, {void Function()? onAbout}) => pumpApp(
        tester,
        SettingsScreen(onAbout: onAbout),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(store),
        ],
      );

  testWidgets('renders rows and calls onAbout', (tester) async {
    var about = 0;
    await pump(tester, onAbout: () => about++);
    await tester.pumpAndSettle();
    expect(find.text('Change Installation URL'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('About'));
    expect(about, 1);
  });

  testWidgets('logout asks for confirmation then clears the session', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("No, I'm Not"));
    await tester.pumpAndSettle();
    expect(await store.read('refresh_token'), 'r');
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I am'));
    await tester.pumpAndSettle();
    expect(await store.read('refresh_token'), isNull);
    expect(prefs.getString('server_url'), 'http://x');
  });

  testWidgets('change URL confirm resets url and session', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Installation URL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I am'));
    await tester.pumpAndSettle();
    expect(prefs.getString('server_url'), isNull);
    expect(await store.read('access_token'), isNull);
  });
}
```

`test/features/settings/about_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/settings/settings.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('renders sections with the current year', (tester) async {
    await pumpApp(tester, const AboutScreen());
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.textContaining('© ${DateTime.now().year}'), findsOneWidget);
    expect(find.text('+91 80863 58930'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests, expect failure**

```bash
flutter test test/features/settings
```

- [ ] **Step 3: Implement**

`lib/features/settings/presentation/widgets/settings_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.chevron_right,
    this.color = AppColors.text,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bold.copyWith(color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(subtitle!, style: AppTextStyles.fieldLabel),
                  ],
                ],
              ),
            ),
            Icon(icon, color: color),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/settings/presentation/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/confirm_dialog.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/presentation/widgets/settings_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.onAbout});

  /// Defaults to pushing the About route. Injectable for tests.
  final VoidCallback? onAbout;

  Future<void> _changeUrl(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(context)) return;
    await ref.read(sessionControllerProvider.notifier).logout();
    await ref.read(serverConfigControllerProvider.notifier).reset();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    if (!await showConfirmDialog(context)) return;
    await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: l10n.commonHeader),
          SettingsRow(
            title: l10n.settingsChangeUrl,
            subtitle: l10n.settingsChangeUrlBody,
            onTap: () => _changeUrl(context, ref),
          ),
          const Divider(height: 1, color: AppColors.primary),
          SettingsRow(
            title: l10n.settingsAbout,
            onTap: onAbout ?? () => context.push(RoutePaths.about),
          ),
          const Divider(height: 1, color: AppColors.primary),
          SettingsRow(
            title: l10n.settingsLogout,
            icon: Icons.logout,
            color: AppColors.errorRed,
            onTap: () => _logout(context, ref),
          ),
          const Divider(height: 1, color: AppColors.primary),
        ],
      ),
    );
  }
}
```

`lib/features/settings/presentation/about_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _phone = Uri.parse('tel:+918086358930');
  static final _site = Uri.parse('https://www.decare.team');

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Nothing to do: the device has no handler for this link.
    }
  }

  void _back(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      showFlash(context, context.l10n.commonCannotGoBack, type: FlashType.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final year = DateTime.now().year;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: l10n.aboutHeader, leftIcon: Icons.arrow_back, onLeftTap: () => _back(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(child: Image.asset('assets/images/decare_logo.jpeg', height: 120)),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.aboutCopyright(year), style: AppTextStyles.fieldLabel, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.aboutTerms, style: AppTextStyles.header),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.aboutLicense, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.aboutUs, style: AppTextStyles.header),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.aboutParaIntro, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.aboutParaTwo, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.aboutParaThree, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.aboutContact, style: AppTextStyles.header),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.aboutParaFinale, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LinkButton(label: l10n.aboutPhone, color: AppColors.primary, onPressed: () => _open(_phone)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(l10n.aboutOr, style: AppTextStyles.fieldLabel),
                    ),
                    LinkButton(label: l10n.aboutWebsite, color: AppColors.primary, onPressed: () => _open(_site)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

`lib/features/settings/settings.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/settings/presentation/about_screen.dart';
import 'package:hms_uploader/features/settings/presentation/settings_screen.dart';

export 'presentation/about_screen.dart';
export 'presentation/settings_screen.dart';

final GoRoute aboutRoute = GoRoute(
  path: RoutePaths.aboutPattern,
  builder: (context, state) => const AboutScreen(),
);

GoRoute settingsRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => const SettingsScreen(),
      routes: children,
    );
```

- [ ] **Step 4: Run tests and analyzer**

```bash
flutter test && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings test/features/settings
git commit -m "feat(settings): settings and about screens"
```

---

### Task 12: App shell, router with session gate, entry point and native splash

**Files:**
- Create: `lib/app/router.dart`, `lib/app/app_shell.dart`, `lib/app/tab_bar.dart`, `lib/app/app.dart`
- Modify: `lib/main.dart` (replace placeholder), generated splash files under `android/` and `ios/`
- Test: `test/app/redirect_test.dart`, `test/app/app_gate_test.dart`

**Interfaces:**
- Consumes: every feature barrel, `RoutePaths`, `serverUrlProvider`, `accessTokenProvider`, `sharedPreferencesProvider`, `HideWithKeyboard`, `buildAppTheme`, `AppLocalizations`.
- Produces: `String? computeRedirect({required String location, required bool hasServerUrl, required bool sessionValid})`, `final routerProvider = Provider<GoRouter>`, `final rootNavigatorKey = GlobalKey<NavigatorState>()`, `class HmsApp extends ConsumerWidget`, `class AppShell extends StatelessWidget { const AppShell({required StatefulNavigationShell navigationShell}); }`, `class AppTabBar extends StatelessWidget { const AppTabBar({required int currentIndex, required ValueChanged<int> onTap}); }`.

- [ ] **Step 1: Write failing redirect test**

`test/app/redirect_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';

void main() {
  group('computeRedirect', () {
    test('no server url always goes to configure', () {
      for (final loc in [RoutePaths.login, RoutePaths.home, RoutePaths.settings, RoutePaths.about]) {
        expect(computeRedirect(location: loc, hasServerUrl: false, sessionValid: false), RoutePaths.configure);
      }
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: false, sessionValid: false), isNull);
    });

    test('url without session goes to login, configure allowed', () {
      expect(computeRedirect(location: RoutePaths.home, hasServerUrl: true, sessionValid: false), RoutePaths.login);
      expect(computeRedirect(location: RoutePaths.tomogram(4), hasServerUrl: true, sessionValid: false), RoutePaths.login);
      expect(computeRedirect(location: RoutePaths.login, hasServerUrl: true, sessionValid: false), isNull);
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: true, sessionValid: false), isNull);
    });

    test('valid session leaves auth screens for home', () {
      expect(computeRedirect(location: RoutePaths.login, hasServerUrl: true, sessionValid: true), RoutePaths.home);
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: true, sessionValid: true), RoutePaths.home);
      expect(computeRedirect(location: RoutePaths.home, hasServerUrl: true, sessionValid: true), isNull);
      expect(computeRedirect(location: RoutePaths.about, hasServerUrl: true, sessionValid: true), isNull);
    });
  });
}
```

- [ ] **Step 2: Write failing app gate test**

`test/app/app_gate_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

String liveToken() {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp})}.s';
}

Future<ProviderContainer> containerWith({String? url, bool session = false}) async {
  SharedPreferences.setMockInitialValues(url == null ? {} : {'server_url': url});
  final prefs = await SharedPreferences.getInstance();
  final store = InMemorySecureStore();
  if (session) {
    await store.write('access_token', 'a');
    await store.write('refresh_token', liveToken());
  }
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
  ]);
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);
  return container;
}

void main() {
  testWidgets('starts on configure when no url', (tester) async {
    final c = await containerWith();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Installation URL'), findsOneWidget);
  });

  testWidgets('starts on login when url but no session', (tester) async {
    final c = await containerWith(url: 'http://x');
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('starts on home with tabs when session is valid, and logout returns to login', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Enter OP Number'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I am'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run tests, expect failure**

```bash
flutter test test/app
```

- [ ] **Step 4: Implement tab bar and shell**

`lib/app/tab_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Two text tabs on the dark primary bar, matching the React Native tab bar.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final labels = [context.l10n.settingsTabHome, context.l10n.settingsTabSettings];
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.primary,
      child: SizedBox(
        height: 74 + bottom,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) Container(width: 0.5, height: 44, color: Colors.white),
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: i == currentIndex ? Colors.black.withOpacity(0.5) : Colors.transparent,
                        border: i == currentIndex
                            ? const Border(bottom: BorderSide(color: AppColors.offWhite, width: 2))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(labels[i], style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/app/app_shell.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/tab_bar.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';

/// Hosts the two tab branches under the custom tab bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: HideWithKeyboard(
        child: AppTabBar(currentIndex: navigationShell.currentIndex, onTap: _goBranch),
      ),
    );
  }
}
```

- [ ] **Step 5: Implement router**

`lib/app/router.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/app_shell.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// The three-way gate from the React Native `AppNavigator`.
String? computeRedirect({required String location, required bool hasServerUrl, required bool sessionValid}) {
  const authScreens = {RoutePaths.login, RoutePaths.configure};
  if (!hasServerUrl) {
    return location == RoutePaths.configure ? null : RoutePaths.configure;
  }
  if (!sessionValid) {
    return authScreens.contains(location) ? null : RoutePaths.login;
  }
  return authScreens.contains(location) ? RoutePaths.home : null;
}

/// Notifies the router when the server URL or the session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(serverConfigControllerProvider, (_, __) => notifyListeners());
    ref.listen(sessionControllerProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.home,
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(
      location: state.matchedLocation,
      hasServerUrl: ref.read(serverConfigControllerProvider).valueOrNull != null,
      sessionValid: ref.read(sessionControllerProvider).valueOrNull?.isValid() ?? false,
    ),
    routes: [
      configureRoute,
      loginRoute,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [homeRoute(children: tomogramRoutes)]),
          StatefulShellBranch(routes: [settingsRoute(children: [aboutRoute])]),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
```

- [ ] **Step 6: Implement app and main**

`lib/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/theme/app_theme.dart';

class HmsApp extends ConsumerWidget {
  const HmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      debugShowCheckedModeBanner: false,
    );
  }
}
```

`lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Bridge feature state into the core network layer without core importing features.
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
  ]);
  // Load persisted state before the first frame so the redirect gate is exact.
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);

  runApp(UncontrolledProviderScope(container: container, child: const HmsApp()));
  FlutterNativeSplash.remove();
}
```

Move `flutter_native_splash` from `dev_dependencies` to `dependencies` in `pubspec.yaml` (the runtime `preserve`/`remove` calls need it), then run `flutter pub get`.

- [ ] **Step 7: Generate the native splash**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
dart run flutter_native_splash:create
```

Expected: it reports writing Android drawables/styles and iOS LaunchScreen assets. `android/app/src/main/res/values/styles.xml` now has a `LaunchTheme` with the `#16142a` background.

- [ ] **Step 8: Run all tests and analyzer**

```bash
flutter test && flutter analyze
```

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(app): router with session gate, tab shell, entry point and native splash"
```

---

### Task 13: README, debug APK build and final verification

**Files:**
- Create: `README.md`
- Modify: none

- [ ] **Step 1: Write `README.md`**

```markdown
# DeCare HMS (Flutter)

Companion uploader for a self-hosted DeCare HMS installation. Staff configure the
server URL, log in, look up a patient by OP number, attach JPEG tomograms with
narrations and upload them. Flutter port of the React Native `HMSUploader` app.

## Requirements

- Flutter 3.19.x (Dart 3.3). Run `flutter --version` to confirm.
- Android SDK for the Android build. iOS is configured but not verified here.

## Run

```bash
flutter pub get
flutter gen-l10n          # regenerates lib/core/l10n/generated from app_en.arb
flutter run
```

Tests and analysis:

```bash
flutter test
flutter analyze
```

Debug APK: `flutter build apk --debug` (output in `build/app/outputs/flutter-apk/`).

## Structure

```
lib/
  main.dart            bootstrap and provider overrides
  app/                 MaterialApp, GoRouter, redirect gate, tab shell
  core/                shared code; never imports features
    network/           Dio client, Bearer interceptor, JSend envelope, ApiFailure
    storage/           shared_preferences and secure storage providers
    navigation/        RoutePaths
    theme/ l10n/ widgets/ utils/
  features/<name>/
    <name>.dart        barrel: the only file other features may import
    data/              API classes, DTOs, repositories
    application/       Riverpod controllers and services
    presentation/      screens and feature-local widgets
```

Features: `server_config`, `auth`, `patient_lookup`, `tomogram`, `settings`.

## Adding a workflow

1. Create `lib/features/<name>/` with `data/`, `application/`, `presentation/` as needed.
2. Export its public providers and a `GoRoute` (or `List<RouteBase>`) from `lib/features/<name>/<name>.dart`.
3. Register the route in `lib/app/router.dart` and add the path to `lib/core/navigation/route_paths.dart`.
4. Add strings to `lib/core/l10n/app_en.arb` and run `flutter gen-l10n`.
5. Add tests under `test/features/<name>/`.

## Server contract

Base URL is `<server>/api`. Endpoints: `GET /auth/healthcheck`, `POST /auth/login`,
`GET /opregister?opid=`, `POST /tomogram` (multipart: `opid`, `images`, `narrations[i]`).
Responses follow JSend. The access token is sent as `Authorization: Bearer <token>`.
```

- [ ] **Step 2: Full verification**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
flutter analyze
flutter test
flutter build apk --debug
```

Expected: `No issues found!`, all tests pass, and `✓ Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 3: Check the dependency rule**

```bash
grep -rn "features/" lib/core && echo "VIOLATION: core imports features" || echo "core is clean"
grep -rnE "import 'package:hms_uploader/features/([a-z_]+)/(data|application|presentation)/" lib/features | awk -F"features/" '{ split($2,a,"/"); split($3,b,"/"); if (a[1]!=b[1]) print }' | grep . && echo "VIOLATION: cross-feature deep import" || echo "feature boundaries are clean"
```

Expected: `core is clean` and `feature boundaries are clean`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: README with structure and workflow guide"
```
