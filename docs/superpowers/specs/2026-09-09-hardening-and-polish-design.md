# DeCare HMS: hardening, workflow completion, appearance and release

Date: 2026-09-09
Repos: `E:\Projects\personal\deCare\hms\HMSServer` (Express/TypeScript, Sequelize 5, SQL Server) and `E:\Projects\personal\deCare\hms\HMSFlutter` (branch `flutter-port`)
Builds on: `2026-09-08-flutter-port-design.md`, `2026-09-09-ui-redesign-design.md`

## 1. Goal and scope

Five agreed work streams, delivered as two plans:

**Plan A: platform and workflow** (server first, then app)
1. Server: enforce the JWT middleware on `/opregister` and `/tomogram`; add a refresh endpoint; fix the login controller; make doctor, tomogram type and part IDs settings-driven; add `GET /api/tomogram?opid=`.
2. App: send and refresh tokens, handle session expiry; show already-uploaded tomograms per patient; offline upload queue with automatic retry; resize photos at capture.

**Plan B: appearance, design follow-ups, release**
3. Appearance setting (light, dark, system) with a full dark palette.
4. Design-system follow-ups from the redesign review.
5. Release signing with a locally generated upload keystore, release build hardening, GitHub Actions CI.

Decisions taken with the user: no body-part or doctor selection in the app; crash reporting deferred; CI on GitHub Actions; keystore generated locally by me and gitignored; dark mode selectable in Settings.

Explicit assumptions:
- Passwords stay plain text in `HospitalUser.dbo.User` because the desktop ERP shares that table and compares plain text; hashing is out of scope and would break the ERP.
- Inter font subsetting is skipped: no `fonttools` on this machine and installing system Python packages is not part of the ask.
- The old React Native app will stop working once the middleware is enforced; it is superseded.

## 2. Server changes (HMSServer)

### 2.1 Authentication
- `src/middlewares/auth.ts`: keep the Bearer parsing; on missing token respond 401 (not 403) `failResponse("Authentication required")`; on invalid or expired token 401 `failResponse("Invalid or expired token")`, and `return` after sending (today it falls through to `next()` after an error response).
- Apply `authentication` to `GET /opregister`, `POST /tomogram`, `GET /tomogram`. `/auth/*` stays open.
- `POST /auth/refresh` with JSON `{ refreshToken }`: verify with `appSecret + '_refresh'` and `token_type === 'refresh'`; respond `successResponse({ accessToken })` with a new 2 h access token carrying `{ user_id, username, token_type: 'access' }`. Invalid or expired refresh token → 401 `failResponse("Invalid or expired refresh token")`.
- `src/controllers/auth/login.ts`: query `attributes: ['ID', 'Username', 'Password']` and compare `user.Password === password`; token payload uses `user.ID`. Behaviour otherwise unchanged (404 `Invalid Credentials`).

