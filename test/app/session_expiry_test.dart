import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

String liveToken() {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp})}.s';
}

/// Same wiring as [main], so the expiry path runs against the real providers.
Future<(ProviderContainer, InMemorySecureStore)> containerWith(
    {required Directory docs, String? url, bool session = false}) async {
  SharedPreferences.setMockInitialValues(url == null ? {} : {'server_url': url});
  final prefs = await SharedPreferences.getInstance();
  final store = InMemorySecureStore();
  if (session) {
    await store.write('access_token', 'a');
    await store.write('refresh_token', liveToken());
  }
  final health = MockHealthCheckApi();
  when(() => health.check(any())).thenAnswer((_) async {});
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    healthCheckApiProvider.overrideWithValue(health),
    appDocumentsDirProvider.overrideWithValue(docs),
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
    refreshAccessTokenProvider
        .overrideWith((ref) => () => ref.read(sessionControllerProvider.notifier).refreshAccessToken()),
  ]);
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);
  return (container, store);
}

void main() {
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('expiry_docs'));
  tearDown(() => docs.delete(recursive: true));
  testWidgets('an auth failure signs out, returns to login and warns the user', (tester) async {
    resetDsBannersForTest();
    final (c, store) = await containerWith(docs: docs, url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(await store.read('refresh_token'), isNull);
    expect(await store.read('access_token'), isNull);
    expect(find.text('Session expired, please sign in again'), findsOneWidget);

    // Let the banner's dismiss timer run out before the tree is torn down.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a burst of auth failures signs out once and shows one banner', (tester) async {
    resetDsBannersForTest();
    final (c, store) = await containerWith(docs: docs, url: 'http://x', session: true);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Modules'), findsOneWidget);

    // Three parallel requests all coming back 401.
    c.read(authFailureProvider.notifier).state++;
    c.read(authFailureProvider.notifier).state++;
    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(await store.read('refresh_token'), isNull);
    expect(find.text('Session expired, please sign in again'), findsOneWidget);

    // Banners are queued one at a time, so a second enqueued banner would only
    // show up once the first has been dismissed.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Session expired, please sign in again'), findsNothing);
  });

  testWidgets('an auth failure with no session does nothing', (tester) async {
    resetDsBannersForTest();
    final (c, _) = await containerWith(docs: docs, url: 'http://x');
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);

    c.read(authFailureProvider.notifier).state++;
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Session expired, please sign in again'), findsNothing);
  });
}
