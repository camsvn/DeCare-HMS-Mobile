import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockAuthApi extends Mock implements AuthApi {}

/// Login shows the configured host as a chip, so the screen needs prefs.
Future<SharedPreferences> _prefsWithHost() async {
  SharedPreferences.setMockInitialValues({'server_url': 'http://decare.team'});
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets('renders fields and flashes invalid credentials', (tester) async {
    final prefs = await _prefsWithHost();
    final api = MockAuthApi();
    when(() => api.login(any(), any())).thenThrow(const UnauthorizedFailure());
    await pumpApp(tester, const LoginScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      authApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('DeCare HMS'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('decare.team'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Change server'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'doc');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Login: Invalid username or password'), findsOneWidget);
    verify(() => api.login('doc', 'pw')).called(1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('eye icon toggles password visibility', (tester) async {
    final prefs = await _prefsWithHost();
    await pumpApp(tester, const LoginScreen(), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      authApiProvider.overrideWithValue(MockAuthApi()),
    ]);
    await tester.pumpAndSettle();
    TextField password() => tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });
}