### 2.2 Settings-driven identifiers
- New helper `src/helpers/settings.ts`: `getSettingInt(key: string, fallback: number): Promise<number>` and `getSetting(key: string, fallback: string)` reading `Settings` by the `Key` column (the model's attribute for `Key` is misnamed `opid`; rename it to `key` and update `multer.ts` to `where: { key: 'TomogramPath' }`).
- `uploadTomogramController`: `doctorId = await getSettingInt('PrimaryDoctorID', 1)`, `tomogramTypeId = await getSettingInt('TomogramTypeID', 6)`, `tomogramPartId = await getSettingInt('TomogramPartID', 2)`.
- SQL seed script `sql/seed-local-tomogram.sql` (documented, not auto-run): inserts `TomogramTypeID`/`TomogramPartID` settings rows and the two lookup rows with `IDENTITY_INSERT`, idempotent (`IF NOT EXISTS`).

### 2.3 Tomogram history endpoint
- `GET /api/tomogram?opid=<n>` (authenticated). Resolves the OP register row by `opid` (404 `Invalid OP Number` when absent), then returns
  ```json
  { "status": "success", "data": [
    { "id": 12, "dateTime": "2026-09-09T12:40:11.000Z", "doctorId": 1, "tomogramTypeId": 6,
      "details": [ { "id": 30, "tomogramPartId": 2, "narration": "left forearm" } ] }
  ] }
  ```
  ordered newest first. Sequelize models: `TomogramMaster` gains the `dateTime` attribute mapped to `DateTime` if missing; details fetched with a second query `where masterid IN (...)` and grouped in code (Sequelize 5 associations are not defined today; keep it simple).
- `POST /tomogram` also sets `dateTime: new Date()` on the master row if the column has no default (check `INFORMATION_SCHEMA.COLUMNS` for `COLUMN_DEFAULT`; if a default exists, leave it).

### 2.4 Verification
`npm run build` (tsc) clean; manual curl sequence documented in `HMSServer/README-api.md`: login → 401 without token on `/opregister` → 200 with token → refresh → history. No test framework is added to the server in this pass.

## 3. App: authentication and session (feature `auth`, `core/network`)

- `AuthApi.refresh(String refreshToken) → Future<String accessToken>` calling `POST /auth/refresh`.
- `SessionController.refreshAccessToken()` swaps the access token in state and secure storage.
- `AuthInterceptor` becomes a plain `Interceptor` with single-flight refresh (a `QueuedInterceptor` would deadlock: the refresher posts `/auth/refresh` through the same client) with `onError`: on 401 from any path except `/auth/*`, if a refresh token exists and this request has not been retried, call refresh, set the new Bearer header and retry the request once. If refresh fails or the retry 401s again, complete with the original error.
- `core/network` cannot import `features/auth`, so the interceptor receives two callbacks from `main.dart` overrides: `accessTokenProvider` (exists) and a new `refreshAccessTokenProvider = Provider<Future<String?> Function()>` (returns the new token or null). `main.dart` overrides it with the session controller's method.
- Session expiry UX: `Session.isValid` continues to use the refresh token's `exp`. When a protected call ends in `UnauthorizedFailure` after the refresh attempt, the feature controller surfaces it as today; additionally a `sessionExpiryListener` in `lib/app/` (a `ProviderObserver`-free approach: `ref.listen` on a new `authFailureProvider` StateProvider set by the interceptor callback) triggers `logout()` and shows `l10n.errorSessionExpired` "Session expired, please sign in again" as a danger banner. The redirect gate then lands on Login.

## 4. App: tomogram history (feature `tomogram`)

- `data/tomogram_history_api.dart`: `TomogramHistoryApi.list(int opid) → Future<List<TomogramSet>>`; `TomogramSet(id, dateTime, details: List<TomogramSetDetail(id, narration)>)`.
- `application/tomogram_history_controller.dart`: `AutoDisposeFamilyAsyncNotifier<List<TomogramSet>, int>` keyed by opid; `refresh()` after a successful upload.
- Presentation: on the Tomogram screen, above the drafts, a `DsCard` "Already uploaded" header row with a mono count chip and the last upload date (`label` secondary, formatted `d MMM HH:mm` via `intl`), collapsed by default; tapping expands to a list of sets, each a compact row: date (mono), then the narrations joined with " · " (secondary, ellipsised). Loading: one `DsSkeleton.row()`. Error: a single secondary-text line "Could not load history" (no banner). Empty: the card is hidden. New ARB keys: `tomogramHistoryTitle` "Already uploaded", `tomogramHistoryCount` "{count} sets" (plural-aware: "1 set"/"{count} sets" via ICU plural), `tomogramHistoryLast` "Last {date}", `tomogramHistoryError` "Could not load history", `tomogramHistoryNoNarration` "No description".

## 5. App: offline upload queue (feature `tomogram`)

### 5.1 Model and storage
- `PendingUpload(id: uuid, opid, patientName, files: List<PendingFile(path, description)>, createdAt, attempts, lastError?)`. Stored as JSON under prefs key `pending_uploads`; files copied at enqueue time from the picker cache to `<applicationDocumentsDirectory>/pending/<id>/<n>.jpg` (re-add `path_provider`). Removing an entry deletes its folder.
- `PendingUploadsRepository(prefs)`: `read()`, `write(list)`.

### 5.2 Behaviour
- Tapping Upload: attempt immediately as today. If the failure is `CannotConnectFailure` or `TimeoutFailure`, enqueue the drafts as a `PendingUpload`, clear the drafts, show a warning banner `tomogramQueued` "Saved offline. It will upload when the server is reachable." and pop. Other failures behave as today (drafts kept, danger banner).
- `UploadQueueController` (`AsyncNotifier<List<PendingUpload>>`, non-autoDispose, created at app start): processes entries sequentially, oldest first, whenever (a) the app starts, (b) `connectivity_plus` reports a non-`none` result after having been `none`, (c) the user taps retry, (d) a new entry is enqueued while online. Success removes the entry and its files and refreshes the history controller for that opid. Network failure stops the run (wait for the next trigger); a non-network failure increments `attempts`, stores `lastError`, and continues with the next entry. Entries with `attempts >= 5` stay in the list marked failed and are retried only manually.
- Only one processing run at a time (`_running` guard).

### 5.3 UI
- Dashboard context strip: when the queue is non-empty, a `DsChip(onShell: true)` "{count} pending" (`dashboardPending`) appears left of the status dot; tapping opens a `showDsSheet` listing entries (`DsListRow`: patient name, mono opid, trailing value "{n} photos" or the failure count) with a `DsButton.primary` "Retry now" (`queueRetry`) and per-row ghost "Discard" (`queueDiscard`, with `showDsDialog` confirm). Empty queue → chip hidden.
- Tomogram screen: if this opid has a pending entry, a `DsCard` line "{n} photos waiting to upload" (`tomogramPendingLine`) above history.

### 5.4 Photo size
`MediaPickerService`: `pickImage(source: camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 85)` and `pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 85)`. image_picker re-encodes as JPEG, so the JPEG check still passes and the server filter is satisfied.

## 6. Appearance (Plan B)

- `DsColors.dark`: canvas `#0F141C`, card `#171E29`, shell `#0B1017`, shellRaised `#1E2938`, textPrimary `#E8ECF2`, textSecondary `#9AA4B2`, textOnShell `#FFFFFF`, textOnShellMuted 70% white, borderSubtle `#273040`, accentSolid `#5AA8F0`, accentText `#7DBCF5`, gradient unchanged, success `#3DBA85`, warning `#F0B429`, danger `#F26B70`. Light palette gains `accentText` `#1F6FBF` (WCAG AA on card and canvas) used by ghost buttons and links; `accentSolid` stays for focus rings and icons.
- `buildDsTheme(Brightness)` returns light or dark `ThemeData` with the matching `DsColors`/`DsType`; `HmsApp` sets `theme`, `darkTheme`, `themeMode` from `appearanceProvider` (`Notifier<ThemeMode>` persisted in prefs key `appearance`: `system` default). The `AnnotatedRegion` status-bar style follows the resolved brightness; the navy shell is dark in both modes so icons stay light.
- Settings: new group "Appearance" (`settingsGroupAppearance`) with a row "Theme" (`settingsTheme`) whose trailing value is the current choice; tap opens a `showDsSheet` with three `DsListRow`s: "System" (`appearanceSystem`), "Light" (`appearanceLight`), "Dark" (`appearanceDark`), the active one with a check icon.
- Splash stays navy; the native splash cannot follow the in-app setting.
- Verification: every screen screenshotted in dark mode on the emulator; widget tests for the appearance controller and the sheet; a smoke test that pumps the app with `themeMode: dark` and asserts `Theme.of(context).brightness`.

## 7. Design-system follow-ups (Plan B)

- Text scaling: `DsAppBar`, `DsBottomBar`, `DsListRow` grow with content (`ConstrainedBox(minHeight:)` instead of fixed `SizedBox`), and the bars clamp scaling to 1.3 with `MediaQuery.withClampedTextScaling`.
- Ghost buttons and links use `accentText`.
- Kit tests for every component and declared state that lacks one: `DsCard`, `DsChip`, `DsEmptyState`, `DsIconTile`, `DsOnboardingScaffold`, `DsProgressBar` (reduced motion), `DsStatusDot`, `FadeThroughPage` (reduced motion), `DsTextField` prefix/suffix/counter, `showDsDialog` destructive, `DsButton` variants disabled.
- `AppModule.badge` becomes `Widget Function()? badge` returning a widget (features return a `ConsumerWidget`); `core/modules` drops the Riverpod import. Tomogram's badge becomes `RecentCountBadge` (`ConsumerWidget`).
- `DsSkeleton`: remove the dead `rows` parameter and the hard-coded horizontal margin (callers add padding); `DsSkeleton.card` kept.
- `DsRadius.sheet` renamed `DsRadius.onboarding`; `DsChip` uses `type.label`/`type.mono` sizes without overriding; `HideWithKeyboard` uses `DsMotion.of(context, DsMotion.base)`.
- `ModulePlaceholderCard` participates in the stagger; `ModuleCard` merges semantics only over the tappable content, leaving the badge outside.
- `ExitOnDoubleBack` unchanged.

## 8. Release and CI (Plan B)

- `android/key.properties` (gitignored) with `storeFile=upload-keystore.jks`, `storePassword`, `keyAlias=upload`, `keyPassword`; keystore generated with `keytool -genkeypair -v -keystore android/upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000` using a generated 24-character password; both files gitignored; a `android/key.properties.example` committed. The report to the user states where the files are and that they must be backed up; a lost keystore means a new Play listing.
- `android/app/build.gradle`: load `key.properties` if present, `signingConfigs.release`, `buildTypes.release { signingConfig signingConfigs.release; minifyEnabled true; shrinkResources true; proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro' }`; `proguard-rules.pro` keeps Tink (`-keep class com.google.crypto.tink.** { *; }`) and `-dontwarn` for its optional deps. Debug builds keep debug signing.
- Version: `pubspec.yaml` `version: 1.1.0+2`; README documents bumping `version` (name+code) per release and the `flutter build appbundle --release` command.
- CI: `.github/workflows/ci.yml` on push and pull_request: `subosito/flutter-action@v2` with `flutter-version: 3.19.0`, `flutter pub get`, `flutter gen-l10n`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, uploading the APK as an artifact. Runs on `ubuntu-latest` with Java 17. No release signing in CI (the keystore is local).
- Verification locally: `flutter build apk --release` and `flutter build appbundle --release` succeed with the new signing config; `apksigner verify --print-certs` shows the upload key; release APK installs and runs on the emulator (cold start measured and reported).

## 9. Out of scope

Crash reporting (deferred by the user), password hashing, body part and doctor selection, Inter subsetting, iOS build, server test framework, folding `patient_lookup` into `tomogram`.

## 10. Dependencies added

App: `connectivity_plus ^6.1.5` (7.x needs a newer Flutter Gradle plugin), `path_provider` (re-added). Server: none (uses existing `jsonwebtoken`, `sequelize`).
