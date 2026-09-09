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
