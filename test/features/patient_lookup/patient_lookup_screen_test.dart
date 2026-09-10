import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/op_search_bar.dart';
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

  /// Titles of the recent rows, top to bottom.
  List<String> recentTitles(WidgetTester tester) =>
      tester.widgetList<DsListRow>(find.byType(DsListRow)).map((row) => row.title).toList();

  Finder spinnerIn(String title) => find.descendant(
        of: find.widgetWithText(DsListRow, title),
        matching: find.byType(CircularProgressIndicator),
      );

  setUp(() => api = MockOpRegisterApi());

  testWidgets('shows empty state when no recent searches', (tester) async {
    final prefs = await prefsWith({});
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('Tomogram'), findsOneWidget);
    expect(find.text('There is no patient selected.'), findsOneWidget);
    expect(find.text('Enter OP Number'), findsOneWidget);
  });

  testWidgets('lists recent searches and clears them', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"},{"id":2,"opid":34,"name":"Bob"}]',
    });
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    expect(find.text('Recent'), findsOneWidget);
    expect(find.widgetWithText(DsListRow, 'Jane'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.widgetWithText(DsListRow, 'Bob'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Jane'), findsNothing);
    expect(find.text('There is no patient selected.'), findsOneWidget);
  });

  testWidgets('swiping a recent row away removes it', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"},{"id":2,"opid":34,"name":"Bob"}]',
    });
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.drag(find.text('Jane'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Jane'), findsNothing);
    expect(find.widgetWithText(DsListRow, 'Bob'), findsOneWidget);
  });

  testWidgets('deleting a recent row through the trash icon removes it', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"}]',
    });
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Jane'), findsNothing);
  });

  testWidgets('submitting an OP number looks it up and reports the patient', (tester) async {
    final prefs = await prefsWith({});
    const jane = Patient(id: 1, opid: 42, name: 'Jane');
    when(() => api.getByOpId(42)).thenAnswer((_) async => jane);
    Patient? selected;
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (p) async => selected = p), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '42');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(selected, jane);
    expect(find.widgetWithText(DsListRow, 'Jane'), findsOneWidget);
  });

  testWidgets('a lookup from a recent row keeps the list on screen and spins in that row', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"},{"id":2,"opid":34,"name":"Bob"}]',
    });
    const bob = Patient(id: 2, opid: 34, name: 'Bob');
    final gate = Completer<Patient>();
    final navigated = Completer<void>();
    when(() => api.getByOpId(34)).thenAnswer((_) => gate.future);
    final selected = <Patient>[];
    await pumpApp(
      tester,
      PatientLookupScreen(onPatientSelected: (p) async {
        selected.add(p);
        await navigated.future;
      }),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        opRegisterApiProvider.overrideWithValue(api),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Bob'));
    await tester.pump();

    // The list stays put: no skeletons, both rows still readable.
    expect(find.byType(DsSkeleton), findsNothing);
    expect(recentTitles(tester), ['Jane', 'Bob']);
    // Only the row being looked up carries a spinner, in place of its trash icon.
    expect(spinnerIn('Bob'), findsOneWidget);
    expect(spinnerIn('Jane'), findsNothing);
    expect(
      find.descendant(of: find.widgetWithText(DsListRow, 'Bob'), matching: find.byIcon(Icons.delete_outline)),
      findsNothing,
    );

    // Every row is inert while the lookup runs.
    await tester.tap(find.text('Jane'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    verifyNever(() => api.getByOpId(12));
    expect(recentTitles(tester), ['Jane', 'Bob']);

    gate.complete(bob);
    await tester.pump();
    expect(selected, [bob]);
    // Recents are reordered on return, not before leaving.
    expect(recentTitles(tester), ['Jane', 'Bob']);
    navigated.complete();
    await tester.pumpAndSettle();
    expect(recentTitles(tester), ['Bob', 'Jane']);
    expect(spinnerIn('Bob'), findsNothing);
    verify(() => api.getByOpId(34)).called(1);
  });

  testWidgets('a lookup from Go leaves the recent list untouched', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"}]',
    });
    const ann = Patient(id: 3, opid: 42, name: 'Ann');
    final gate = Completer<Patient>();
    final navigated = Completer<void>();
    when(() => api.getByOpId(42)).thenAnswer((_) => gate.future);
    final selected = <Patient>[];
    await pumpApp(
      tester,
      PatientLookupScreen(onPatientSelected: (p) async {
        selected.add(p);
        await navigated.future;
      }),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        opRegisterApiProvider.overrideWithValue(api),
      ],
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), '42');
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(find.byType(DsSkeleton), findsNothing);
    expect(recentTitles(tester), ['Jane']);
    // The search bar carries the busy state; no row spins for an OP that is not listed.
    expect(tester.widget<OpSearchBar>(find.byType(OpSearchBar)).busy, isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete(ann);
    await tester.pump();
    expect(selected, [ann]);
    expect(recentTitles(tester), ['Jane']);
    // The request has landed but the screen it opened has not closed yet: Go
    // stays busy for as long as the rows below it stay inert.
    expect(tester.widget<OpSearchBar>(find.byType(OpSearchBar)).busy, isTrue);
    navigated.complete();
    await tester.pumpAndSettle();
    expect(recentTitles(tester), ['Ann', 'Jane']);
    expect(tester.widget<OpSearchBar>(find.byType(OpSearchBar)).busy, isFalse);
  });

  testWidgets('taps while a lookup is in flight do not start a second one', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":42,"name":"Jane"}]',
    });
    final gate = Completer<Patient>();
    when(() => api.getByOpId(42)).thenAnswer((_) => gate.future);
    var selected = 0;
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async => selected++), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '42');
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();
    // The row stays on screen throughout, and stays inert.
    await tester.tap(find.widgetWithText(DsListRow, 'Jane'));
    await tester.pump();
    gate.complete(const Patient(id: 1, opid: 42, name: 'Jane'));
    await tester.pumpAndSettle();
    verify(() => api.getByOpId(42)).called(1);
    expect(selected, 1);
  });

  testWidgets('lookup failure flashes Patient error and leaves the list alone', (tester) async {
    final prefs = await prefsWith({
      'recent_searches': '[{"id":1,"opid":12,"name":"Jane"}]',
    });
    when(() => api.getByOpId(any())).thenThrow(const NotFoundFailure('Invalid OP Number'));
    await pumpApp(tester, PatientLookupScreen(onPatientSelected: (_) async {}), overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '7');
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Patient: Invalid OP Number'), findsOneWidget);
    expect(recentTitles(tester), ['Jane']);
    expect(find.byType(DsSkeleton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
