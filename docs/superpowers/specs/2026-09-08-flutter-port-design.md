# DeCare HMS: Flutter port design

Date: 2026-09-08
Source app: `E:\Projects\personal\deCare\hms\HMSUploader` (React Native 0.66, Ignite, MobX-State-Tree)
Target: `E:\Projects\personal\deCare\hms\HMSFlutter` (this repository)

## 1. Goal and scope

Port the DeCare HMS uploader app to Flutter with identical user-facing behaviour and an identical API contract, plus a small set of "safe fixes" that the server cannot observe or already tolerates. The structure is feature-first so future workflows can be added as new feature folders.

The app lets clinic staff configure a self-hosted DeCare HMS server URL, log in, look up a patient by OP number, attach one or more skin-lesion photos ("tomograms") with per-image narrations, and upload them.

In scope (product screens): Configure URL, Login, Home (OP search and recent searches), Tomogram (pick, describe, upload), Permission fallback, Settings, About.

Dropped (boilerplate or dead): welcome and demo screens, Rick and Morty character store, Storybook, Reactotron, keychain wrapper, unused Checkbox/Switch/FormRow/Wallpaper/BulletItem widgets, Japanese stub translations, navigation-state persistence (dev-only in the original), `getUsers`/`getUser` API leftovers.

Safe fixes included:

- Tokens stored in platform secure storage instead of plain preferences.
- `Authorization: Bearer <accessToken>` sent on every API call. The server's middleware expects this format but is currently disabled on the routes the app calls, so this is harmless today and correct tomorrow.
- Human-readable error messages instead of raw codes such as `cannot-connect`.
- Picker restricted to JPEG to match the server's multer filter (`image/jpg`, `image/jpeg` only).
- Upload timeout raised to 60 s send/receive; JSON calls stay at 10 s.
- UUIDs for local tomogram drafts instead of 6-digit time slices.
- Portrait lock on both platforms; iOS camera and photo-library usage strings added.
- Typos fixed ("Terms of Service").

Out of scope: refresh-token flow and 401 handling (server has no refresh endpoint), certificate pinning, HTTPS enforcement (users type the URL; cleartext must remain allowed for LAN installs), iOS verification (no Mac in this session).

## 2. Platforms and toolchain

