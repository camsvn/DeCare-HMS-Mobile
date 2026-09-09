import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/dashboard/dashboard.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

AppModule fakeModule(String id, String title) => AppModule(
      id: id,
      title: (_) => title,
      subtitle: (_) => 'sub',
      icon: Icons.extension,
      entryRoute: '/app/$id',
      routes: const [],
    );

void main() {
  late SharedPreferences prefs;
  late MockHealthCheckApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'server_url': 'http://cutis.decare.team'});
    prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    when(() => api.check(any())).thenAnswer((_) async {});
  });

  testWidgets('renders a card per module plus placeholder when only one', (tester) async {
    await pumpApp(tester, DashboardScreen(modules: [fakeModule('a', 'Alpha')]), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('More modules coming'), findsOneWidget);
    expect(find.text('cutis.decare.team'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('no placeholder with two modules; unreachable server shows warning text', (tester) async {
    when(() => api.check(any())).thenThrow(Exception('down'));
    await pumpApp(tester, DashboardScreen(modules: [fakeModule('a', 'Alpha'), fakeModule('b', 'Beta')]), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      healthCheckApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsNWidgets(2));
    expect(find.byType(ModulePlaceholderCard), findsNothing);
    expect(find.text('Server unreachable'), findsOneWidget);
  });
}
