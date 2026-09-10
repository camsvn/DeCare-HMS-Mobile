# DeCare HMS UI/UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the app's presentation layer on a token-driven design system with a navy shell, gradient accent, Inter typography, a module dashboard, and compact screens, without changing controllers, repositories, APIs or the server contract.

**Architecture:** New `lib/core/design/` holds tokens (`DsColors`, `DsType` as `ThemeExtension`s, `DsSpace`, `DsRadius`, `DsMotion`) and a component kit (`Ds*` widgets). `lib/core/modules/app_module.dart` defines module descriptors; `lib/app/modules.dart` lists them; the router spreads their routes and a new `dashboard` feature renders them. Screens are rebuilt on the kit; old core widgets are deleted at the end.

**Tech Stack:** Flutter 3.19 / Dart 3.3, existing Riverpod 2.6 and go_router 14.6, bundled Inter TTFs, `package_info_plus` 8.0.2.

**Spec:** `docs/superpowers/specs/2026-09-09-ui-redesign-design.md`

## Global Constraints

- SDK Flutter 3.19.0 / Dart 3.3.0. No `flutter upgrade`. New dependency allowed: `package_info_plus: ^8.0.2` only.
- `core` never imports `features`. Features import other features only via barrels. The `app/` layer may import anything.
- Screens never use raw colours, sizes or font names: everything comes from `context.ds` (colours), `context.dsType` (text styles), `DsSpace`, `DsRadius`, `DsMotion`.
- All user-visible strings via `context.l10n` from `lib/core/l10n/app_en.arb`; run `flutter gen-l10n` after editing it.
- The gradient (`ds.accentGradient`) is reserved for the primary action, module icon tiles, the FAB, progress and the active tab underline; decorative use elsewhere is not allowed.
- Behaviour and copy of existing flows stay as tested today unless the spec changes them (listed per task). Controller, repository and API tests must not change.
- Every task ends with `flutter analyze` clean, `flutter test` green, then a commit. Run all commands from `E:\Projects\personal\deCare\hms\HMSFlutter` (Git Bash: `cd "E:/Projects/personal/deCare/hms/HMSFlutter"`).
- Font files are already downloaded at `C:\Users\amals\AppData\Local\Temp\claude\E--Projects-personal-deCare-hms-HMSUploader\ea7319d7-0f7a-40c8-b324-d6f735e540f1\scratchpad\inter\extras\ttf\Inter-{Regular,Medium,SemiBold,Bold}.ttf` with `LICENSE.txt` one folder up.

---

## File map

| Path | Responsibility |
|---|---|
| `lib/core/design/tokens/ds_colors.dart` | `DsColors` ThemeExtension, light palette |
| `lib/core/design/tokens/ds_type.dart` | `DsType` ThemeExtension with the six text styles |
| `lib/core/design/tokens/ds_space.dart`, `ds_radius.dart`, `ds_motion.dart` | scales and durations |
| `lib/core/design/ds_theme.dart` | `buildDsTheme()` and `context.ds` / `context.dsType` extensions |
| `lib/core/design/widgets/*.dart` | the kit (one widget per file) |
| `lib/core/design/design.dart` | barrel exporting tokens and widgets |
| `lib/core/design/transitions/fade_through_page.dart` | route transition |
| `lib/core/modules/app_module.dart` | module descriptor |
| `lib/app/modules.dart` | registered modules |
| `lib/features/dashboard/**` | dashboard screen |
| `assets/fonts/` | Inter TTFs and licence |

---

### Task 1: Tokens, fonts, theme, route paths

**Files:**
- Create: `lib/core/design/tokens/ds_colors.dart`, `lib/core/design/tokens/ds_type.dart`, `lib/core/design/tokens/ds_space.dart`, `lib/core/design/tokens/ds_radius.dart`, `lib/core/design/tokens/ds_motion.dart`, `lib/core/design/ds_theme.dart`, `lib/core/design/design.dart`, `assets/fonts/Inter-*.ttf`, `assets/fonts/LICENSE-Inter.txt`
- Modify: `pubspec.yaml`, `lib/core/navigation/route_paths.dart`, `lib/app/app.dart` (use `buildDsTheme`)
- Test: `test/core/design/ds_theme_test.dart`

**Interfaces:**
- Produces: `DsColors` (fields `canvas, card, shell, shellRaised, textPrimary, textSecondary, textOnShell, textOnShellMuted, borderSubtle, accentSolid, success, warning, danger` as `Color`, `accentGradient` as `LinearGradient`; `DsColors.light`), `DsType` (fields `display, title, heading, body, label, mono` as `TextStyle`, all coloured `textPrimary`; `DsType.inter(DsColors)`), `DsSpace.{x1,x2,x3,x4,x5,x6,x8,gutter}`, `DsRadius.{small,medium,large,full}`, `DsMotion.{fast,base,slow,curve}` and `DsMotion.of(BuildContext, Duration)`, `ThemeData buildDsTheme()`, `extension DsContext on BuildContext { DsColors get ds; DsType get dsType; }`, `extension DsTextStyleX on TextStyle { TextStyle withColor(Color c); }`, `RoutePaths.dashboard`, `RoutePaths.tomogramEntry`, `RoutePaths.tomogram(int)` now `'/app/tomogram/$opid'`, `RoutePaths.permission` now `'/app/tomogram/permission'`.

- [ ] **Step 1: Fonts and pubspec**

```bash
cd "E:/Projects/personal/deCare/hms/HMSFlutter"
mkdir -p assets/fonts
SRC="C:/Users/amals/AppData/Local/Temp/claude/E--Projects-personal-deCare-hms-HMSUploader/ea7319d7-0f7a-40c8-b324-d6f735e540f1/scratchpad/inter"
cp "$SRC/extras/ttf/Inter-Regular.ttf" "$SRC/extras/ttf/Inter-Medium.ttf" "$SRC/extras/ttf/Inter-SemiBold.ttf" "$SRC/extras/ttf/Inter-Bold.ttf" assets/fonts/
cp "$SRC/LICENSE.txt" assets/fonts/LICENSE-Inter.txt
flutter pub add package_info_plus
```

In `pubspec.yaml` under `flutter:` add (keep the existing `assets:` list):

```yaml
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

- [ ] **Step 2: Write the failing theme test**

`test/core/design/ds_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('theme exposes tokens through context extensions', (tester) async {
    late DsColors ds;
    late DsType type;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Builder(builder: (context) {
        ds = context.ds;
        type = context.dsType;
        return const SizedBox();
      }),
    ));
    expect(ds.shell, const Color(0xFF151D28));
    expect(ds.canvas, const Color(0xFFF4F6FA));
    expect(ds.accentGradient.colors, hasLength(3));
    expect(type.body.fontFamily, 'Inter');
    expect(type.body.fontSize, 14);
    expect(type.title.fontWeight, FontWeight.w600);
    expect(type.mono.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(type.body.color, ds.textPrimary);
  });

  test('DsMotion.of collapses to fast when animations are disabled', () {
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: true), DsMotion.fast);
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: false),
        const Duration(milliseconds: 320));
  });
}
```

- [ ] **Step 3: Run it, expect compile failure**

```bash
flutter test test/core/design
```

- [ ] **Step 4: Implement tokens**

`lib/core/design/tokens/ds_colors.dart`:

```dart
import 'package:flutter/material.dart';

