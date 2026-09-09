import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/design/design.dart';

import '../helpers/signed_in_container.dart';

void main() {
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('theme_docs'));
  tearDown(() => docs.delete(recursive: true));

  /// The dashboard's context, once the app has settled on it.
  BuildContext dashboard(WidgetTester tester) => tester.element(find.text('Modules'));

  SystemUiOverlayStyle overlay(WidgetTester tester) => tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
      .value;

  Future<void> pumpDashboard(WidgetTester tester, {String? appearance}) async {
    final harness = await signedInContainer(
      docs: docs,
      extraPrefs: appearance == null ? const {} : {'appearance': appearance},
    );
    addTearDown(harness.container.dispose);
    await tester.pumpWidget(
        UncontrolledProviderScope(container: harness.container, child: const HmsApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('a stored dark appearance paints the screens with the dark palette', (tester) async {
    await pumpDashboard(tester, appearance: 'dark');

    expect(Theme.of(dashboard(tester)).brightness, Brightness.dark);
    expect(dashboard(tester).ds.canvas, DsColors.dark.canvas);
    expect(overlay(tester).statusBarColor, DsColors.dark.shell);
    expect(overlay(tester).statusBarIconBrightness, Brightness.light);
  });

  testWidgets('a stored light appearance stays light even on a dark platform', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpDashboard(tester, appearance: 'light');

    expect(Theme.of(dashboard(tester)).brightness, Brightness.light);
    expect(dashboard(tester).ds.canvas, DsColors.light.canvas);
    expect(overlay(tester).statusBarColor, DsColors.light.shell);
    expect(overlay(tester).statusBarIconBrightness, Brightness.light);
  });

  testWidgets('with nothing stored it follows the platform, and flips when the platform does',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpDashboard(tester);

    expect(Theme.of(dashboard(tester)).brightness, Brightness.dark);
    expect(dashboard(tester).ds.canvas, DsColors.dark.canvas);
    expect(overlay(tester).statusBarColor, DsColors.dark.shell);
    expect(overlay(tester).statusBarIconBrightness, Brightness.light);

    // The platform switching back repaints the running app.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();

    expect(Theme.of(dashboard(tester)).brightness, Brightness.light);
    expect(dashboard(tester).ds.canvas, DsColors.light.canvas);
    expect(overlay(tester).statusBarColor, DsColors.light.shell);
    expect(overlay(tester).statusBarIconBrightness, Brightness.light);
  });
}
