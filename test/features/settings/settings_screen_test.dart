import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;
  late InMemorySecureStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://x'});
    prefs = await SharedPreferences.getInstance();
    store = InMemorySecureStore();
    await store.write('access_token', 'a');
    await store.write('refresh_token', 'r');
  });

  Future<void> pump(WidgetTester tester, {void Function()? onAbout}) => pumpApp(
        tester,
        SettingsScreen(onAbout: onAbout),
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
}
