# Plan B: Appearance, design follow-ups, release signing and CI

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a light/dark/system appearance setting with a full dark palette, close the design-system follow-ups from the redesign review, and make the Android app releasable: signed with a local upload keystore, minified, versioned, and built by GitHub Actions on every push.

**Architecture:** `DsColors` gains a `dark` palette and an `accentText` token; `buildDsTheme(Brightness)` produces both themes; an `appearanceProvider` (persisted `ThemeMode`) drives `MaterialApp.themeMode`; Settings gets an Appearance group. Kit widgets grow with text scale and get the remaining tests. Gradle reads `android/key.properties` (gitignored) for release signing; `proguard-rules.pro` keeps Tink; `.github/workflows/ci.yml` runs analyze, test and a debug build.

**Tech Stack:** Flutter 3.19 / Dart 3.3, Riverpod 2.6, keytool (Corretto JDK 11 at `C:\Program Files\Amazon Corretto\jdk11.0.14_10\bin\keytool.exe`), GitHub Actions `subosito/flutter-action@v2`.

**Spec:** `docs/superpowers/specs/2026-09-09-hardening-and-polish-design.md` (sections 6 to 8)

## Global Constraints

- Flutter 3.19 / Dart 3.3, no `flutter upgrade`, no new pub dependencies.
- `core` never imports `features`; cross-feature imports via barrels; all UI strings via `context.l10n`; screens use only tokens.
- `flutter analyze` clean and `flutter test` green before every commit. Work in `E:\Projects\personal\deCare\hms\HMSFlutter` on branch `flutter-port`.
- Never commit `android/key.properties` or `android/upload-keystore.jks`; both must be listed in `.gitignore` before they are created.
- Debug builds keep debug signing; only `release` uses the upload key.

---

### Task 1: Appearance setting and dark palette

**Files:**
- Modify: `lib/core/design/tokens/ds_colors.dart` (add `accentText`, `DsColors.dark`), `lib/core/design/ds_theme.dart` (`buildDsTheme([Brightness brightness = Brightness.light])`), `lib/app/app.dart` (theme, darkTheme, themeMode, status-bar style by brightness), `lib/features/settings/presentation/settings_screen.dart`, `lib/features/settings/settings.dart`, `lib/core/l10n/app_en.arb`, `test/helpers/pump_app.dart` (optional `themeMode`)
- Create: `lib/features/settings/application/appearance_controller.dart`, `lib/features/settings/presentation/widgets/appearance_sheet.dart`
- Test: `test/core/design/ds_theme_test.dart` (dark tokens), `test/features/settings/appearance_controller_test.dart`, `test/features/settings/settings_screen_test.dart` (appearance row and sheet), `test/app/app_theme_mode_test.dart`

**Interfaces:**
- `DsColors.light` adds `accentText: Color(0xFF1F6FBF)`. `DsColors.dark`: canvas `0xFF0F141C`, card `0xFF171E29`, shell `0xFF0B1017`, shellRaised `0xFF1E2938`, textPrimary `0xFFE8ECF2`, textSecondary `0xFF9AA4B2`, textOnShell `0xFFFFFFFF`, textOnShellMuted `0xB3FFFFFF`, borderSubtle `0xFF273040`, accentSolid `0xFF5AA8F0`, accentText `0xFF7DBCF5`, accentGradient unchanged, success `0xFF3DBA85`, warning `0xFFF0B429`, danger `0xFFF26B70`.
- `ThemeData buildDsTheme([Brightness brightness = Brightness.light])` picks the palette, sets `brightness`, `scaffoldBackgroundColor`, `colorScheme` (from `ColorScheme.light()`/`.dark()` then `copyWith` as today plus `surfaceTint: Colors.transparent`), `dialogTheme`/`bottomSheetTheme` on `card`, text theme colours, extensions `[colors, DsType.inter(colors)]`.
- `appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>`; `AppearanceController.build()` reads prefs key `appearance` (`'system' | 'light' | 'dark'`, default system); `set(ThemeMode)` persists.
- `HmsApp`: `theme: buildDsTheme(Brightness.light)`, `darkTheme: buildDsTheme(Brightness.dark)`, `themeMode: ref.watch(appearanceProvider)`. The `AnnotatedRegion` value uses the resolved brightness: `statusBarColor` = that palette's `shell`, `statusBarIconBrightness: Brightness.light` in both (the shell is dark in both palettes). Resolve `system` via `MediaQuery.platformBrightnessOf(context)` inside the builder.
- Settings: new group `settingsGroupAppearance` "Appearance" above "Help", row `settingsTheme` "Theme" with `trailingValue` = current label and chevron; tap → `showAppearanceSheet(context, ref)`: heading, three `DsListRow`s (`appearanceSystem` "System", `appearanceLight` "Light", `appearanceDark` "Dark"), active row `trailingIcon: Icons.check` (non-interactive, `onTrailingTap: null`).
- Ghost buttons and links (`DsButton.ghost`, `LinkButton`-like usages) switch from `accentSolid` to `accentText`.

