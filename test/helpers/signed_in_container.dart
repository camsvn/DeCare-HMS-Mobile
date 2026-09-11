import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

/// A JWT-shaped token (unsigned, unverified) that is still well inside its
/// expiry, so the session gate treats it as valid.
String liveToken() {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp})}.s';
}

/// A container wired like `main`, so widget tests drive the real providers.
///
/// [url] is the stored server URL; pass null for an unconfigured install.
/// [session] seeds a live token pair, [extraPrefs] any other stored keys. The
/// dashboard's context strip runs one health check on first build, so the
/// health API is always mocked to succeed.
///
/// [overrides] join the container's own, for a test that drives the real app
/// and still needs one service faked (the camera, say). They belong here
/// rather than in a nested `ProviderScope`: a provider that is not itself
/// overridden is attached to the root container, so a nested override would be
/// invisible to the providers that read it.
Future<({ProviderContainer container, InMemorySecureStore store})> signedInContainer({
  required Directory docs,
  String? url = 'http://x',
  bool session = true,
  Map<String, Object> extraPrefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': ?url,
    ...extraPrefs,
  });
  final prefs = await SharedPreferences.getInstance();
  final store = InMemorySecureStore();
  if (session) {
    await store.write('access_token', 'a');
    await store.write('refresh_token', liveToken());
  }
  final health = MockHealthCheckApi();
  when(() => health.check(any())).thenAnswer((_) async {});
  final container = ProviderContainer(retry: noRetry, overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    healthCheckApiProvider.overrideWithValue(health),
    appDocumentsDirProvider.overrideWithValue(docs),
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).value),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).value?.accessToken),
    refreshAccessTokenProvider
        .overrideWith((ref) => () => ref.read(sessionControllerProvider.notifier).refreshAccessToken()),
    ...overrides,
  ]);
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);
  return (container: container, store: store);
}