- Flutter 3.19.0 / Dart 3.3.0 stable, as installed on the development machine. All packages are pinned to versions that resolve on this SDK.
- Android is the verified target. Application id `com.decare.hmsuploader`, launcher label `HMS`, version `1.0.0+1`, `minSdk 21`, portrait only, cleartext traffic permitted, `allowBackup=false`.
- iOS folder is generated and configured (bundle id `com.decare.hmsuploader`, portrait only, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSAllowsArbitraryLoads` true) but not built here.
- Dart package name: `hms_uploader`.

Dependencies:

| Package | Purpose |
|---|---|
| flutter_riverpod | state management |
| go_router | routing, redirect gate, tab shell |
| dio | HTTP, multipart, interceptors, per-request timeouts |
| shared_preferences | server URL, recent searches |
| flutter_secure_storage | access and refresh tokens |
| image_picker | camera and gallery |
| permission_handler | runtime permissions and "open settings" |
| path_provider | temp directory for picked files |
| uuid | draft ids |
| url_launcher | tel: and https: links on About |
| flutter_localizations, intl | ARB-based strings |
| flutter_native_splash (dev) | dark native splash with logo |
| mocktail (dev) | test doubles |
| flutter_lints (dev) | analysis |

No code generation (no freezed, json_serializable, riverpod_generator). Models are hand-written.

## 3. Project layout

```
lib/
  main.dart                 bootstrap: ProviderScope, eager-load config + session, runApp
  app/
    app.dart                MaterialApp.router, theme, localization delegates
    router.dart             GoRouter: root routes, StatefulShellRoute tabs, redirect, back-to-exit
    tab_bar.dart            custom two-tab bar (hidden when keyboard is visible)
  core/
    network/  dio_client.dart (provider, rebuilds on URL change), auth_interceptor.dart,
              api_envelope.dart, api_failure.dart
    storage/  prefs_store.dart, secure_store.dart (thin wrappers, providers)
    theme/    app_colors.dart, app_spacing.dart, app_text_styles.dart, app_theme.dart
    l10n/     app_en.arb  -> generated AppLocalizations (flutter gen-l10n)
    widgets/  app_header.dart, app_text_field.dart, search_text_field.dart, primary_button.dart,
              link_button.dart, loader_modal.dart, confirm_dialog.dart, app_bottom_sheet.dart,
              flash_banner.dart, hide_with_keyboard.dart, keyboard_visibility.dart
    icons/    app_icons.dart (SVG paths as Dart `Path`/CustomPainter or flutter_svg-free vector data)
    utils/    url_validator.dart, jwt.dart, temp_files.dart
  features/
    server_config/
      server_config.dart               barrel: exports providers and routes
      data/health_check_api.dart, server_config_repository.dart
      application/server_config_controller.dart
      presentation/configure_url_screen.dart
    auth/
      auth.dart
      data/auth_api.dart, session.dart, session_repository.dart
      application/session_controller.dart
      presentation/login_screen.dart, widgets/logo.dart
    patient_lookup/
      patient_lookup.dart
      data/op_register_api.dart, patient.dart, recent_searches_repository.dart
      application/patient_lookup_controller.dart, recent_searches_controller.dart
      presentation/home_screen.dart, widgets/recent_search_row.dart, op_search_bar.dart, empty_state.dart
    tomogram/
      tomogram.dart
      data/tomogram_api.dart, tomogram_draft.dart, upload_result.dart
      application/tomogram_controller.dart, media_picker_service.dart
      presentation/tomogram_screen.dart, permission_screen.dart,
                   widgets/tomogram_card.dart, patient_bar.dart, add_source_sheet.dart, empty_state.dart
    settings/
      settings.dart
      presentation/settings_screen.dart, about_screen.dart, widgets/settings_row.dart
test/
  core/...                  unit tests for envelope, failure mapping, url validator, jwt, temp files
  features/<name>/...       controller and repository tests with fakes; widget tests for screens
assets/
  images/hms_square.png, decare_logo.jpeg, installation_url.png
```

Rules:

- `core` never imports `features`.
- A feature imports `core` freely and other features only through their barrel file.
- Each feature has up to three sub-layers: `data` (APIs, DTOs, repositories), `application` (Riverpod controllers), `presentation` (screens, feature-local widgets). Unneeded layers are omitted.
- Each feature barrel exports a `List<RouteBase> <feature>Routes` where it owns routes; `router.dart` concatenates them.
- Adding a workflow: add a folder under `features`, export its routes, add its ARB strings.

## 4. Navigation and session gate

Routes:

| Path | Screen | Placement |
|---|---|---|
| `/configure` | ConfigureUrlScreen | root |
| `/login` | LoginScreen | root |
| `/app/home` | HomeScreen | shell branch 0 |
| `/app/home/tomogram/:opid` | TomogramScreen | pushed in branch 0; `extra` = Patient |
| `/app/home/permission` | PermissionScreen | pushed in branch 0; `extra` = List<Permission> |
| `/app/settings` | SettingsScreen | shell branch 1 |
| `/app/settings/about` | AboutScreen | pushed in branch 1 |

Redirect (evaluated on every navigation; router `refreshListenable` fires when server URL or session changes):

1. No server URL saved: `/configure`.
2. URL saved, and no refresh token or its `exp` has passed: `/login`. Exception: `/configure` is allowed so the login screen's "Change URL" link works.
3. Session valid and location is `/configure` or `/login`: `/app/home`. Otherwise no redirect.

Screens never navigate to `/login` or `/configure` after logout or reset; they clear state and the redirect handles it. Login success also relies on the redirect.

Back button: a PopScope at the shell and on the root screens implements double-press-to-exit on Home, Login and Configure with a 3 s window and the flash "Press back again to exit". Other screens pop normally. Exit uses `SystemNavigator.pop()`.

Startup: `main.dart` awaits the preferences and secure-storage reads before `runApp` so the first frame is already the right screen. The native splash (`flutter_native_splash`) uses background `#16142a` and the `hms_square` logo, replacing the old in-JS splash.

Tab bar: custom widget, height 74, background primary `#151D28`, two text tabs "Home" and "Settings", focused tab has a translucent black overlay and a 2 px off-white bottom border, a 0.5 px white vertical divider between tabs. Hidden while the keyboard is visible.

## 5. Networking, data and state

### Dio client

`dioProvider` builds one `Dio` per server URL: base URL `<serverUrl>/api`, `Accept: application/json`, connect and receive timeouts 10 s. `AuthInterceptor` reads the current access token from the session controller and adds `Authorization: Bearer <token>` when present. The health check uses a separate short-lived `Dio` for the candidate URL because the URL is not yet committed.

### Envelope and failure mapping

Server responses are `{ "status": "success" | "fail" | "error", "data": ..., "message"?: ... }`. `ApiEnvelope.parse(response)` returns the `data` on `success` and throws `ApiFailure.rejected(message)` otherwise.

`ApiFailure` is a sealed class:

| Variant | Mapped from | Default message |
|---|---|---|
| `cannotConnect` | DioException connectionError, socket errors, unknown with SocketException | Could not reach the server |
| `timeout` | connection/send/receive timeout | The server took too long to respond |
| `unauthorized` | 401, 403 | Session expired (login screen overrides: Invalid username or password) |
| `notFound` | 404 | Not found (login: Invalid username or password; patient: No patient with that OP number) |
| `server` | 5xx | server `message` if present, else Server error |
| `rejected` | other 4xx, or `status != success` | server `message` |
| `badData` | JSON shape mismatch, parse errors | Unexpected response from server |

`ApiFailure.from(Object error)` performs the mapping. Every API method awaits Dio inside `try` and rethrows as `ApiFailure`. Screens show failures in the flash banner with the same prefixes as today: `Host:`, `Login:`, `Patient:`, `Tomogram Upload:`.

### Endpoints

| Method | Path | Request | Response `data` |
|---|---|---|---|
| GET | `/auth/healthcheck` | none | `{message, uptime}`; commit URL only when `uptime` is present |
| POST | `/auth/login` | JSON `{username, password}` | `{id, username, accessToken, refreshToken}` |
| GET | `/opregister?opid=<n>` | query | `{id, opid, name}` |
| POST | `/tomogram` | multipart: `opid`, repeated `images` (`image<uuid>.jpg`, `image/jpeg`), `narrations[i]` | `[{id, masterid, tomogrampartid, narration}]` |

### Feature state

- **server_config**: `ServerConfigRepository` (shared_preferences key `server_url`). `ServerConfigController extends Notifier<String?>` with `connect(String rawUrl)`: validate with the regex below, run health check, save on success. The controller state is `AsyncValue<String?>`, so `isLoading` doubles as the connecting indicator.

  URL regex (from the source app, with the domain alternative widened to multi-level hosts with an optional port, because the original rejects the production host `cutis.decare.team`):
  `^(https?:\/\/)?((localhost|\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(:\d{1,5})?|(www\.)?[\w\-]+(\.[\w\-]+)*\.[a-z]{2,}(:\d{1,5})?|([A-Za-z0-9_-]+\.?[A-Za-z0-9_-]*:[0-9]+))(\/\S*)?$` (case-insensitive). If the scheme is absent, `http://` is prepended before use.

- **auth**: `Session(accessToken, refreshToken)`. `SessionRepository` stores both in secure storage (`access_token`, `refresh_token`). `SessionController extends Notifier<Session?>` with `login(username, password)`, `logout()`. `Session.isValid` decodes the refresh token payload (base64url, no signature check) and checks `exp * 1000 > now`.

- **patient_lookup**: `Patient(id, opid, name)`. `RecentSearchesController extends Notifier<List<Patient>>`: `add` (dedupe by `id`, insert at front, cap 10), `remove(id)`, `clear()`; persisted as JSON under `recent_searches`. `PatientLookupController extends AutoDisposeAsyncNotifier<Patient?>` with `search(int opid)`; on success adds to recents and returns the patient so the screen can navigate.

- **tomogram**: `TomogramDraft(id, filePath, description)`. `TomogramController` is `AutoDisposeFamilyNotifier<TomogramState, int>` keyed by opid, with `addFiles(List<String>)`, `remove(id)`, `updateDescription(id, text)`, `clear()`, `upload()`. `TomogramState` holds `drafts` and `isUploading`. `MediaPickerService` wraps image_picker and permission_handler: `pickFromGallery()` (multi, up to 2 per pick, JPEG only, non-JPEG files rejected with a flash), `takePhoto()`, and `Future<List<Permission>> deniedPermissions(source)`; the screen routes to PermissionScreen when the list is non-empty. `TomogramApi.upload(opid, drafts)` builds the multipart above with 60 s send and receive timeouts. Successful upload deletes the local files, shows flash "Tomogram: Uploaded", clears drafts, and pops to Home. Remove and clear also delete files.

- **settings**: no data layer. "Change Installation URL" confirm resets server config and session; "Logout" confirm clears the session. Redirect performs the navigation.

Permissions: gallery picking goes through the system picker (`ACTION_GET_CONTENT` / the Android photo picker), which grants per-file read access and needs no runtime permission on any API level, so nothing is requested for it; only the camera is requested (`Permission.camera`, manifest `CAMERA`). PermissionScreen shows the names of denied permissions, a "Grant Permission" button calling `openAppSettings()`, and re-checks on app resume via `WidgetsBindingObserver`; it pops automatically once everything is granted.

## 6. UI and theme

Colors (from the source palette): primary `#151D28`, text `#120E2C`, dimText `#BAB6C8`, dim `#939AA4`, offWhite `#e6e6e6`, background `#ffffff`, error `#dd3333`, errorRed `#FF6C63`, orange `#FBA928`, splash `#16142a`, rowGrey `#e8e8e8`, searchBorder `#c5c5c5`, divider `#EFEFEF`.

Spacing scale: 0, 4, 8, 12, 16, 24, 32, 48, 64 as named constants (`xxs` … `xxxl`).

Typography: platform default font, body 15, header 24 bold, field label 13 dim, brand title 40 on login and 28 in the home header. Light theme only; the original loaded a dark navigation theme but no screen used it.

Icons: the twelve SVG icons are converted to Dart `CustomPainter` paths or Material equivalents where a one-to-one glyph exists (check, close, search, delete, arrow, arrow-left, logout, visibility, visibility-off, camera). Screen illustrations (login logo, blank canvas, add-tomogram, add-button) are exported to PNG assets at 1x/2x/3x from the source SVGs; the login logo already embeds a JPEG so a raster export loses nothing. This avoids a runtime SVG dependency.

Shared widgets reproduce the source components: `AppHeader` (centered title, optional left/right icon buttons), `AppTextField` and `SearchTextField`, `PrimaryButton` and `LinkButton`, `LoaderModal` ("Please wait", spinner, ". . . text . . ."), `ConfirmDialog` ("Are you sure?", "No, I'm Not" / "Yes, I am"), `AppBottomSheet` (drag to dismiss), `FlashBanner` (top overlay, types danger/warning/success/info, auto-dismiss), `HideWithKeyboard`.

Screen-by-screen behaviour matches the inventory of the source app: same copy, same empty states, same button placement, same gradient on the patient bar, same read-only OP field with a close icon that clears drafts and goes back.

All UI copy lives in `app_en.arb`. Keys are grouped by feature prefix (`configureUrl_*`, `login_*`, `home_*`, `tomogram_*`, `permission_*`, `settings_*`, `about_*`, `common_*`, `error_*`). The About copyright uses a `year` placeholder.

## 7. Error handling

- Every controller catches `ApiFailure` and exposes it to the screen through its state (`AsyncValue.error` or a returned result). Screens render it in the flash banner. Unexpected exceptions are wrapped as `ApiFailure.badData` at the API boundary so nothing else leaks.
- Upload failures keep the drafts so the user can retry.
- File deletion failures are logged and ignored.
- A top-level `FlutterError.onError` and `PlatformDispatcher.onError` log to the console; no error screen in v1 beyond Flutter's default. The source error boundary showed unedited boilerplate text, so nothing is lost.

## 8. Testing

Unit tests, run with `flutter test`:

- `core`: envelope parsing, `ApiFailure.from` mapping for each Dio error type and status code, URL regex accept/reject table (including the hyphen case from the last RN commit), JWT `exp` decoding, temp-file deletion.
- `server_config`: controller saves only when health check reports `uptime`; invalid URL never hits the network.
- `auth`: login stores tokens; logout clears them; `isValid` on expired vs live tokens.
- `patient_lookup`: recent searches cap, dedupe, order, persistence round-trip; search adds to recents on success only.
- `tomogram`: add/remove/update/clear; upload builds the expected multipart field names and file names; success clears drafts; failure keeps them.
- Router redirect table: the three gate outcomes.

Widget tests for each screen's main states (loading, empty, populated, error) using fake controllers via Riverpod overrides. Screens are tested with a mocked `MediaPickerService` and `Dio` (using `mocktail`).

Verification before completion: `flutter analyze` clean, `flutter test` green, `flutter build apk --debug` succeeds, and the app launches on an Android emulator through the configure and login screens against a stub server or the real HMSServer if it is running.

## 9. Delivery

The port is committed to this repository on `main`. The React Native repository is left untouched as the reference implementation. A `README.md` describes setup (`flutter pub get`, `flutter gen-l10n`, `flutter run`), the feature-folder convention, and how to add a workflow.
