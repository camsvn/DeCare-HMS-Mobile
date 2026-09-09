import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/theme/app_theme.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

void main() {
  testWidgets('shows copy and flashes on invalid url', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockHealthCheckApi();
    await pumpApp(tester, const ConfigureUrlScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Connect to your server'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'not a url');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Invalid URL: Please provide a valid URL'), findsOneWidget);
    expect(find.text('Enter a valid server address'), findsOneWidget);
    verifyNever(() => api.check(any()));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('flashes host error when health check fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = MockHealthCheckApi();
    when(() => api.check(any())).thenThrow(const CannotConnectFailure());
    await pumpApp(tester, const ConfigureUrlScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'http://decare.team');
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Host: Could not reach the server'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a successful connect moves on even when the URL is unchanged', (tester) async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://decare.team'});
    final prefs = await SharedPreferences.getInstance();
    final api = MockHealthCheckApi();
    when(() => api.check(any())).thenAnswer((_) async {});
    final router = GoRouter(
      initialLocation: RoutePaths.configure,
      routes: [
        GoRoute(path: RoutePaths.configure, builder: (_, __) => const ConfigureUrlScreen()),
        GoRoute(path: RoutePaths.login, builder: (_, __) => const Scaffold(body: Text('signed in area'))),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    // main.dart resolves the persisted URL before the first frame; do the same
    // so the screen never sees the initial load's loading-to-data transition.
    await container.read(serverConfigControllerProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: buildAppTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Connect to your server'), findsOneWidget);
    // The saved URL is re-entered verbatim, so the controller's value never
    // changes; only the loading-to-data transition marks the connect as done.
    await tester.enterText(find.byType(TextField), 'http://decare.team');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('signed in area'), findsOneWidget);
  });
}
