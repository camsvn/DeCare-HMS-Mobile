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
    // The badge sits over the card and must not swallow its tap: the pointer
    // is meant to miss the badge and land on the card beneath it.
    await tester.tap(find.text('3'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 2);
  });

  testWidgets('the card is one tappable node; the badge keeps its own', (tester) async {
    final handle = tester.ensureSemantics();
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
            onTap: () {},
          ),
        ),
      ),
    ));
    final card = tester.getSemantics(find.text('Tomogram'));
    expect(card.label, contains('Tomogram'));
    expect(card.label, contains('Upload skin photos'));
    // The count is a live value of its own, not part of the card's label.
    expect(card.label, isNot(contains('3')));
    expect(tester.getSemantics(find.text('3')).label, '3');
    handle.dispose();
  });
}
