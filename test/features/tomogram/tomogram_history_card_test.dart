import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

TomogramSet _set({
  required int id,
  required DateTime dateTime,
  List<String> narrations = const [],
}) =>
    TomogramSet(
      id: id,
      dateTime: dateTime,
      doctorId: 1,
      tomogramTypeId: 1,
      details: [
        for (var i = 0; i < narrations.length; i++)
          TomogramSetDetail(id: i + 1, tomogramPartId: i + 1, narration: narrations[i]),
      ],
    );

void main() {
  late MockTomogramHistoryApi api;

  setUp(() => api = MockTomogramHistoryApi());

  Future<void> pump(WidgetTester tester) => pumpApp(
        tester,
        const TomogramHistoryCard(opid: 42),
        overrides: [tomogramHistoryApiProvider.overrideWithValue(api)],
      );

  testWidgets('shows the set count and last upload date, and expands on tap', (tester) async {
    when(() => api.list(42)).thenAnswer((_) async => [
          _set(id: 9, dateTime: DateTime(2026, 9, 8, 14, 32), narrations: ['left forearm', 'right forearm']),
          _set(id: 8, dateTime: DateTime(2026, 9, 1, 9, 5), narrations: ['scalp']),
        ]);
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Already uploaded'), findsOneWidget);
    expect(find.text('2 sets'), findsOneWidget);
    expect(find.text('Last 8 Sep 14:32'), findsOneWidget);
    // Collapsed: the per-set rows are not built yet.
    expect(find.text('left forearm · right forearm'), findsNothing);

    await tester.tap(find.text('Already uploaded'));
    await tester.pumpAndSettle();

    expect(find.text('left forearm · right forearm'), findsOneWidget);
    expect(find.text('scalp'), findsOneWidget);
    expect(find.text('1 Sep 09:05'), findsOneWidget);

    await tester.tap(find.text('Already uploaded'));
    await tester.pumpAndSettle();
    expect(find.text('scalp'), findsNothing);
  });

  testWidgets('a single set is counted in the singular', (tester) async {
    when(() => api.list(42)).thenAnswer((_) async => [_set(id: 9, dateTime: DateTime(2026, 9, 8, 14, 32))]);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('1 set'), findsOneWidget);
  });

  testWidgets('a set with no narrations falls back to the no-description label', (tester) async {
    when(() => api.list(42)).thenAnswer((_) async => [
          _set(id: 9, dateTime: DateTime(2026, 9, 8, 14, 32), narrations: ['']),
        ]);
    await pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already uploaded'));
    await tester.pumpAndSettle();
    expect(find.text('No description'), findsOneWidget);
  });

  testWidgets('renders nothing when the patient has no history', (tester) async {
    when(() => api.list(42)).thenAnswer((_) async => const []);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byType(DsCard), findsNothing);
    expect(find.text('Already uploaded'), findsNothing);
    // Takes no space of its own, so the screen's layout is unchanged.
    final box = tester.widget<SizedBox>(
      find.descendant(of: find.byType(TomogramHistoryCard), matching: find.byType(SizedBox)),
    );
    expect(box.width, 0);
    expect(box.height, 0);
  });

  testWidgets('shows a skeleton while loading', (tester) async {
    final gate = Completer<List<TomogramSet>>();
    when(() => api.list(42)).thenAnswer((_) => gate.future);
    await pump(tester);
    await tester.pump();
    expect(find.byType(DsSkeleton), findsOneWidget);

    gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(DsSkeleton), findsNothing);
  });

  testWidgets('shows the error text when the fetch fails', (tester) async {
    when(() => api.list(42)).thenThrow(const TimeoutFailure());
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Could not load history'), findsOneWidget);
    expect(find.text('Already uploaded'), findsNothing);
  });
}
