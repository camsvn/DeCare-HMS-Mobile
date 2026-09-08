import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockOpRegisterApi extends Mock implements OpRegisterApi {}

void main() {
  late MockOpRegisterApi api;

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  setUp(() => api = MockOpRegisterApi());

  testWidgets('shows empty state when no recent searches', (tester) async {
    final prefs = await prefsWith({});
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('There is no patient selected.'), findsOneWidget);
    expect(find.text('Enter OP Number'), findsOneWidget);
  });

  testWidgets('lists recent searches and clears them', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"},{"id":2,"opid":34,"name":"Bob"}]',
    });
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('Jane, 12'), findsOneWidget);
    expect(find.text('Bob, 34'), findsOneWidget);
    await tester.tap(find.text('clear all'));
    await tester.pump();
    expect(find.text('Jane, 12'), findsNothing);
    expect(find.text('There is no patient selected.'), findsOneWidget);
  });

  testWidgets('submitting an OP number looks it up and reports the patient', (tester) async {
    final prefs = await prefsWith({});
    const jane = Patient(id: 1, opid: 42, name: 'Jane');
    when(() => api.getByOpId(42)).thenAnswer((_) async => jane);
    Patient? selected;
    await pumpApp(tester, HomeScreen(onPatientSelected: (p) => selected = p), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '42');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(selected, jane);
    expect(find.text('Jane, 42'), findsOneWidget);
  });

  testWidgets('lookup failure flashes Patient error', (tester) async {
    final prefs = await prefsWith({});
    when(() => api.getByOpId(any())).thenThrow(const NotFoundFailure('Invalid OP Number'));
    await pumpApp(tester, HomeScreen(onPatientSelected: (_) {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patient: Invalid OP Number'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
