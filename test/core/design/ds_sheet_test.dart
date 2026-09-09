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
    expect(scrim.value, DsColors.light.scrim.withOpacity(0.45).value);
  });

  testWidgets('dims — never hazes — the screen behind it on the dark palette', (tester) async {
    await pumpOpener(tester, (_) {}, themeMode: ThemeMode.dark);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The dark palette's textPrimary is near-white; a scrim built from it would
    // lay a haze over the app instead of dimming it.
    final scrim = scrimOf(tester);
    expect(scrim.computeLuminance(), lessThan(0.2));
    expect(scrim.value, DsColors.dark.scrim.withOpacity(0.45).value);
  });
}
