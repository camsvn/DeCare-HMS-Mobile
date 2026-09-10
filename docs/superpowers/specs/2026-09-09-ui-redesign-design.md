# DeCare HMS: UI/UX redesign

Date: 2026-09-09
Repo: `E:\Projects\personal\deCare\hms\HMSFlutter`, branch `flutter-port`
Builds on: `2026-09-08-flutter-port-design.md` (behaviour, API contract, feature layout are unchanged)

## 1. Goal

Make the app feel professional, compact and polished, and give it a shell that absorbs future modules without redesign. Presentation and navigation only: controllers, repositories, APIs and the server contract stay as they are.

Decisions taken with the user: dashboard of module cards for navigation; clinical dark-navy shell with the logo's blue-green gradient as the single accent; bundled Inter typeface; light theme only, built on semantic tokens so a dark palette can be added later; subtle motion.

## 2. Design tokens (`lib/core/design/tokens/`)

Screens never reference raw colours or sizes. Files: `ds_colors.dart`, `ds_typography.dart`, `ds_spacing.dart`, `ds_radius.dart`, `ds_motion.dart`, `ds_theme.dart` (builds `ThemeData` from the tokens and exposes them as a `ThemeExtension` named `DsColors`).

Colour (light):

| Token | Value | Use |
|---|---|---|
| `canvas` | `#F4F6FA` | page background |
| `card` | `#FFFFFF` | cards, sheets, fields |
| `shell` | `#151D28` | app bar, bottom bar, onboarding upper area, splash |
| `shellRaised` | `#1E2938` | selected tab background, chips on navy |
| `textPrimary` | `#121826` | headings, values |
| `textSecondary` | `#5B6472` | labels, helper text |
| `textOnShell` | `#FFFFFF`; muted at 70% alpha | text on navy |
| `borderSubtle` | `#E3E7EE` | field outlines, dividers, card border |
| `accentGradient` | linear `#6D5BD0` → `#2F8FE5` → `#10B394`, left to right | primary buttons, active tab underline, module icon tiles, progress bar, FAB |
| `accentSolid` | `#2F8FE5` | links, focus ring, small icons |
| `success` / `warning` / `danger` | `#1F9D6A` / `#E0A100` / `#E5484D` | banners, status dot, destructive icons |

Rule: the gradient is reserved for the primary action, module icon tiles, the FAB, progress and the active tab underline; decorative use elsewhere is not allowed.

Typography: Inter, bundled at `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf`, declared in `pubspec.yaml`.

| Style | Size / weight / extra | Use |
|---|---|---|
| `display` | 28 / 700 | onboarding brand title |
| `title` | 20 / 600 | app bar titles, patient name |
| `heading` | 16 / 600 | section headers, card titles |
| `body` | 14 / 400 | default |
| `label` | 12 / 500, letter spacing 0.3 | field labels, chips, tab labels |
| `mono` | 14 / 500, `FontFeature.tabularFigures()` | OP numbers, dates, counts |

Spacing scale: 4, 8, 12, 16, 20, 24, 32. Screen gutter 16, card padding 12. Radius: 8 fields and buttons, 12 cards, 16 sheets, full for FAB and chips. No card shadows; depth comes from canvas-versus-card contrast plus a 1 px subtle border. Only the FAB has a shadow: 8 px blur, `accentSolid` at 25%.

Motion: `fast` 120 ms, `base` 200 ms, `slow` 320 ms, curve `easeOutCubic`. Skeleton shimmer 1.2 s. When `MediaQuery.disableAnimations` is true, transitions become plain fades of `fast` and staggers are skipped.

## 3. Shell, dashboard, module registry

**Shell** (`lib/app/app_shell.dart`, restyled): `DsAppBar` (48 dp), content on `canvas`, `DsBottomBar` with Home and Settings. Bottom bar hides with the keyboard. Back-button handling is unchanged from the current shell (double-press to exit on Home, Settings returns to Home).

**Module registry** (`lib/core/modules/app_module.dart`):

```dart
class AppModule {
  const AppModule({required this.id, required this.title, required this.subtitle,
    required this.icon, required this.entryRoute, required this.routes, this.badge});
  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final IconData icon;
  final String entryRoute;
  final List<RouteBase> routes;      // nested under the Home branch
  final Widget Function(WidgetRef ref)? badge;
}
```