/// Semantic colour tokens. Screens read these through `context.ds`; nothing
/// outside this file names a raw colour.
class DsColors extends ThemeExtension<DsColors> {
  const DsColors({
    required this.canvas,
    required this.card,
    required this.shell,
    required this.shellRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnShell,
    required this.textOnShellMuted,
    required this.borderSubtle,
    required this.accentSolid,
    required this.accentGradient,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color card;
  final Color shell;
  final Color shellRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnShell;
  final Color textOnShellMuted;
  final Color borderSubtle;
  final Color accentSolid;
  final LinearGradient accentGradient;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = DsColors(
    canvas: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    shell: Color(0xFF151D28),
    shellRaised: Color(0xFF1E2938),
    textPrimary: Color(0xFF121826),
    textSecondary: Color(0xFF5B6472),
    textOnShell: Color(0xFFFFFFFF),
    textOnShellMuted: Color(0xB3FFFFFF),
    borderSubtle: Color(0xFFE3E7EE),
    accentSolid: Color(0xFF2F8FE5),
    accentGradient: LinearGradient(
      colors: [Color(0xFF6D5BD0), Color(0xFF2F8FE5), Color(0xFF10B394)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    success: Color(0xFF1F9D6A),
    warning: Color(0xFFE0A100),
    danger: Color(0xFFE5484D),
  );

  @override
  DsColors copyWith({
    Color? canvas,
    Color? card,
    Color? shell,
    Color? shellRaised,
    Color? textPrimary,
    Color? textSecondary,
    Color? textOnShell,
    Color? textOnShellMuted,
    Color? borderSubtle,
    Color? accentSolid,
    LinearGradient? accentGradient,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return DsColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      shell: shell ?? this.shell,
      shellRaised: shellRaised ?? this.shellRaised,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textOnShell: textOnShell ?? this.textOnShell,
      textOnShellMuted: textOnShellMuted ?? this.textOnShellMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentSolid: accentSolid ?? this.accentSolid,
      accentGradient: accentGradient ?? this.accentGradient,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  DsColors lerp(DsColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return DsColors(
      canvas: c(canvas, other.canvas),
      card: c(card, other.card),
      shell: c(shell, other.shell),
      shellRaised: c(shellRaised, other.shellRaised),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textOnShell: c(textOnShell, other.textOnShell),
      textOnShellMuted: c(textOnShellMuted, other.textOnShellMuted),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      accentSolid: c(accentSolid, other.accentSolid),
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t)!,
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
    );
  }
}
```

`lib/core/design/tokens/ds_type.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_colors.dart';

/// The six text styles. All default to `textPrimary`; use `withColor` for
/// secondary or on-shell text.
class DsType extends ThemeExtension<DsType> {
  const DsType({
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.label,
    required this.mono,
  });

  static const String family = 'Inter';

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle label;
  final TextStyle mono;

  factory DsType.inter(DsColors colors) {
    final c = colors.textPrimary;
    return DsType(
      display: TextStyle(fontFamily: family, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: c),
      title: TextStyle(fontFamily: family, fontSize: 20, fontWeight: FontWeight.w600, height: 1.25, color: c),
      heading: TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3, color: c),
      body: TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45, color: c),
      label: TextStyle(
          fontFamily: family, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3, height: 1.3, color: c),
      mono: TextStyle(
        fontFamily: family,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  @override
  DsType copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? label,
    TextStyle? mono,
  }) =>
      DsType(
        display: display ?? this.display,
        title: title ?? this.title,
        heading: heading ?? this.heading,
        body: body ?? this.body,
        label: label ?? this.label,
        mono: mono ?? this.mono,
      );

  @override
  DsType lerp(DsType? other, double t) {
    if (other == null) return this;
    return DsType(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}

extension DsTextStyleX on TextStyle {
  TextStyle withColor(Color color) => copyWith(color: color);
}
```

`lib/core/design/tokens/ds_space.dart`:

```dart
/// Spacing scale in logical pixels.
abstract final class DsSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double gutter = 16;
  static const double cardPadding = 12;
}
```

`lib/core/design/tokens/ds_radius.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class DsRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double sheet = 24;
  static const double full = 999;

  static BorderRadius get smallAll => BorderRadius.circular(small);
  static BorderRadius get mediumAll => BorderRadius.circular(medium);
  static BorderRadius get largeAll => BorderRadius.circular(large);
}
```

`lib/core/design/tokens/ds_motion.dart`:

```dart
import 'package:flutter/widgets.dart';

abstract final class DsMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration shimmer = Duration(milliseconds: 1200);
  static const Duration stagger = Duration(milliseconds: 30);

  /// Collapses any duration to [fast] when the OS asks for reduced motion.
  static Duration resolve(Duration duration, {required bool disableAnimations}) =>
      disableAnimations ? fast : duration;

  static Duration of(BuildContext context, Duration duration) =>
      resolve(duration, disableAnimations: MediaQuery.disableAnimationsOf(context));
}
```

- [ ] **Step 5: Theme and barrel**

`lib/core/design/ds_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_colors.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

ThemeData buildDsTheme() {
  const colors = DsColors.light;
  final type = DsType.inter(colors);
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: colors.accentSolid,
      onPrimary: colors.textOnShell,
      surface: colors.card,
      onSurface: colors.textPrimary,
      error: colors.danger,
      outline: colors.borderSubtle,
    ),
    textTheme: base.textTheme.apply(fontFamily: DsType.family, bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
    dividerColor: colors.borderSubtle,
    splashFactory: InkSparkle.splashFactory,
    extensions: [colors, type],
  );
}

extension DsContext on BuildContext {
  DsColors get ds => Theme.of(this).extension<DsColors>() ?? DsColors.light;
  DsType get dsType => Theme.of(this).extension<DsType>() ?? DsType.inter(ds);
}
```

`lib/core/design/design.dart`:

```dart
export 'ds_theme.dart';
export 'tokens/ds_colors.dart';
export 'tokens/ds_motion.dart';
export 'tokens/ds_radius.dart';
export 'tokens/ds_space.dart';
export 'tokens/ds_type.dart';
```

(Tasks 2 and 3 append widget exports to this barrel.)

- [ ] **Step 6: Route paths**

Replace `lib/core/navigation/route_paths.dart`:

```dart
/// Route locations shared by features and the router.
abstract final class RoutePaths {
  static const configure = '/configure';
  static const login = '/login';

  /// Dashboard: the Home tab root.
  static const dashboard = '/app/home';
  static const home = dashboard;

  /// Tomogram module.
  static const tomogramEntry = '/app/tomogram';
  static const tomogramPattern = ':opid';
  static String tomogram(int opid) => '$tomogramEntry/$opid';
  static const permissionPattern = 'permission';
  static const permission = '$tomogramEntry/permission';

  static const settings = '/app/settings';
  static const aboutPattern = 'about';
  static const about = '$settings/about';
}
```

Note: `tomogramPattern` is now `':opid'` because the tomogram routes nest under the module entry route in Task 4. Until Task 4 rewires the router, `flutter test test/app` may fail on paths; that is expected and listed there. Run `flutter test` excluding `test/app` in this task: `flutter test test/core test/features`.

- [ ] **Step 7: Use the theme**

In `lib/app/app.dart` replace `buildAppTheme()` with `buildDsTheme()` (import `package:hms_uploader/core/design/design.dart`) and change `appOverlayStyle.statusBarColor` to `DsColors.light.shell`. Leave `lib/core/theme/` in place; Task 8 deletes it.

- [ ] **Step 8: Verify and commit**

```bash
flutter test test/core test/features && flutter analyze
git add -A && git commit -m "feat(design): tokens, Inter fonts, theme and new route paths"
```

---

### Task 2: Kit part 1 — surfaces, bars, rows, chips, states

**Files:**
- Create: `lib/core/design/widgets/ds_app_bar.dart`, `ds_bottom_bar.dart`, `ds_card.dart`, `ds_list_row.dart`, `ds_chip.dart`, `ds_status_dot.dart`, `ds_empty_state.dart`, `ds_skeleton.dart`, `ds_progress_bar.dart`, `ds_icon_tile.dart`
- Modify: `lib/core/design/design.dart` (exports)
- Test: `test/core/design/ds_app_bar_test.dart`, `test/core/design/ds_bottom_bar_test.dart`, `test/core/design/ds_list_row_test.dart`, `test/core/design/ds_skeleton_test.dart`

**Interfaces:**
- Produces:
  - `DsAppBar({required String title, Widget? titleTrailing, List<Widget> actions = const [], bool automaticallyImplyLeading = true, VoidCallback? onBack})` — `PreferredSizeWidget`, height 48 + top inset, shows a back arrow when `onBack != null` or when `Navigator.canPop(context)` and `automaticallyImplyLeading`.
  - `DsBottomBar({required int currentIndex, required ValueChanged<int> onTap, required List<DsDestination> destinations})`, `DsDestination({required IconData icon, required String label})`.
  - `DsCard({required Widget child, EdgeInsets? padding, VoidCallback? onTap})`.
  - `DsListRow({required String title, IconData? leadingIcon, String? trailingValue, bool chevron = false, IconData? trailingIcon, VoidCallback? onTrailingTap, VoidCallback? onTap, bool destructive = false})`.
  - `DsChip({required String text, bool mono = false, bool onShell = false})`.
  - `DsStatusDot({required bool ok})`.
  - `DsEmptyState({Widget? illustration, required String heading, required String body, Widget? action})`.
  - `DsSkeleton.row()`, `DsSkeleton.card({double height = 120})`.
  - `DsProgressBar()` (indeterminate, 3 dp, gradient).
  - `DsIconTile({required IconData icon, double size = 40})` (gradient tile with white icon).

- [ ] **Step 1: Write failing tests**

`test/core/design/ds_app_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('spans the width, shows title, actions and back when it can pop', (tester) async {
    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        appBar: DsAppBar(title: 'Tomogram', onBack: () => backs++, actions: const [Icon(Icons.check)]),
      ),
    ));
    expect(tester.getSize(find.byType(DsAppBar)).width, tester.getSize(find.byType(Scaffold)).width);
    expect(find.text('Tomogram'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backs, 1);
  });

  testWidgets('hides the back arrow on a root route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(appBar: DsAppBar(title: 'Home')),
    ));
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
```

`test/core/design/ds_bottom_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('reports taps and marks the active destination selected', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        bottomNavigationBar: DsBottomBar(
          currentIndex: 0,
          onTap: (i) => tapped = i,
          destinations: const [
            DsDestination(icon: Icons.home_outlined, label: 'Home'),
            DsDestination(icon: Icons.settings_outlined, label: 'Settings'),
          ],
        ),
      ),
    ));
    await tester.tap(find.text('Settings'));
    expect(tapped, 1);
    final home = tester.getSemantics(find.text('Home'));
    expect(home.hasFlag(SemanticsFlag.isSelected), isTrue);
  });
}
```

`test/core/design/ds_list_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('renders title, mono value, and separate trailing action', (tester) async {
    var taps = 0;
    var trailing = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsListRow(
          leadingIcon: Icons.person_outline,
          title: 'Jane',
          trailingValue: '580',
          trailingIcon: Icons.delete_outline,
          onTrailingTap: () => trailing++,
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('580'), findsOneWidget);
    await tester.tap(find.text('Jane'));
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(taps, 1);
    expect(trailing, 1);
    expect(tester.getSize(find.byType(DsListRow)).height, 56);
  });
}
```

`test/core/design/ds_skeleton_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('skeleton animates and disposes cleanly', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildDsTheme(), home: Scaffold(body: DsSkeleton.row())));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DsSkeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
```

- [ ] **Step 2: Run tests, expect compile failure**

```bash
flutter test test/core/design
```

- [ ] **Step 3: Implement**

`lib/core/design/widgets/ds_icon_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';

