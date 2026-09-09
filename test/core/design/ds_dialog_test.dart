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

  testWidgets('paints an untinted card surface', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDsDialog(context, title: 'Sign out?'),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first,
    );
    expect(material.surfaceTintColor, Colors.transparent);
    expect(material.color, DsColors.light.card);
  });

  testWidgets('the destructive variant confirms with a destructive button', (tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showDsDialog(
            context,
            title: 'Discard pending upload?',
            confirmLabel: 'Discard',
            destructive: true,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<DsButton>(find.widgetWithText(DsButton, 'Discard'));
    expect(confirm.variant, DsButtonVariant.destructive);
    // Cancel stays the plain secondary button either way.
    expect(tester.widget<DsButton>(find.widgetWithText(DsButton, 'Cancel')).variant, DsButtonVariant.secondary);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
