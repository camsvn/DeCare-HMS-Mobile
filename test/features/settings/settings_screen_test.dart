import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

/// A JWT-shaped token (unsigned, unverified) carrying a `username` claim.
String tokenFor(String username) {
  String b64(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'username': username})}.s';
}

void main() {
  late SharedPreferences prefs;
  late InMemorySecureStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://x'});
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
    await store.write('access_token', tokenFor('alice'));
    await store.write('refresh_token', 'r');
  });

  Future<void> pump(WidgetTester tester,
          {void Function()? onAbout, ThemeMode themeMode = ThemeMode.light}) =>
      pumpApp(
        tester,
        SettingsScreen(onAbout: onAbout),
        themeMode: themeMode,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStoreProvider.overrideWithValue(store),
          appVersionProvider.overrideWith((ref) async => 'v1.0.0 (1)'),
        ],
      );

  testWidgets('renders rows and calls onAbout', (tester) async {
    var about = 0;
    await pump(tester, onAbout: () => about++);
    await tester.pumpAndSettle();
    expect(find.text('Change Installation URL'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Signed in as'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('v1.0.0 (1)'), findsOneWidget);
    await tester.tap(find.text('About'));
    expect(about, 1);
  });

  testWidgets('logout asks for confirmation then clears the session',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await store.read('refresh_token'), 'r');
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(await store.read('refresh_token'), isNull);
    expect(prefs.getString('server_url'), 'http://x');
  });

  testWidgets('change URL confirm resets url and session', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change Installation URL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(prefs.getString('server_url'), isNull);
    expect(await store.read('access_token'), isNull);
  });

  testWidgets('the appearance row shows the current theme and the sheet changes it',
      (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    // Nothing stored yet, so the row reads System.
    expect(find.text('System'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    // The sheet is headed "Appearance", so the word is now on screen twice.
    expect(find.text('Appearance'), findsNWidgets(2));
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    // Only the active option is ticked; the tick is labelled but is not a
    // second action.
    expect(find.byIcon(Icons.check), findsOneWidget);
    final tick = tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(Icons.check), matching: find.byType(IconButton)));
    expect(tick.onPressed, isNull);
    expect(tick.tooltip, 'Selected');

    // The active option is announced as selected; the others are not.
    Iterable<bool?> selectedFlags(String label) => tester
        .widgetList<Semantics>(find.ancestor(
          of: find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
          matching: find.byType(Semantics),
        ))
        .map((widget) => widget.properties.selected);
    expect(selectedFlags('System'), contains(true));
    expect(selectedFlags('Dark'), isNot(contains(true)));

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(prefs.getString('appearance'), 'dark');
    // The sheet is gone and the row now reads Dark.
    expect(find.text('Light'), findsNothing);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('renders on the dark palette when the dark theme is active', (tester) async {
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Theme'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(tester.widget<Text>(find.text('Appearance')).style?.color, DsColors.dark.textSecondary);
  });
}
