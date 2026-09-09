import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    final settings = tester.getSemantics(find.text('Settings'));
    expect(settings.hasFlag(SemanticsFlag.isSelected), isFalse);
  });
}
