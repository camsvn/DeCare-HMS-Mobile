import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/network/server_reachability.dart';
import 'package:hms_uploader/core/widgets/server_unreachable_banner.dart';

import '../../helpers/fake_connectivity.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeConnectivityService connectivity;

  setUp(() {
    connectivity = FakeConnectivityService();
    addTearDown(connectivity.close);
  });

  Future<ProviderContainer> pump(WidgetTester tester, {ThemeMode themeMode = ThemeMode.light}) async {
    await pumpApp(
      tester,
      const Scaffold(body: Column(children: [ServerUnreachableBanner()])),
      themeMode: themeMode,
      overrides: [
        serverUrlProvider.overrideWithValue('http://x'),
        accessTokenProvider.overrideWithValue(null),
        refreshAccessTokenProvider.overrideWithValue(() async => null),
        connectivityServiceProvider.overrideWithValue(connectivity),
      ],
    );
    return ProviderScope.containerOf(tester.element(find.byType(ServerUnreachableBanner)));
  }

  const message = "Can't reach the server";

  testWidgets('stays hidden until a request fails to connect', (tester) async {
    final container = await pump(tester);
    expect(find.text(message), findsNothing);

    container.read(serverReachabilityProvider.notifier).report(true);
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
  });

  testWidgets('shows the problem and a retry while the server is unreachable', (tester) async {
    final container = await pump(tester);
    container.read(serverReachabilityProvider.notifier).report(false);
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry clears the banner once the server answers', (tester) async {
    final container = await pump(tester);
    final adapter = FakeHttpAdapter.status(200);
    container.read(dioProvider).httpClientAdapter = adapter;
    container.read(serverReachabilityProvider.notifier).report(false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(adapter.paths, ['/api/auth/healthcheck']);
    expect(find.text(message), findsNothing);
  });

  testWidgets('retry keeps the banner, ready to try again, while the server stays down', (tester) async {
    final container = await pump(tester);
    final adapter = FakeHttpAdapter.failing(DioExceptionType.connectionError);
    container.read(dioProvider).httpClientAdapter = adapter;
    container.read(serverReachabilityProvider.notifier).report(false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(adapter.paths.length, 2);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('reads on its own colour in dark mode', (tester) async {
    final container = await pump(tester, themeMode: ThemeMode.dark);
    container.read(serverReachabilityProvider.notifier).report(false);
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text(message));
    final material = tester.widget<Material>(
      find.ancestor(of: find.text(message), matching: find.byType(Material)).first,
    );
    expect(text.style?.color, isNot(material.color));
  });
}
