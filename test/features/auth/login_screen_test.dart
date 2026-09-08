import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockAuthApi extends Mock implements AuthApi {}

void main() {
  testWidgets('renders fields and flashes invalid credentials', (tester) async {
    final api = MockAuthApi();
    when(() => api.login(any(), any())).thenThrow(const UnauthorizedFailure());
    await pumpApp(tester, const LoginScreen(), overrides: [
      secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      authApiProvider.overrideWithValue(api),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('DeCare HMS'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

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
    await pumpApp(tester, const LoginScreen(), overrides: [
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