/// Gradient square with a white icon: the module-card and empty-state motif.
class DsIconTile extends StatelessWidget {
  const DsIconTile({super.key, required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: context.ds.accentGradient, borderRadius: BorderRadius.circular(DsRadius.small)),
      alignment: Alignment.center,
      child: Icon(icon, color: context.ds.textOnShell, size: size * 0.55),
    );
  }
}
```

`lib/core/design/widgets/ds_app_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// 48 dp navy bar. Full width, left-aligned title, optional trailing widget
/// beside the title (e.g. an OP chip) and actions on the right.
class DsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DsAppBar({
    super.key,
    required this.title,
    this.titleTrailing,
    this.actions = const [],
    this.automaticallyImplyLeading = true,
    this.onBack,
  });

  static const double barHeight = 48;

  final String title;
  final Widget? titleTrailing;
  final List<Widget> actions;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final canPop = onBack != null || (automaticallyImplyLeading && (ModalRoute.of(context)?.canPop ?? false));
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: ds.shell,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          height: barHeight,
          width: double.infinity,
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  icon: Icon(Icons.arrow_back, color: ds.textOnShell, size: 24),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                )
              else
                const SizedBox(width: DsSpace.gutter),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: context.dsType.title.withColor(ds.textOnShell),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (titleTrailing != null) ...[const SizedBox(width: DsSpace.x2), titleTrailing!],
                  ],
                ),
              ),
              ...actions,
              const SizedBox(width: DsSpace.x1),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_bottom_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsDestination {
  const DsDestination({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Navy bottom bar; the active destination gets a gradient underline.
class DsBottomBar extends StatelessWidget {
  const DsBottomBar({super.key, required this.currentIndex, required this.onTap, required this.destinations});

  static const double barHeight = 60;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DsDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: ds.shell,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: barHeight,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == currentIndex,
                    button: true,
                    label: destinations[i].label,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(destinations[i].icon,
                              size: 24, color: i == currentIndex ? ds.textOnShell : ds.textOnShellMuted),
                          const SizedBox(height: 2),
                          Text(destinations[i].label,
                              style: context.dsType.label
                                  .withColor(i == currentIndex ? ds.textOnShell : ds.textOnShellMuted)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: DsMotion.of(context, DsMotion.base),
                            curve: DsMotion.curve,
                            height: 2,
                            width: i == currentIndex ? 28 : 0,
                            decoration: BoxDecoration(gradient: ds.accentGradient, borderRadius: BorderRadius.circular(1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// White surface with a 1 px subtle border. No shadow.
class DsCard extends StatelessWidget {
  const DsCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Material(
      color: ds.card,
      shape: RoundedRectangleBorder(
        borderRadius: DsRadius.mediumAll,
        side: BorderSide(color: ds.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(DsSpace.cardPadding), child: child),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_list_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// 56 dp row: optional leading icon, title, optional mono value, chevron or
/// trailing icon action (which does not trigger [onTap]).
class DsListRow extends StatelessWidget {
  const DsListRow({
    super.key,
    required this.title,
    this.leadingIcon,
    this.trailingValue,
    this.chevron = false,
    this.trailingIcon,
    this.onTrailingTap,
    this.onTap,
    this.destructive = false,
  });

  static const double height = 56;

  final String title;
  final IconData? leadingIcon;
  final String? trailingValue;
  final bool chevron;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final titleColor = destructive ? ds.danger : ds.textPrimary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.x3),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: ds.canvas, borderRadius: BorderRadius.circular(DsRadius.small)),
                  alignment: Alignment.center,
                  child: Icon(leadingIcon, size: 20, color: destructive ? ds.danger : ds.textSecondary),
                ),
                const SizedBox(width: DsSpace.x3),
              ],
              Expanded(
                child: Text(title, style: type.body.withColor(titleColor), overflow: TextOverflow.ellipsis),
              ),
              if (trailingValue != null) ...[
                const SizedBox(width: DsSpace.x2),
                Text(trailingValue!, style: type.mono.withColor(ds.textSecondary)),
              ],
              if (chevron) Icon(Icons.chevron_right, size: 20, color: ds.textSecondary),
              if (trailingIcon != null)
                IconButton(
                  icon: Icon(trailingIcon, size: 20, color: destructive ? ds.danger : ds.textSecondary),
                  onPressed: onTrailingTap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_chip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

/// Small pill for values like OP numbers, hosts, counts.
class DsChip extends StatelessWidget {
  const DsChip({super.key, required this.text, this.mono = false, this.onShell = false});

  final String text;
  final bool mono;
  final bool onShell;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final base = mono ? context.dsType.mono : context.dsType.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.x2, vertical: 2),
      decoration: BoxDecoration(
        color: onShell ? ds.shellRaised : ds.canvas,
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: onShell ? null : Border.all(color: ds.borderSubtle),
      ),
      child: Text(text, style: base.copyWith(fontSize: 12, color: onShell ? ds.textOnShell : ds.textSecondary)),
    );
  }
}
```

`lib/core/design/widgets/ds_status_dot.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

class DsStatusDot extends StatelessWidget {
  const DsStatusDot({super.key, required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ok ? ds.success : ds.warning),
    );
  }
}
```

`lib/core/design/widgets/ds_empty_state.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsEmptyState extends StatelessWidget {
  const DsEmptyState({super.key, this.illustration, required this.heading, required this.body, this.action});

  final Widget? illustration;
  final String heading;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              SizedBox(height: 180, child: illustration),
              const SizedBox(height: DsSpace.x6),
            ],
            Text(heading, style: type.heading, textAlign: TextAlign.center),
            const SizedBox(height: DsSpace.x1),
            Text(body, style: type.body.withColor(ds.textSecondary), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: DsSpace.x4), action!],
          ],
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_skeleton.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// Shimmering placeholder blocks.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton._({super.key, required this.height, required this.rows});

  factory DsSkeleton.row({Key? key}) => DsSkeleton._(key: key, height: 56, rows: 1);
  factory DsSkeleton.card({Key? key, double height = 120}) => DsSkeleton._(key: key, height: height, rows: 1);

  final double height;
  final int rows;

  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DsMotion.shimmer)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          margin: const EdgeInsets.symmetric(horizontal: DsSpace.gutter, vertical: DsSpace.x1),
          decoration: BoxDecoration(
            borderRadius: DsRadius.mediumAll,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [ds.borderSubtle, ds.card, ds.borderSubtle],
            ),
          ),
        );
      },
    );
  }
}
```

`lib/core/design/widgets/ds_progress_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';

/// 3 dp indeterminate bar painted with the accent gradient.
class DsProgressBar extends StatefulWidget {
  const DsProgressBar({super.key});

  @override
  State<DsProgressBar> createState() => _DsProgressBarState();
}