Each feature that is a module exports one `AppModule` from its barrel. `lib/app/modules.dart` holds `final List<AppModule> appModules = [tomogramModule];`. `router.dart` spreads `for (m in appModules) ...m.routes` into the Home branch under the dashboard route. The dashboard renders `appModules`. Adding a module edits `modules.dart` only.

**Dashboard** (`lib/features/dashboard/`, new feature, presentation only): route `/app/home`. Layout: context strip on `shell` colour flush under the app bar showing the server host (from the configured URL), the username (from the JWT payload `username` claim, decoded by a new `jwtClaim` helper in `core/utils/jwt.dart`) and a `DsStatusDot` (success when the last health check on this session succeeded, warning otherwise; the dashboard triggers one health check on first build through the existing `HealthCheckApi`). Then a "Modules" heading and a two-column grid of `ModuleCard`s. While `appModules.length == 1`, a dashed placeholder tile labelled "More modules coming" fills the second cell.

**Tomogram module**: `tomogramModule` exports id `tomogram`, icon `Icons.photo_camera_back_outlined`, entry `/app/tomogram`, routes: `/app/tomogram` (the `patient_lookup` screen, registered by the tomogram module), `/app/tomogram/:opid`, `/app/tomogram/permission`. Badge: the recent-searches count as a mono chip when non-zero. `RoutePaths` gains `dashboard = '/app/home'`, `tomogramEntry = '/app/tomogram'`; `tomogram(opid)` and `permission` move under `/app/tomogram`.

**Onboarding** (Configure URL, Login): outside the shell. Upper area on `shell` with the circle logo (72 dp) and "DeCare HMS" in `display` on white; a `card` panel with top radius 24 rises from the bottom (`slow`) holding the form.

## 4. Component kit (`lib/core/design/widgets/`)

| Component | Replaces | Notes |
|---|---|---|
| `DsAppBar` | `AppHeader` | 48 dp, title left in `title`, leading back arrow when the route can pop, `actions` slot, always full width. |
| `DsBottomBar` | `AppTabBar` | Two destinations, gradient 2 px underline on active, `Semantics(selected: true)`. |
| `ModuleCard` | new | 40 dp gradient icon tile, title `heading`, subtitle `body` secondary, optional badge, press scale 0.98 over `fast`. |
| `DsCard` | ad hoc cards | `card` colour, radius 12, 1 px `borderSubtle`, padding 12. |
| `DsListRow` | `RecentSearchRow`, `SettingsRow` | 56 dp; leading icon tile optional; title; trailing mono value, chevron, or destructive icon button. |
| `DsTextField` | `AppTextField` | Filled `card`, `borderSubtle` outline, 2 px `accentSolid` focus ring, label above in `label`, error text below in `danger`, prefix/suffix icons, `mono: true` variant. Keeps `controller`, `onSubmitted`, `onChanged`, `inputFormatters`, `maxLength`, `maxLines`, `readOnly`, `obscureText`, `autofocus`, `textInputAction`, `keyboardType`. |
| `DsButton` | `PrimaryButton`, `LinkButton` | `DsButton.primary` (gradient, white text, 44 dp), `.secondary` (card fill, subtle border), `.ghost`, `.destructive`; `loading` shows an inline spinner and disables. |
| `DsFab` | inline "+" | 52 dp gradient circle with the blue shadow. |
| `showDsSheet` | `showAppBottomSheet` | Root navigator, radius 16, drag handle; builder receives the sheet context (same contract as today). |
| `DsBanner` / `showDsBanner` | `showFlash` | Top overlay, slides in over `base`, auto-dismiss 2.5 s, variants success/warning/danger/info with leading icon. Queued: a new banner waits for the current one instead of replacing it. |
| `showDsDialog` | `showConfirmDialog` | Title, body, secondary cancel, primary or destructive confirm; returns `bool`. |
| `DsEmptyState` | two empty-state widgets | illustration slot, heading, body, optional action. |
| `DsSkeleton` | new | shimmer blocks (`DsSkeleton.row`, `DsSkeleton.card`). |
| `DsStatusDot` | new | 8 dp dot, success or warning. |
| `DsProgressBar` | new | 3 dp indeterminate bar with the gradient, used under the app bar during upload. |
| `DsChip` | new | mono or label text on `shellRaised` (on navy) or `canvas` (on white). |

