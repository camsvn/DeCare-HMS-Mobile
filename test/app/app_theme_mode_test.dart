import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A signed-in container on the dashboard, with [appearance] already stored.
Future<ProviderContainer> containerWith({required Directory docs, String? appearance}) async {
  SharedPreferences.setMockInitialValues({
    'server_url': 'http://x',
    if (appearance != null) 'appearance': appearance,
  });
  final prefs = await SharedPreferences.getInstance();
  final store = InMemorySecureStore();
  await store.write('access_token', 'a');
  await store.write('refresh_token', liveToken());
  final health = MockHealthCheckApi();
  when(() => health.check(any())).thenAnswer((_) async {});
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    secureStoreProvider.overrideWithValue(store),
    healthCheckApiProvider.overrideWithValue(health),
    appDocumentsDirProvider.overrideWithValue(docs),
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
  ]);
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);
  return container;
}

void main() {
  late Directory docs;

  setUp(() async => docs = await Directory.systemTemp.createTemp('theme_docs'));
  tearDown(() => docs.delete(recursive: true));

  testWidgets('a stored dark appearance paints the screens with the dark palette', (tester) async {
    final c = await containerWith(docs: docs, appearance: 'dark');
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Modules'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.ds.canvas, DsColors.dark.canvas);
  });

  testWidgets('with nothing stored it follows the platform, which is light in tests', (tester) async {
    final c = await containerWith(docs: docs);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const HmsApp()));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Modules'));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(context.ds.canvas, DsColors.light.canvas);
  });

  testWidgets('the status bar takes the resolved palette shell in both modes', (tester) async {
    final dark = await containerWith(docs: docs, appearance: 'dark');
    addTearDown(dark.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: dark, child: const HmsApp()));
    await tester.pumpAndSettle();
    var region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
    expect(region.value.statusBarColor, DsColors.dark.shell);
    expect(region.value.statusBarIconBrightness, Brightness.light);

    final light = await containerWith(docs: docs, appearance: 'light');
    addTearDown(light.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: light, child: const HmsApp()));
    await tester.pumpAndSettle();
    region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
    expect(region.value.statusBarColor, DsColors.light.shell);
    expect(region.value.statusBarIconBrightness, Brightness.light);
  });
}
