import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> pumpOpener(
    WidgetTester tester,
    void Function(String?) onResult, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final value = await showDsSheet<String>(
              context,
              builder: (sheetContext) => [
                ListTile(
                  title: const Text('camera'),
                  onTap: () => Navigator.of(sheetContext).pop('camera'),
                ),
                ListTile(
                  title: const Text('gallery'),
                  onTap: () => Navigator.of(sheetContext).pop('gallery'),
                ),
              ],
            );
            onResult(value);
          },
          child: const Text('open'),
        ),
      ),
      themeMode: themeMode,
    );
  }

  /// The colour the sheet's own barrier paints over the screen behind it.
  Color scrimOf(WidgetTester tester) {
    final painted = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .where((barrier) => barrier.color != null)
        .toList();
    expect(painted, isNotEmpty);
    return painted.first.color!;
  }

  testWidgets('returns the tapped item value', (tester) async {
    String? result;
    await pumpOpener(tester, (value) => result = value);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('camera'), findsOneWidget);
    await tester.tap(find.text('gallery'));
    await tester.pumpAndSettle();
    expect(result, 'gallery');
  });

  testWidgets('paints an untinted card surface', (tester) async {
    await pumpOpener(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(BottomSheet), matching: find.byType(Material)).first,
    );
    expect(material.surfaceTintColor, Colors.transparent);
    expect(material.color, DsColors.light.card);
  });

  testWidgets('dims the screen behind it on the light palette', (tester) async {
    await pumpOpener(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final scrim = scrimOf(tester);
    expect(scrim.computeLuminance(), lessThan(0.2));
    expect(scrim.toARGB32(), DsColors.light.scrim.withValues(alpha: 0.45).toARGB32());
  });

  testWidgets('lifts its content clear of the soft keyboard', (tester) async {
    // A sheet used to sit *behind* the keyboard: anything with a field in it
    // put the field, and often the buttons, under the glass.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await pumpOpener(tester, (_) {});
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The last item's bottom clears the keyboard's top edge.
    expect(tester.getRect(find.text('gallery')).bottom, lessThanOrEqualTo(500));
    expect(tester.getRect(find.text('camera')).top, greaterThanOrEqualTo(0));
  });

  testWidgets('a sheet taller than its cap scrolls instead of overflowing', (tester) async {
    // The view, not `setSurfaceSize`: the cap is read off `MediaQuery`, which
    // reports the view's own size rather than the test surface's.
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDsSheet<void>(
            context,
            builder: (_) => [for (var i = 0; i < 20; i++) ListTile(title: Text('row $i'))],
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Capped at 9/16 of the screen, with the rest reachable by scrolling.
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.height, lessThanOrEqualTo(400 * dsSheetMaxHeightFactor + 1));
    final scrollable = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable));
    expect(tester.state<ScrollableState>(scrollable.first).position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('dims — never hazes — the screen behind it on the dark palette', (tester) async {
    await pumpOpener(tester, (_) {}, themeMode: ThemeMode.dark);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The dark palette's textPrimary is near-white; a scrim built from it would
    // lay a haze over the app instead of dimming it.
    final scrim = scrimOf(tester);
    expect(scrim.computeLuminance(), lessThan(0.2));
    expect(scrim.toARGB32(), DsColors.dark.scrim.withValues(alpha: 0.45).toARGB32());
  });
}