`LoaderModal` is removed. A lookup keeps the recent list on screen and spins in the row it came from (see **Find patient**); uploads show `DsProgressBar` and disable the action.

Icons: Flutter Material icons, outlined variants only, 20 dp in rows, 24 dp in bars.

## 5. Screens

**Configure URL**: onboarding layout. Card: heading "Connect to your server", helper text, `DsTextField` with `link` prefix and the existing placeholder, `DsButton.primary` "Connect" (loading inline). Invalid URL marks the field with error text as well as the banner.

**Login**: onboarding layout. Card: mono `DsChip` with the server host at the top, username, password (visibility toggle), `DsButton.primary` "Sign In", `DsButton.ghost` "Change server".

**Dashboard**: as section 3. App bar title "DeCare HMS".

**Find patient** (`patient_lookup`, route `/app/tomogram`): app bar "Tomogram" with back arrow. Search bar under the app bar: `DsTextField(mono: true)` numeric with search prefix, clear suffix when non-empty, and a gradient "Go" `DsButton.primary` (compact, 40 dp) that appears only with text. "Recent" heading with ghost "Clear". `DsListRow`s: person icon tile, name, mono OP number, trash icon; `Dismissible` swipe-to-delete as well. While a lookup runs the list stays exactly as it is — no skeletons, no reordering: the search bar goes busy, every row goes inert, and the row whose OP is being looked up shows a small progress ring in place of its trash icon (updated 2026-09-10). The patient moves to the top of recents only once the tomogram screen it opened has been popped. `DsEmptyState` with the existing illustration.

**Tomogram** (`/app/tomogram/:opid`): app bar title = patient name, with a mono `DsChip` of the OP number beside it; back arrow; trailing `DsButton.ghost` "Upload" in `accentSolid` visible once a draft exists. Back with drafts present asks via `showDsDialog` ("Discard photos?") before clearing and popping; without drafts it pops directly. The separate patient bar and footer OP field are removed. Draft cards: `DsCard` with the image 16:10, radius 8, a mono "1 of 3" `DsChip` at the image corner, trash icon button, description `DsTextField` (3 lines, 200 char counter). `DsFab` bottom-right, 16 dp above the bottom bar. During upload: `DsProgressBar` under the app bar, FAB and Upload disabled. Success: success banner, pop. Failure: danger banner, drafts kept.

**Permission**: inside the shell; icon tile, heading, body, `DsButton.primary` "Grant Permission".

**Settings**: app bar "Settings". `DsCard` group "Server": row with the host as mono trailing value and chevron → change-URL flow (dialog then reset+logout). Group "Account": row with the username (mono), row "Sign out" destructive → dialog then logout. Group "Help": row "About" → About. Footer: app version and build from `package_info_plus`, `label` style, centred.

**About**: content unchanged, sections on `DsCard`s, app bar "About" with back arrow.

Copy changes go into `app_en.arb`; unused keys are removed at the end.

## 6. Motion

Route transitions: fade-through (outgoing fades over `fast`; incoming fades and translates up 8 dp over `base`) via a custom `Page` used by all routes in `router.dart`. Dashboard cards and recent rows stagger in 30 ms apart on first build only. `DsButton` and `ModuleCard` scale to 0.98 on press. Banners slide from the top. Sheets keep the Material slide. Everything collapses to fades when animations are disabled system-wide.

## 7. Testing and verification

- Widget tests for every kit component's states (`test/core/design/`).
- Screen behaviour tests updated for new copy and structure; the controller, repository and API tests are untouched.
- Dashboard tests: renders one `ModuleCard` per registered module plus the placeholder when only one; tapping the Tomogram card navigates to `/app/tomogram` (router-level test).
- Router tests updated for the new paths.
- Final verification: `flutter analyze` clean, `flutter test` green, `flutter build apk --debug`, and an emulator walkthrough with screenshots of every screen, as done for the port.

## 8. Dependencies added

`package_info_plus` (app version in Settings). Inter font files (SIL Open Font License) under `assets/fonts/`. Nothing else.

## 9. Out of scope

Dark palette values, the tomogram history feature, server changes, iOS verification.