class _DsProgressBarState extends State<DsProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DsMotion.shimmer)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth * 0.35;
            final x = -w + (c.maxWidth + w) * _controller.value;
            return Stack(
              children: [
                Container(color: ds.borderSubtle),
                Positioned(
                  left: x,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: ds.accentGradient)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

Add to `lib/core/design/design.dart`:

```dart
export 'widgets/ds_app_bar.dart';
export 'widgets/ds_bottom_bar.dart';
export 'widgets/ds_card.dart';
export 'widgets/ds_chip.dart';
export 'widgets/ds_empty_state.dart';
export 'widgets/ds_icon_tile.dart';
export 'widgets/ds_list_row.dart';
export 'widgets/ds_progress_bar.dart';
export 'widgets/ds_skeleton.dart';
export 'widgets/ds_status_dot.dart';
```

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/core && flutter analyze
git add -A && git commit -m "feat(design): kit part 1 (app bar, bottom bar, card, row, chip, dot, empty, skeleton, progress)"
```

---

### Task 3: Kit part 2 — inputs, buttons, overlays, module card, transition

**Files:**
- Create: `lib/core/design/widgets/ds_text_field.dart`, `ds_button.dart`, `ds_fab.dart`, `ds_sheet.dart`, `ds_banner.dart`, `ds_dialog.dart`, `module_card.dart`, `lib/core/design/transitions/fade_through_page.dart`
- Modify: `lib/core/design/design.dart`, `lib/core/l10n/app_en.arb` (dialog button labels)
- Test: `test/core/design/ds_text_field_test.dart`, `ds_button_test.dart`, `ds_banner_test.dart`, `ds_dialog_test.dart`, `module_card_test.dart`

**Interfaces:**
- Produces:
  - `DsTextField({TextEditingController? controller, String? label, String? hint, String? errorText, bool mono = false, bool obscureText = false, bool readOnly = false, bool autofocus = false, TextInputType? keyboardType, TextInputAction? textInputAction, List<TextInputFormatter>? inputFormatters, int? maxLength, int maxLines = 1, Widget? prefix, Widget? suffix, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, bool showCounter = false})`.
  - `DsButton.primary / .secondary / .ghost / .destructive({required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})`.
  - `DsFab({required IconData icon, required VoidCallback? onPressed, String? tooltip})`.
  - `Future<T?> showDsSheet<T>(BuildContext context, {required List<Widget> Function(BuildContext sheetContext) builder})`.
  - `enum DsBannerKind { success, warning, danger, info }`, `void showDsBanner(BuildContext context, String message, {DsBannerKind kind = DsBannerKind.info})` — queued.
  - `Future<bool> showDsDialog(BuildContext context, {required String title, String? body, String? confirmLabel, bool destructive = false})`.
  - `ModuleCard({required IconData icon, required String title, required String subtitle, Widget? badge, VoidCallback? onTap})`, `ModulePlaceholderCard({required String label})`.
  - `FadeThroughPage<T>({required Widget child, LocalKey? key, String? name, Object? arguments})`.
  - ARB keys: `commonConfirm` "Confirm", `commonDiscard` "Discard".

- [ ] **Step 1: Write failing tests**

`test/core/design/ds_text_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('shows label, hint, error and forwards input', (tester) async {
    String? changed;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsTextField(label: 'Username', hint: 'jane', errorText: 'Required', onChanged: (v) => changed = v),
      ),
    ));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('jane'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    expect(changed, 'abc');
  });

  testWidgets('mono variant uses tabular figures', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildDsTheme(), home: const Scaffold(body: DsTextField(mono: true))));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
```

`test/core/design/ds_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('primary fires onPressed and disables while loading', (tester) async {
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Column(children: [
          DsButton.primary(label: 'Go', onPressed: () => presses++),
          DsButton.primary(label: 'Busy', onPressed: () => presses++, loading: true),
        ]),
      ),
    ));
    await tester.tap(find.text('Go'));
    expect(presses, 1);
    expect(find.text('Busy'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    expect(presses, 1);
    expect(tester.getSize(find.byType(DsButton).first).height, 44);
  });

  testWidgets('variants render', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Column(children: [
          DsButton.secondary(label: 'Two', onPressed: () {}),
          DsButton.ghost(label: 'Three', onPressed: () {}),
          DsButton.destructive(label: 'Four', onPressed: () {}),
        ]),
      ),
    ));
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
  });
}
```

`test/core/design/ds_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('queues banners instead of replacing them', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showDsBanner(context, 'First', kind: DsBannerKind.warning);
              showDsBanner(context, 'Second', kind: DsBannerKind.success);
            },
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
  });
}
```

`test/core/design/ds_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('returns true on confirm, false on cancel', (tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDsDialog(context, title: 'Sign out?', body: 'You will need to sign in again.'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
```

`test/core/design/module_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('module card shows content and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: SizedBox(
          width: 180,
          child: ModuleCard(
            icon: Icons.photo_camera_back_outlined,
            title: 'Tomogram',
            subtitle: 'Upload skin photos',
            badge: const DsChip(text: '3', mono: true),
            onTap: () => taps++,
          ),
        ),
      ),
    ));
    expect(find.text('Tomogram'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Tomogram'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
```

Note: `pump_app.dart` currently applies `buildAppTheme()`; change it to `buildDsTheme()` in this task so dialog copy resolves against l10n (the helper already installs the localization delegates).

- [ ] **Step 2: Run tests, expect compile failure**

```bash
flutter test test/core/design
```

- [ ] **Step 3: ARB additions**

Add to `lib/core/l10n/app_en.arb`: `"commonConfirm": "Confirm"`, `"commonDiscard": "Discard"`. Run `flutter gen-l10n`.

- [ ] **Step 4: Implement**

`lib/core/design/widgets/ds_text_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsTextField extends StatelessWidget {
  const DsTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.mono = false,
    this.obscureText = false,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.showCounter = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool mono;
  final bool obscureText;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final style = (mono ? type.mono : type.body).withColor(ds.textPrimary);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: DsRadius.smallAll,
          borderSide: BorderSide(color: color, width: width),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: type.label.withColor(ds.textSecondary)),
          const SizedBox(height: DsSpace.x1),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: style,
          cursorColor: ds.accentSolid,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: style.withColor(ds.textSecondary),
            errorText: errorText,
            errorStyle: type.label.withColor(ds.danger),
            counterText: showCounter ? null : '',
            counterStyle: type.label.withColor(ds.textSecondary),
            filled: true,
            fillColor: ds.card,
            isDense: true,
            prefixIcon: prefix,
            suffixIcon: suffix,
            prefixIconColor: ds.textSecondary,
            suffixIconColor: ds.textSecondary,
            contentPadding: const EdgeInsets.symmetric(horizontal: DsSpace.x3, vertical: DsSpace.x3),
            enabledBorder: border(ds.borderSubtle),
            focusedBorder: border(ds.accentSolid, 2),
            errorBorder: border(ds.danger),
            focusedErrorBorder: border(ds.danger, 2),
            disabledBorder: border(ds.borderSubtle),
            border: border(ds.borderSubtle),
          ),
        ),
      ],
    );
  }
}
```

`lib/core/design/widgets/ds_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

enum DsButtonVariant { primary, secondary, ghost, destructive }

/// Button with four variants, inline loading state and a 0.98 press scale.
class DsButton extends StatefulWidget {
  const DsButton._({
    super.key,
    required this.variant,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    this.icon,
    this.height = 44,
  });

  const DsButton.primary({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.primary, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.secondary({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.secondary, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.ghost({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = false, IconData? icon, double height = 40})
      : this._(key: key, variant: DsButtonVariant.ghost, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.destructive({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.destructive, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);

  final DsButtonVariant variant;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final IconData? icon;
  final double height;

  @override
  State<DsButton> createState() => _DsButtonState();
}

class _DsButtonState extends State<DsButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;

    final Color fg;
    final Color? bg;
    final Gradient? gradient;
    final Border? border;
    switch (widget.variant) {
      case DsButtonVariant.primary:
        fg = ds.textOnShell;
        bg = null;
        gradient = ds.accentGradient;
        border = null;
      case DsButtonVariant.secondary:
        fg = ds.textPrimary;
        bg = ds.card;
        gradient = null;
        border = Border.all(color: ds.borderSubtle);
      case DsButtonVariant.ghost:
        fg = ds.accentSolid;
        bg = null;
        gradient = null;
        border = null;
      case DsButtonVariant.destructive:
        fg = ds.textOnShell;
        bg = ds.danger;
        gradient = null;
        border = null;
    }

    final child = widget.loading
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: DsSpace.x2)],
              Text(widget.label, style: type.body.copyWith(fontWeight: FontWeight.w600, color: fg)),
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: DsMotion.of(context, DsMotion.fast),
          curve: DsMotion.curve,
          child: Opacity(
            opacity: _enabled || widget.loading ? 1 : 0.5,
            child: Container(
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.x4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                gradient: gradient,
                border: border,
                borderRadius: DsRadius.smallAll,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_fab.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';

/// 52 dp gradient circle. The only shadowed element in the system.
class DsFab extends StatelessWidget {
  const DsFab({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: ds.accentGradient,
          boxShadow: [BoxShadow(color: ds.accentSolid.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: ds.textOnShell, size: 26),
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// Root-navigator sheet with a drag handle. Items must pop with the
/// [sheetContext] they receive, never the caller's context.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required List<Widget> Function(BuildContext sheetContext) builder,
}) {
  final ds = context.ds;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: ds.textPrimary.withOpacity(0.45),
    backgroundColor: ds.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.large))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.x2, bottom: DsSpace.x1),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: ds.borderSubtle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          ...builder(sheetContext),
          const SizedBox(height: DsSpace.x2),
        ],
      ),
    ),
  );
}
```

`lib/core/design/widgets/ds_banner.dart`:

```dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

enum DsBannerKind { success, warning, danger, info }

/// Queued top banners: each shows for 2.5 s, then the next one plays.
void showDsBanner(BuildContext context, String message, {DsBannerKind kind = DsBannerKind.info}) {
  _DsBannerQueue.instance.enqueue(Overlay.of(context, rootOverlay: true), message, kind);
}

class _DsBannerQueue {
  _DsBannerQueue._();
  static final instance = _DsBannerQueue._();

  final Queue<(OverlayState, String, DsBannerKind)> _pending = Queue();
  bool _showing = false;

  void enqueue(OverlayState overlay, String message, DsBannerKind kind) {
    _pending.add((overlay, message, kind));
    _next();
  }

