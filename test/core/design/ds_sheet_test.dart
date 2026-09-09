import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

import '../../helpers/pump_app.dart';

void main() {
  Future<void> pumpOpener(WidgetTester tester, void Function(String?) onResult) async {
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
    );
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
}