- [ ] **Step 1: Failing tests** — dark palette values and `buildDsTheme(Brightness.dark).brightness == Brightness.dark`; controller default/system, `set(dark)` persists `'dark'` and rebuilds to `ThemeMode.dark`; settings screen shows "Theme" with "System", tapping opens the sheet, choosing "Dark" updates the row to "Dark" and prefs to `'dark'`; app test pumps `HmsApp` with prefs `appearance: dark` and asserts `Theme.of(dashboard context).brightness == Brightness.dark` (use `tester.element(find.text('Modules'))`).
- [ ] **Step 2: Implement.** `flutter gen-l10n`.
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `feat(appearance): light/dark/system theme setting with dark palette`.

---

### Task 2: Design-system follow-ups

**Files:**
- Modify: `lib/core/design/widgets/ds_app_bar.dart`, `ds_bottom_bar.dart`, `ds_list_row.dart` (grow with text; clamp bars to 1.3), `ds_button.dart` (ghost uses `accentText`), `ds_skeleton.dart` (drop `rows`, drop hard-coded margin; callers add padding), `ds_chip.dart` (use token sizes), `ds_radius.dart` (`sheet` → `onboarding`; update `ds_onboarding_scaffold.dart`), `lib/core/widgets/keyboard_visibility.dart` (`DsMotion.of`), `module_card.dart` (MergeSemantics only over tappable content; badge outside), `lib/features/dashboard/presentation/dashboard_screen.dart` (placeholder staggered; callers of `DsSkeleton` add padding), `lib/core/modules/app_module.dart` (`Widget Function()? badge`, no Riverpod import), `lib/features/tomogram/tomogram.dart` (badge → `RecentCountBadge` ConsumerWidget in `lib/features/tomogram/presentation/widgets/recent_count_badge.dart`), `lib/features/patient_lookup/presentation/patient_lookup_screen.dart` (skeleton padding), README (badge API)
- Test: new `test/core/design/{ds_card,ds_chip,ds_empty_state,ds_icon_tile,ds_onboarding_scaffold,ds_progress_bar,ds_status_dot,fade_through_page}_test.dart`; extend `ds_text_field_test.dart` (prefix, suffix, counter, maxLength), `ds_dialog_test.dart` (destructive variant renders `DsButton.destructive`), `ds_button_test.dart` (each variant disabled), `ds_app_bar_test.dart`/`ds_bottom_bar_test.dart`/`ds_list_row_test.dart` (text scale 2.0 does not overflow: pump inside `MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2.0)))` and assert no exceptions and height >= base), `dashboard_screen_test.dart` (badge renders count via the new API)

