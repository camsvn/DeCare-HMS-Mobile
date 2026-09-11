import 'dart:ui' show Tristate;

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
    expect(home.flagsCollection.isSelected, Tristate.isTrue);
    final settings = tester.getSemantics(find.text('Settings'));
    expect(settings.flagsCollection.isSelected, isNot(Tristate.isTrue));
  });

  testWidgets('grows for large text without overflowing, and clamps the scale at 1.3', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<double> pumpAt(double scale) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildDsTheme(),
        home: Builder(
          // Keep the ambient size and padding; only the text scale changes.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              bottomNavigationBar: DsBottomBar(
                currentIndex: 0,
                onTap: (_) {},
                destinations: const [
                  DsDestination(icon: Icons.home_outlined, label: 'Home'),
                  DsDestination(icon: Icons.notifications_outlined, label: 'Notifications'),
                ],
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byType(DsBottomBar)).height;
    }

    final base = await pumpAt(1);
    expect(base, DsBottomBar.barHeight);
    final clamped = await pumpAt(1.3);
    expect(clamped, greaterThan(base));
    // Past the clamp the bar stops growing: the shell must not eat the screen.
    expect(await pumpAt(2), clamped);
  });
}