  void _next() {
    if (_showing || _pending.isEmpty) return;
    final (overlay, message, kind) = _pending.removeFirst();
    if (!overlay.mounted) return _next();
    _showing = true;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DsBannerView(
        message: message,
        kind: kind,
        onDone: () {
          entry.remove();
          _showing = false;
          _next();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _DsBannerView extends StatefulWidget {
  const _DsBannerView({required this.message, required this.kind, required this.onDone});

  final String message;
  final DsBannerKind kind;
  final VoidCallback onDone;

  @override
  State<_DsBannerView> createState() => _DsBannerViewState();
}

class _DsBannerViewState extends State<_DsBannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DsMotion.base);
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismiss = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final (color, icon) = switch (widget.kind) {
      DsBannerKind.success => (ds.success, Icons.check_circle_outline),
      DsBannerKind.warning => (ds.warning, Icons.warning_amber_outlined),
      DsBannerKind.danger => (ds.danger, Icons.error_outline),
      DsBannerKind.info => (ds.shellRaised, Icons.info_outline),
    };
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: DsMotion.curve)),
        child: Material(
          color: color,
          child: Padding(
            padding: EdgeInsets.fromLTRB(DsSpace.gutter, top + DsSpace.x3, DsSpace.gutter, DsSpace.x3),
            child: Row(
              children: [
                Icon(icon, color: ds.textOnShell, size: 20),
                const SizedBox(width: DsSpace.x3),
                Expanded(child: Text(widget.message, style: context.dsType.body.withColor(ds.textOnShell))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/core/design/widgets/ds_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/design/widgets/ds_button.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Confirmation dialog. Resolves true when confirmed.
Future<bool> showDsDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final ds = ctx.ds;
      final type = ctx.dsType;
      final l10n = ctx.l10n;
      final confirm = confirmLabel ?? l10n.commonConfirm;
      return Dialog(
        backgroundColor: ds.card,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.largeAll),
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: type.heading),
              if (body != null) ...[
                const SizedBox(height: DsSpace.x2),
                Text(body, style: type.body.withColor(ds.textSecondary)),
              ],
              const SizedBox(height: DsSpace.x5),
              Row(
                children: [
                  Expanded(child: DsButton.secondary(label: l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop(false))),
                  const SizedBox(width: DsSpace.x3),
                  Expanded(
                    child: destructive
                        ? DsButton.destructive(label: confirm, onPressed: () => Navigator.of(ctx).pop(true))
                        : DsButton.primary(label: confirm, onPressed: () => Navigator.of(ctx).pop(true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
```

`lib/core/design/widgets/module_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/design/widgets/ds_card.dart';
import 'package:hms_uploader/core/design/widgets/ds_icon_tile.dart';

/// Dashboard tile for one module.
class ModuleCard extends StatefulWidget {
  const ModuleCard({super.key, required this.icon, required this.title, required this.subtitle, this.badge, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: DsMotion.of(context, DsMotion.fast),
        curve: DsMotion.curve,
        child: DsCard(
          onTap: widget.onTap,
          padding: const EdgeInsets.all(DsSpace.x3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  DsIconTile(icon: widget.icon),
                  const Spacer(),
                  if (widget.badge != null) widget.badge!,
                ],
              ),
              const SizedBox(height: DsSpace.x3),
              Text(widget.title, style: type.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(widget.subtitle, style: type.label.withColor(ds.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed tile shown while only one module is registered.
class ModulePlaceholderCard extends StatelessWidget {
  const ModulePlaceholderCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return CustomPaint(
      painter: _DashedBorderPainter(color: ds.borderSubtle, radius: DsRadius.medium),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.x3),
          child: Text(label, style: context.dsType.label.withColor(ds.textSecondary), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}
```

`lib/core/design/transitions/fade_through_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';

/// Fade-through: the incoming page fades in and rises 8 dp; the outgoing
/// page fades out. Collapses to a plain fade under reduced motion.
class FadeThroughPage<T> extends Page<T> {
  const FadeThroughPage({required this.child, super.key, super.name, super.arguments});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: DsMotion.of(context, DsMotion.base),
      reverseTransitionDuration: DsMotion.of(context, DsMotion.fast),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (context, animation, secondary, child) {
        final reduce = MediaQuery.disableAnimationsOf(context);
        final fade = CurvedAnimation(parent: animation, curve: DsMotion.curve);
        final rise = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: DsMotion.curve));
        final out = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: secondary, curve: Curves.easeIn));
        Widget result = FadeTransition(opacity: fade, child: child);
        if (!reduce) result = SlideTransition(position: rise, child: result);
        return FadeTransition(opacity: out, child: result);
      },
    );
  }
}
```

Add exports to `design.dart`: `widgets/ds_text_field.dart`, `widgets/ds_button.dart`, `widgets/ds_fab.dart`, `widgets/ds_sheet.dart`, `widgets/ds_banner.dart`, `widgets/ds_dialog.dart`, `widgets/module_card.dart`, `transitions/fade_through_page.dart`.

- [ ] **Step 5: Verify and commit**

```bash
flutter gen-l10n && flutter test test/core && flutter analyze
git add -A && git commit -m "feat(design): kit part 2 (field, button, fab, sheet, queued banner, dialog, module card, transition)"
```

---

### Task 4: Module registry, dashboard feature, router and shell

**Files:**
- Create: `lib/core/modules/app_module.dart`, `lib/app/modules.dart`, `lib/features/dashboard/dashboard.dart`, `lib/features/dashboard/application/connection_status_controller.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart`, `lib/features/dashboard/presentation/widgets/context_strip.dart`
- Modify: `lib/core/utils/jwt.dart` (add `jwtClaim`), `lib/features/tomogram/tomogram.dart` (export `tomogramModule`, nest routes under the entry), `lib/features/patient_lookup/patient_lookup.dart` (`patientLookupRoute` replaces `homeRoute`), `lib/app/router.dart`, `lib/app/app_shell.dart`, `lib/core/l10n/app_en.arb`
- Delete: `lib/app/tab_bar.dart`
- Test: `test/core/utils/jwt_test.dart` (add claim test), `test/features/dashboard/dashboard_screen_test.dart`, `test/app/app_gate_test.dart` (update paths, add module navigation test), `test/app/redirect_test.dart` (paths), `test/features/patient_lookup/home_screen_test.dart` (rename to `patient_lookup_screen_test.dart` if the screen is renamed; see below)

**Interfaces:**
- Produces:
  - `class AppModule { id, title(l10n), subtitle(l10n), icon, entryRoute, routes, badge }` as in the spec.
  - `final List<AppModule> appModules` in `lib/app/modules.dart`.
  - `String? jwtClaim(String token, String claim)`.
  - `connectionStatusProvider = AsyncNotifierProvider<ConnectionStatusController, bool>` (true when the last health check succeeded; `build` performs one check against the configured URL).
  - `GoRoute dashboardRoute({required List<RouteBase> children})` at `RoutePaths.dashboard`.
  - `GoRoute patientLookupRoute({required List<RouteBase> children})` at `RoutePaths.tomogramEntry` (the former `homeRoute`; screen class renamed `PatientLookupScreen`, file `patient_lookup_screen.dart`).
  - `final AppModule tomogramModule` whose `routes` = `[patientLookupRoute(children: [tomogramDetailRoute, permissionRoute])]`.
  - ARB keys: `dashboardModules` "Modules", `dashboardMorePlaceholder` "More modules coming", `dashboardConnected` "Connected", `dashboardUnreachable` "Server unreachable", `tomogramModuleTitle` "Tomogram", `tomogramModuleSubtitle` "Upload skin photos to a patient record", `tomogramRecentBadge` "{count} recent" with int placeholder, `settingsTabHome` stays "Home".

- [ ] **Step 1: Failing tests**

Add to `test/core/utils/jwt_test.dart`:

```dart
  test('jwtClaim reads a string claim', () {
    final t = _token({'exp': 1, 'username': 'System', 'user_id': 2});
    expect(jwtClaim(t, 'username'), 'System');
    expect(jwtClaim(t, 'user_id'), '2');
    expect(jwtClaim(t, 'missing'), isNull);
    expect(jwtClaim('garbage', 'username'), isNull);
  });
```

`test/features/dashboard/dashboard_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/dashboard/dashboard.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

AppModule fakeModule(String id, String title) => AppModule(
      id: id,
      title: (_) => title,
      subtitle: (_) => 'sub',
      icon: Icons.extension,
      entryRoute: '/app/$id',
      routes: const [],
    );

void main() {
  late SharedPreferences prefs;
  late MockHealthCheckApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://cutis.decare.team'});
    prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    when(() => api.check(any())).thenAnswer((_) async {});
  });

  testWidgets('renders a card per module plus placeholder when only one', (tester) async {
    await pumpApp(tester, DashboardScreen(modules: [fakeModule('a', 'Alpha')]), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('More modules coming'), findsOneWidget);
    expect(find.text('cutis.decare.team'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('no placeholder with two modules; unreachable server shows warning text', (tester) async {
    when(() => api.check(any())).thenThrow(Exception('down'));
    await pumpApp(tester, DashboardScreen(modules: [fakeModule('a', 'Alpha'), fakeModule('b', 'Beta')]), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsNWidgets(2));
    expect(find.byType(ModulePlaceholderCard), findsNothing);
    expect(find.text('Server unreachable'), findsOneWidget);
  });
}
```

Update `test/app/app_gate_test.dart` expectations: the valid-session case now lands on the dashboard (`find.text('Modules')`, `find.byType(ModuleCard)`), and add:

```dart
  testWidgets('tapping the Tomogram module opens the patient lookup', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomogram').first);
    await tester.pumpAndSettle();
    expect(find.text('Enter OP Number'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
  });
```

The `containerWith` helper needs `healthCheckApiProvider.overrideWithValue(...)` with a mock that succeeds, since the dashboard triggers a health check.

Update `test/app/redirect_test.dart` to use `RoutePaths.dashboard` where it used `RoutePaths.home` (same value, no behaviour change) and `RoutePaths.tomogram(4)` (now `/app/tomogram/4`).

- [ ] **Step 2: Run, expect failures**

```bash
flutter test test/features/dashboard test/app test/core/utils
```

- [ ] **Step 3: Implement**

Append to `lib/core/utils/jwt.dart`:

```dart
/// Read a claim from the JWT payload as a string, or null.
String? jwtClaim(String token, String claim) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final map = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (map is! Map) return null;
    final value = map[claim];
    return value?.toString();
  } on FormatException {
    return null;
  }
}
```

`lib/core/modules/app_module.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';

/// Describes one workflow module. Features export one of these; the app
/// registers them in `lib/app/modules.dart`.
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entryRoute,
    required this.routes,
    this.badge,
  });

  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final IconData icon;
  final String entryRoute;

  /// Routes nested under the Home tab branch.
  final List<RouteBase> routes;

  /// Optional live badge for the dashboard card.
  final Widget Function(WidgetRef ref)? badge;
}
```

`lib/features/dashboard/application/connection_status_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// True when the configured server answered the health check this session.
class ConnectionStatusController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    if (url == null) return false;
    try {
      await ref.read(healthCheckApiProvider).check(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final connectionStatusProvider =
    AsyncNotifierProvider<ConnectionStatusController, bool>(ConnectionStatusController.new);
```

`lib/features/dashboard/presentation/widgets/context_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/utils/jwt.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/dashboard/application/connection_status_controller.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// Navy strip under the app bar: server host, username, connection dot.
class ContextStrip extends ConsumerWidget {
  const ContextStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    final host = url == null ? '' : (Uri.tryParse(url)?.host ?? url);
    final token = ref.watch(sessionControllerProvider).valueOrNull?.accessToken;
    final user = token == null ? null : jwtClaim(token, 'username');
    final status = ref.watch(connectionStatusProvider);
    final ok = status.valueOrNull ?? true;

    return Container(
      width: double.infinity,
      color: ds.shell,
      padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x2, DsSpace.gutter, DsSpace.x4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host, style: type.mono.withColor(ds.textOnShell), overflow: TextOverflow.ellipsis),
                if (user != null) Text(user, style: type.label.withColor(ds.textOnShellMuted)),
              ],
            ),
          ),
          DsStatusDot(ok: ok),
          const SizedBox(width: DsSpace.x2),
          Text(ok ? l10n.dashboardConnected : l10n.dashboardUnreachable,
              style: type.label.withColor(ds.textOnShellMuted)),
        ],
      ),
    );
  }
}
```

`lib/features/dashboard/presentation/dashboard_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/dashboard/presentation/widgets/context_strip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.modules, this.onOpenModule});

  final List<AppModule> modules;

  /// Defaults to `context.go(entryRoute)`. Injectable for tests.
  final void Function(BuildContext context, AppModule module)? onOpenModule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.dsType;
    final open = onOpenModule ?? (ctx, m) => ctx.push(m.entryRoute);
    return Scaffold(
      appBar: DsAppBar(title: l10n.appTitle, automaticallyImplyLeading: false),
      body: Column(
        children: [
          const ContextStrip(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(DsSpace.gutter),
              children: [
                Text(l10n.dashboardModules, style: type.heading),
                const SizedBox(height: DsSpace.x3),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: DsSpace.x3,
                  crossAxisSpacing: DsSpace.x3,
                  childAspectRatio: 1.15,
                  children: [
                    for (final m in modules)
                      _Staggered(
                        index: modules.indexOf(m),
                        child: ModuleCard(
                          icon: m.icon,
                          title: m.title(l10n),
                          subtitle: m.subtitle(l10n),
                          badge: m.badge?.call(ref),
                          onTap: () => open(context, m),
                        ),
                      ),
                    if (modules.length == 1) ModulePlaceholderCard(label: l10n.dashboardMorePlaceholder),
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

/// Fades and rises a child in, delayed by its index. Runs once per mount.
class _Staggered extends StatefulWidget {
  const _Staggered({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: DsMotion.base);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(DsMotion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: DsMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}
```

`lib/features/dashboard/dashboard.dart`:

```dart
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/features/dashboard/presentation/dashboard_screen.dart';

export 'application/connection_status_controller.dart';
export 'presentation/dashboard_screen.dart';

GoRoute dashboardRoute({required List<AppModule> modules}) => GoRoute(
      path: RoutePaths.dashboard,
      builder: (context, state) => DashboardScreen(modules: modules),
    );
```

Patient lookup: rename `home_screen.dart` to `patient_lookup_screen.dart` and the class to `PatientLookupScreen` (constructor unchanged: `onPatientSelected`). In the barrel replace `homeRoute` with:

```dart
GoRoute patientLookupRoute({required List<RouteBase> children}) => GoRoute(
      path: RoutePaths.tomogramEntry,
      builder: (context, state) => PatientLookupScreen(
        onPatientSelected: (patient) => context.push(RoutePaths.tomogram(patient.opid), extra: patient),
      ),
      routes: children,
    );
```

Rename its test file to `patient_lookup_screen_test.dart` and the widget references accordingly (behaviour unchanged in this task; Task 6 restyles it).

Tomogram barrel `lib/features/tomogram/tomogram.dart`: keep `tomogramRoutes` content but rename the two routes `tomogramDetailRoute` (path `RoutePaths.tomogramPattern`, i.e. `':opid'`) and `permissionRoute`, and add:

```dart
final AppModule tomogramModule = AppModule(
  id: 'tomogram',
  title: (l10n) => l10n.tomogramModuleTitle,
  subtitle: (l10n) => l10n.tomogramModuleSubtitle,
  icon: Icons.photo_camera_back_outlined,
  entryRoute: RoutePaths.tomogramEntry,
  routes: [patientLookupRoute(children: [tomogramDetailRoute, permissionRoute])],
  badge: (ref) {
    final count = ref.watch(recentSearchesControllerProvider).length;
    return count == 0 ? const SizedBox.shrink() : DsChip(text: '$count', mono: true);
  },
);
```

(`patientLookupRoute` and `recentSearchesControllerProvider` come from the `patient_lookup` barrel, which tomogram already imports.)

`lib/app/modules.dart`:

```dart
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// Registered workflow modules, in dashboard order. Add new modules here.
final List<AppModule> appModules = [tomogramModule];
```

`lib/app/router.dart`: replace the Home branch with

```dart
StatefulShellBranch(routes: [
  dashboardRoute(modules: appModules),
  for (final m in appModules) ...m.routes,
]),
```

and wrap every `GoRoute.builder` into `pageBuilder` using `FadeThroughPage` by passing `pageBuilder: (context, state) => FadeThroughPage(key: state.pageKey, child: ...)` in the feature barrels (configure, login, dashboard, patient lookup, tomogram detail, permission, settings, about). Keep `redirect`, `refreshListenable`, `initialLocation: RoutePaths.dashboard`.

`lib/app/app_shell.dart`: replace `AppTabBar` with `DsBottomBar` (destinations `Icons.home_outlined` + `l10n.settingsTabHome`, `Icons.settings_outlined` + `l10n.settingsTabSettings`), keep the back-press handling and `HideWithKeyboard`. Delete `lib/app/tab_bar.dart`.

ARB: add the keys listed in Interfaces; run `flutter gen-l10n`.

- [ ] **Step 4: Verify and commit**

```bash
flutter test && flutter analyze
git add -A && git commit -m "feat(app): module registry, dashboard, routes under /app/tomogram, DS shell"
```

---

### Task 5: Onboarding screens (Configure URL, Login)

**Files:**
- Create: `lib/core/design/widgets/ds_onboarding_scaffold.dart`
- Modify: `lib/features/server_config/presentation/configure_url_screen.dart`, `lib/features/auth/presentation/login_screen.dart`, `lib/core/l10n/app_en.arb`, `lib/core/design/design.dart`
- Test: `test/features/server_config/configure_url_screen_test.dart`, `test/features/auth/login_screen_test.dart` (update copy and finders)

**Interfaces:**
- Produces: `DsOnboardingScaffold({required Widget card})` — navy upper area with the circle logo (72 dp SVG) and app title in `display` on white, then a `card` panel with top radius 24 that slides up over `slow` on first build; the panel scrolls with the keyboard.
- ARB: `configureUrlHeading` "Connect to your server", `loginHeading` "Sign in", `loginChangeUrl` becomes "Change server", `configureUrlInvalidField` "Enter a valid server address".
- Behaviour unchanged: same controllers, same banners, same `ExitOnDoubleBack` wrapper on both screens, same `context.go(RoutePaths.login)` after a successful connect, same `context.push(RoutePaths.configure)` from the login link.

- [ ] **Step 1: Update tests first**

In `configure_url_screen_test.dart`: expect `find.text('Connect to your server')` instead of `'Installation URL'`; after entering an invalid URL also expect `find.text('Enter a valid server address')` (field error) in addition to the banner. In `login_screen_test.dart`: the "Change URL" text becomes `'Change server'`; the two `TextField`s are still found by `find.byType(TextField).at(0/1)`; add `expect(find.text('decare.team'), findsOneWidget)` after overriding prefs with `{'server_url': 'http://decare.team'}` (login shows the host chip). Run them; expect failure.

- [ ] **Step 2: Implement the scaffold**

`lib/core/design/widgets/ds_onboarding_scaffold.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Navy brand area on top, white card rising from below. Shared by the
/// Configure URL and Login screens so they read as one flow.
class DsOnboardingScaffold extends StatefulWidget {
  const DsOnboardingScaffold({super.key, required this.card});

  final Widget card;

  @override
  State<DsOnboardingScaffold> createState() => _DsOnboardingScaffoldState();
}

class _DsOnboardingScaffoldState extends State<DsOnboardingScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: DsMotion.slow)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final curved = CurvedAnimation(parent: _c, curve: DsMotion.curve);
    return Scaffold(
      backgroundColor: ds.shell,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.x8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/images/hms_circle.svg', width: 72, height: 72),
                  const SizedBox(width: DsSpace.x4),
                  Text(context.l10n.appTitle, style: type.display.withColor(ds.textOnShell)),
                ],
              ),
            ),
            Expanded(
              child: SlideTransition(
                position: reduce
                    ? const AlwaysStoppedAnimation(Offset.zero)
                    : Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
                child: FadeTransition(
                  opacity: reduce ? const AlwaysStoppedAnimation(1) : curved,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ds.card,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(DsRadius.sheet)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.x6, DsSpace.x6, DsSpace.x6, DsSpace.x8),
                      child: widget.card,
                    ),
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

Export it from `design.dart`.

- [ ] **Step 3: Rebuild Configure URL**

Replace the `build` of `_ConfigureUrlScreenState` (keep `_controller`, `_connect`, the `ref.listen` block and the `ExitOnDoubleBack` wrapper). Add a `String? _fieldError` state set to `l10n.configureUrlInvalidField` when the listener sees `InvalidServerUrlException`, cleared on change:

```dart
    return ExitOnDoubleBack(
      child: DsOnboardingScaffold(
        card: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.configureUrlHeading, style: context.dsType.heading),
            const SizedBox(height: DsSpace.x1),
            Text(l10n.configureUrlBody, style: context.dsType.body.withColor(context.ds.textSecondary)),
            const SizedBox(height: DsSpace.x5),
            DsTextField(
              controller: _controller,
              hint: l10n.configureUrlPlaceholder,
              errorText: _fieldError,
              prefix: const Icon(Icons.link, size: 20),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onChanged: (_) => setState(() => _fieldError = null),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: DsSpace.x4),
            DsButton.primary(label: l10n.configureUrlConnect, loading: connecting, onPressed: _connect),
          ],
        ),
      ),
    );
```

Banners: replace `showFlash(...)` with `showDsBanner(context, ..., kind: DsBannerKind.warning/danger)`. The illustration image is no longer shown on this screen.

- [ ] **Step 4: Rebuild Login**

Same pattern. Card content: a `DsChip(text: host, mono: true)` where `host = Uri.tryParse(ref.watch(serverConfigControllerProvider).valueOrNull ?? '')?.host ?? ''` (only when non-empty), `Text(l10n.loginHeading, heading)`, username `DsTextField(label: l10n.loginUsername, textInputAction: next, autofocus: false)`, password `DsTextField(label: l10n.loginPassword, obscureText: _obscure, suffix: IconButton(visibility toggle), onSubmitted: _signIn)`, `DsButton.primary(label: l10n.loginSignIn, loading: signingIn, onPressed: _signIn)`, then `Center(child: DsButton.ghost(label: l10n.loginChangeUrl, onPressed: () => context.push(RoutePaths.configure)))`. Banners via `showDsBanner(..., kind: DsBannerKind.danger)`. Remove the old logo row (the scaffold shows the brand).

- [ ] **Step 5: Verify and commit**

```bash
flutter gen-l10n && flutter test && flutter analyze
git add -A && git commit -m "feat(ui): onboarding scaffold; Configure URL and Login on the design system"
```

---

### Task 6: Patient lookup, Tomogram and Permission screens

**Files:**
- Modify: `lib/features/patient_lookup/presentation/patient_lookup_screen.dart`, `widgets/op_search_bar.dart`, `widgets/recent_search_row.dart` (delete; use `DsListRow`), `widgets/home_empty_state.dart` (use `DsEmptyState`), `lib/features/tomogram/presentation/tomogram_screen.dart`, `widgets/tomogram_card.dart`, `widgets/patient_bar.dart` (delete), `widgets/add_source_sheet.dart`, `widgets/tomogram_empty_state.dart`, `permission_screen.dart`, `lib/core/l10n/app_en.arb`
- Test: `test/features/patient_lookup/patient_lookup_screen_test.dart`, `test/features/tomogram/tomogram_screen_test.dart`, `test/features/tomogram/permission_screen_test.dart`

**Interfaces / behaviour changes (from the spec):**
- Lookup screen: app bar "Tomogram" (`l10n.tomogramModuleTitle`) with back arrow; search bar with a gradient "Go" button (`l10n.homeGo` "Go") shown only with text (replaces the check icon; tests tap `find.text('Go')`); "Recent" heading (`l10n.homeRecent` "Recent") with ghost "Clear" (`l10n.homeClear` "Clear", replacing "clear all"); rows are `DsListRow(leadingIcon: Icons.person_outline, title: name, trailingValue: '$opid', trailingIcon: Icons.delete_outline)` inside a `Dismissible` keyed by patient id; skeleton rows while loading (no `LoaderModal`) — superseded 2026-09-10: no skeletons here, the list stays on screen with an inert, spinning row and reorders on return; empty state through `DsEmptyState` with the existing SVG.
- Tomogram screen: `DsAppBar(title: patient.name, titleTrailing: DsChip('$opid', mono, onShell), onBack: _back, actions: [DsButton.ghost('Upload')] when drafts exist)`. `_back`: if drafts exist, `showDsDialog(title: l10n.tomogramDiscardTitle "Discard photos?", body: l10n.tomogramDiscardBody "The photos you added will be removed.", confirmLabel: l10n.commonDiscard, destructive: true)` then `clearAll()` and pop; else pop. Also wrap the screen body in `PopScope(canPop: drafts.isEmpty, onPopInvoked: (didPop) { if (!didPop) _back(); })`. `DsProgressBar` under the app bar while uploading (`Column` with the bar then the content). `DsFab(icon: Icons.add)` positioned bottom-right via `Scaffold.floatingActionButton`. Draft card: `DsCard` with `ClipRRect(radius small, AspectRatio(16/10, Image.file(cacheWidth: 1080, errorBuilder)))`, a positioned `DsChip('${index + 1} of $total', mono)` at top-left inside the image, a destructive `IconButton(Icons.delete_outline)` top-right, then `DsTextField(label: l10n.tomogramDescription, maxLines: 3, maxLength: 200, showCounter: true)`. Remove `PatientBar` and the footer OP field; the `Op Number` ARB key becomes unused (Task 8 removes it). Banners via `showDsBanner` (success on upload, warning for JPEG/limit, danger on failure). Keep `onPermissionsDenied`.
- Add-source sheet: `showDsSheet` with `DsListRow(leadingIcon: Icons.photo_library_outlined, title: gallery)`, `DsListRow(leadingIcon: Icons.photo_camera_outlined, title: camera)`, then a `DsButton.ghost(label: cancel)`.
- Permission screen: `Scaffold(appBar: DsAppBar(title: l10n.commonHeader))`, body centred column: `DsIconTile(icon: Icons.lock_outline, size: 56)`, heading, body (secondary), `DsButton.primary(label: l10n.permissionGrant, onPressed: openSettings)`.
- Tests: update finders (`'Go'`, `'Clear'`, `'Recent'`, dialog text `'Discard photos?'`), keep all behavioural assertions (lookup success/failure, upload success/failure, JPEG and limit banners, denied permission). Add: back with drafts shows the discard dialog; confirming clears the card.

- [ ] **Step 1: Update the three test files first, run, expect failures**
- [ ] **Step 2: Implement the lookup screen**

`patient_lookup_screen.dart` body sketch (keep `_lookup`, `ref.listen` for errors with `showDsBanner(..., kind: DsBannerKind.danger)`):

```dart
    return Scaffold(
      appBar: DsAppBar(title: l10n.tomogramModuleTitle),
      body: Column(
        children: [
          OpSearchBar(onSubmit: _lookup),
          Expanded(
            child: loading
                ? ListView(children: [DsSkeleton.row(), DsSkeleton.row(), DsSkeleton.row()])
                : recents.isEmpty
                    ? DsEmptyState(
                        illustration: SvgPicture.asset('assets/images/blank_canvas.svg'),
                        heading: l10n.homeEmptyTitle,
                        body: l10n.homeEmptyBody,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.gutter, 0, DsSpace.gutter, DsSpace.x8),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.homeRecent, style: type.heading),
                              DsButton.ghost(label: l10n.homeClear, onPressed: () => ref.read(recentSearchesControllerProvider.notifier).clear()),
                            ],
                          ),
                          const SizedBox(height: DsSpace.x2),
                          DsCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final p in recents) ...[
                                  Dismissible(
                                    key: ValueKey('recent-${p.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(color: ds.danger, alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: DsSpace.x4),
                                        child: Icon(Icons.delete_outline, color: ds.textOnShell)),
                                    onDismissed: (_) => ref.read(recentSearchesControllerProvider.notifier).remove(p.id),
                                    child: DsListRow(
                                      leadingIcon: Icons.person_outline,
                                      title: p.name,
                                      trailingValue: '${p.opid}',
                                      trailingIcon: Icons.delete_outline,
                                      onTrailingTap: () => ref.read(recentSearchesControllerProvider.notifier).remove(p.id),
                                      onTap: () => _lookup(p.opid),
                                    ),
                                  ),
                                  if (p != recents.last) Divider(height: 1, color: ds.borderSubtle),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
```

`OpSearchBar`: white strip on `ds.card` with bottom border, padding gutter; `Row([Expanded(DsTextField(mono: true, hint: l10n.homeSearchPlaceholder, keyboardType number, digitsOnly, maxLength 7, textInputAction search, prefix: Icon(Icons.search), suffix: clear button when hasText, onSubmitted)), if (hasText) SizedBox(width x2), DsButton.primary(label: l10n.homeGo, expand: false, height: 40, onPressed: _submit)])`. Remove `ExitOnDoubleBack` from this screen (the shell owns back).

- [ ] **Step 3: Implement Tomogram, card, sheet, permission** per the interfaces above.
- [ ] **Step 4: ARB** add `homeGo`, `homeRecent`, `homeClear`, `tomogramDiscardTitle`, `tomogramDiscardBody`, `tomogramCounter` "{index} of {total}" (two int placeholders); run `flutter gen-l10n`.
- [ ] **Step 5: Verify and commit**

```bash
flutter test && flutter analyze
git add -A && git commit -m "feat(ui): patient lookup, tomogram and permission screens on the design system"
```

---

### Task 7: Settings and About

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`, `about_screen.dart`, `widgets/settings_row.dart` (delete; use `DsListRow`), `lib/features/settings/settings.dart` (FadeThroughPage already applied in Task 4), `lib/core/l10n/app_en.arb`, `lib/main.dart` (no change needed; `package_info_plus` is read lazily)
- Create: `lib/features/settings/application/app_version_provider.dart`
- Test: `test/features/settings/settings_screen_test.dart`, `about_screen_test.dart`

**Interfaces / behaviour:**
- `appVersionProvider = FutureProvider<String>` returning `'v${info.version} (${info.buildNumber})'` via `PackageInfo.fromPlatform()`; tests override it with `AsyncValue.data('v1.0.0 (1)')`.
- Settings: `DsAppBar(title: l10n.settingsTabSettings, automaticallyImplyLeading: false)`. Body `ListView(padding gutter)` with three groups, each a `Text(groupTitle, label secondary)` then a `DsCard(padding: zero)` of rows:
  - Server (`settingsGroupServer` "Server"): `DsListRow(leadingIcon: Icons.dns_outlined, title: l10n.settingsChangeUrl, trailingValue: host, chevron: true, onTap: _changeUrl)`. `_changeUrl` uses `showDsDialog(title: l10n.settingsChangeUrl, body: l10n.settingsChangeUrlBody, destructive: true, confirmLabel: l10n.commonConfirm)` then the existing reset+logout order.
  - Account (`settingsGroupAccount` "Account"): `DsListRow(leadingIcon: Icons.person_outline, title: username from jwtClaim or '—')`, `DsListRow(leadingIcon: Icons.logout, title: l10n.settingsSignOut "Sign out", destructive: true, onTap: _logout)` with `showDsDialog(title: l10n.settingsSignOutTitle "Sign out?", body: l10n.settingsSignOutBody "You will need to sign in again.", destructive: true, confirmLabel: l10n.settingsSignOut)`.
  - Help (`settingsGroupHelp` "Help"): `DsListRow(leadingIcon: Icons.info_outline, title: l10n.settingsAbout, chevron: true, onTap: onAbout ?? push about)`.
  - Footer: `Center(Text(version, label secondary))` using `ref.watch(appVersionProvider).valueOrNull ?? ''`.
- About: `DsAppBar(title: l10n.aboutHeader)` (back arrow implied). Body `ListView` of `DsCard`s: logo card (image height 96 + copyright label), Terms card (heading + body), About Us card (heading + three paragraphs), Contact card (heading + paragraph + `Row` of two `DsButton.ghost` with phone and website). The custom `_back` with the "Can't go back" banner is dropped: the app bar's implied back handles it and the screen is only reachable by push.
- Tests: settings test taps `'Sign out'` then `'Sign out'` in the dialog (confirm label) and checks the secure store; change-URL test taps the row then `'Confirm'`; about test unchanged except header text. Existing `'Logout'` finders become `'Sign out'`; `"No, I'm Not"`/`"Yes, I am"` become `'Cancel'` and the confirm labels.

- [ ] **Step 1: Update tests, run, expect failures**
- [ ] **Step 2: Implement** per the interfaces; `flutter gen-l10n` after adding keys `settingsGroupServer`, `settingsGroupAccount`, `settingsGroupHelp`, `settingsSignOut`, `settingsSignOutTitle`, `settingsSignOutBody`.
- [ ] **Step 3: Verify and commit**

```bash
flutter test && flutter analyze
git add -A && git commit -m "feat(ui): settings groups with version footer; about on cards"
```

---

### Task 8: Remove the old widgets and theme, prune strings, verify on device

**Files:**
- Delete: `lib/core/widgets/app_header.dart`, `app_text_field.dart`, `app_buttons.dart`, `loader_modal.dart`, `confirm_dialog.dart`, `app_bottom_sheet.dart`, `flash_banner.dart`, `lib/core/theme/*` (all four files), `lib/features/patient_lookup/presentation/widgets/recent_search_row.dart`, `home_empty_state.dart`, `lib/features/tomogram/presentation/widgets/patient_bar.dart`, `tomogram_empty_state.dart` (if now unused), `lib/features/settings/presentation/widgets/settings_row.dart`, their tests under `test/core/widgets/` (`app_header_test`, `app_bottom_sheet_test`, `confirm_dialog_test`, `flash_banner_test`), `assets/images/installation_url.png` (no longer shown)
- Keep: `lib/core/widgets/exit_on_double_back.dart`, `keyboard_visibility.dart`, `l10n_ext.dart` (move `l10n_ext.dart` into `lib/core/design/` is NOT required; leave it).
- Modify: `lib/core/l10n/app_en.arb` (remove unused keys: `homeRecentSearches`, `homeClearAll`, `tomogramOpNumber`, `commonConfirmTitle`, `commonConfirmNo`, `commonConfirmYes`, `configureUrlTitle`, `settingsLogout`, `commonCannotGoBack`, `aboutOr` if unused), `pubspec.yaml` assets list, `README.md` (design system section), spec doc note if anything deviated.

- [ ] **Step 1: Delete files, fix imports** (`flutter analyze` reports every dangling import; fix them all).
- [ ] **Step 2: Prune ARB** — for each candidate key run `grep -rn "l10n\.<key>\b" lib` and delete the key only when there are zero hits; `flutter gen-l10n`.
- [ ] **Step 3: README** — add a "Design system" section: tokens live in `lib/core/design/tokens`, widgets in `lib/core/design/widgets`, rule that screens never use raw colours or sizes, and how to register a module (`AppModule` + `lib/app/modules.dart`).
- [ ] **Step 4: Full verification**

```bash
flutter analyze && flutter test && flutter build apk --debug
grep -rn "features/" lib/core && echo VIOLATION || echo "core is clean"
grep -rnE "Color\(0x|Colors\.[a-z]+" lib/features lib/app | grep -v "Colors.transparent" && echo "RAW COLOURS" || echo "no raw colours in screens"
```

- [ ] **Step 5: Emulator walkthrough** (controller runs this, not the implementer): install the APK, screenshot Configure, Login, Dashboard, Lookup (empty and with recents), Tomogram (empty, with a card, discard dialog), Permission, Settings, About, and the sheet and a banner; compare against the spec.
- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore(ui): remove legacy widgets and theme, prune strings, document the design system"
```
