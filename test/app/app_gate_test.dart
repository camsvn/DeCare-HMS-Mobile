import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

String liveToken() {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp})}.s';
}

Future<ProviderContainer> containerWith({String? url, bool session = false}) async {
  SharedPreferences.setMockInitialValues(url == null ? {} : {'server_url': url});
  final prefs = await SharedPreferences.getInstance();
  final store = InMemorySecureStore();
  if (session) {
    await store.write('access_token', 'a');
    await store.write('refresh_token', liveToken());
  }
  // The dashboard's context strip runs one health check on first build.
  final health = MockHealthCheckApi();
  when(() => health.check(any())).thenAnswer((_) async {});
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    healthCheckApiProvider.overrideWithValue(health),
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
  ]);
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);
  return container;
}

void main() {
  testWidgets('starts on configure when no url', (tester) async {
    final c = await containerWith();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Installation URL'), findsOneWidget);
  });

  testWidgets('starts on login when url but no session', (tester) async {
    final c = await containerWith(url: 'http://x');
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('starts on the dashboard when session is valid, and logout returns to login', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
    expect(find.byType(ModuleCard), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Logout'), findsOneWidget);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, I am'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('tapping the Tomogram module opens the patient lookup', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomogram').first);
    await tester.pumpAndSettle();
    expect(find.text('Enter OP Number'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
  });

  testWidgets('system back on the Home tab arms double-press-to-exit', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('App: Press back again to exit'), findsOneWidget);
    // Still on Home: the shell swallowed the pop instead of exiting.
    expect(find.text('Modules'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('system back on the Settings tab returns to the Home tab', (tester) async {
    final c = await containerWith(url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Logout'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);
  });
}