**Interfaces:**
- `AppModule.badge` is `Widget Function()?`; dashboard renders `m.badge?.call()`.
- `RecentCountBadge extends ConsumerWidget` showing `DsChip('$count', mono)` or `SizedBox.shrink()`.
- `DsSkeleton.row({Key? key})`, `DsSkeleton.card({Key? key, double height = 120})` without margin.
- `DsAppBar` uses `ConstrainedBox(constraints: BoxConstraints(minHeight: 48))` with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, ...)`; `DsBottomBar` likewise (min 60); `DsListRow` min height 56, no clamp.

- [ ] **Step 1: Failing tests** as listed.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Verify and commit** — `flutter analyze && flutter test`; `refactor(design): text-scale safe bars and rows, accent text token, badge API, kit tests`.

---

### Task 3: Release signing, hardening and versioning

**Files:**
- Modify: `.gitignore`, `android/app/build.gradle`, `pubspec.yaml` (`version: 1.1.0+2`), `README.md`
- Create: `android/key.properties.example`, `android/app/proguard-rules.pro`, `android/key.properties` (gitignored), `android/upload-keystore.jks` (gitignored)

- [ ] **Step 1: gitignore first**

Append to `.gitignore`:
```
# Release signing (local only; back these up outside the repo)
android/key.properties
android/upload-keystore.jks
```
Commit this alone: `chore(android): ignore release signing files`.

- [ ] **Step 2: Generate the keystore**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter/android"
PW=$(python -c "import secrets;print(secrets.token_urlsafe(18))" 2>/dev/null || openssl rand -base64 18 | tr -d '/+=')
"C:/Program Files/Amazon Corretto/jdk11.0.14_10/bin/keytool.exe" -genkeypair -v -keystore upload-keystore.jks -storetype JKS -alias upload -keyalg RSA -keysize 2048 -validity 10000 -storepass "$PW" -keypass "$PW" -dname "CN=DeCare HMS Upload, O=Decare Software Solution, C=IN"
printf 'storeFile=upload-keystore.jks\nstorePassword=%s\nkeyAlias=upload\nkeyPassword=%s\n' "$PW" "$PW" > key.properties
printf 'storeFile=upload-keystore.jks\nstorePassword=CHANGE_ME\nkeyAlias=upload\nkeyPassword=CHANGE_ME\n' > key.properties.example
git status --short   # must NOT list key.properties or upload-keystore.jks
```
The password is written only to `android/key.properties`. Never print it into the report; state the file path instead.

- [ ] **Step 3: Gradle**

In `android/app/build.gradle`, before `android {`:
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withReader('UTF-8') { keystoreProperties.load(it) }
}
```
Inside `android {`:
```groovy
    signingConfigs {
        release {
            if (keystorePropertiesFile.exists()) {
                keyAlias keystoreProperties['keyAlias']
                keyPassword keystoreProperties['keyPassword']
                storeFile rootProject.file(keystoreProperties['storeFile'])
                storePassword keystoreProperties['storePassword']
            }
        }
    }
    buildTypes {
        release {
            signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
```
`android/app/proguard-rules.pro`:
```
# flutter_secure_storage uses Tink; keep it whole.
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
```

- [ ] **Step 4: Version and README**

`pubspec.yaml` `version: 1.1.0+2`. README "Release" section: how to bump `version`, `flutter build appbundle --release`, `flutter build apk --release`, where `key.properties` lives and that the keystore must be backed up (a lost upload key cannot be replaced without a new store listing), and that CI does not sign releases.

- [ ] **Step 5: Verify**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
flutter build apk --release 2>&1 | tail -3
flutter build appbundle --release 2>&1 | tail -3
BT=$(ls -d "$LOCALAPPDATA/Android/Sdk/build-tools/"* | sort | tail -1); "$BT/apksigner.bat" verify --print-certs build/app/outputs/flutter-apk/app-release.apk | head -5
```
Expected: both builds succeed; the signer's DN is `CN=DeCare HMS Upload...` (not the debug key). `flutter analyze && flutter test` still clean. If R8 fails on a missing class, add the specific `-dontwarn` and note it.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "build(android): release signing from key.properties, R8 minify, version 1.1.0+2"` (double-check with `git show --stat HEAD` that no key file is included).

---

### Task 4: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`
- Modify: `README.md` (badge placeholder and CI note)

```yaml
name: CI
on:
  push:
    branches: ['**']
  pull_request:
jobs:
  flutter:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { flutter-version: '3.19.0', channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter gen-l10n
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --debug
      - uses: actions/upload-artifact@v4
        with: { name: app-debug-apk, path: build/app/outputs/flutter-apk/app-debug.apk, retention-days: 7 }
```

- [ ] Validate YAML (`python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` if PyYAML exists, otherwise careful review). Commit `ci: analyze, test and debug build on GitHub Actions`. The repo has no remote; the user adds one (`gh repo create` is not run by us).

---

### Task 5: Device verification (controller-run)

Install the **release** APK on the emulator (`adb install -r build/app/outputs/flutter-apk/app-release.apk`), measure cold start (`adb logcat -d | grep "Fully drawn"`), and walk Dashboard, Lookup, Tomogram, Settings, About, Login and Configure in dark mode (Settings → Theme → Dark) with screenshots; then set System and confirm it follows `adb shell "cmd uimode night yes"`. Anything wrong goes to a fix round. Reinstall the debug build afterwards if the user still uses it for `flutter run`.
