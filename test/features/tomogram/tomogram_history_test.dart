import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDio extends Mock implements Dio {}

class MockTomogramApi extends Mock implements TomogramApi {}

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

/// The documented `GET /api/tomogram?opid=N` payload, newest first. The older
/// set carries numeric strings, which the server sends for some columns.
const _body = {
  'status': 'success',
  'data': [
    {
      'id': 9,
      'dateTime': '2026-09-08T14:32:00',
      'doctorId': 3,
      'tomogramTypeId': 1,
      'details': [
        {'id': 21, 'tomogramPartId': 4, 'narration': 'left forearm'},
        {'id': 22, 'tomogramPartId': 5, 'narration': 'right forearm'},
      ],
    },
    {
      'id': '8',
      'dateTime': '2026-09-01T09:05:00',
      'doctorId': '3',
      'tomogramTypeId': '1',
      'details': [
        {'id': '11', 'tomogramPartId': '2', 'narration': 'scalp'},
      ],
    },
  ],
};

Response<dynamic> _ok(Object body) => Response<dynamic>(
      requestOptions: RequestOptions(path: '/tomogram'),
      statusCode: 200,
      data: body,
    );

void main() {
  group('DioTomogramHistoryApi', () {
    test('queries opid and parses the sets newest first with their details', () async {
      final dio = MockDio();
      when(() => dio.get<dynamic>('/tomogram', queryParameters: {'opid': 42}))
          .thenAnswer((_) async => _ok(_body));

      final sets = await DioTomogramHistoryApi(dio).list(42);

      expect(sets.map((s) => s.id), [9, 8]);
      expect(sets.first.dateTime, DateTime(2026, 9, 8, 14, 32));
      expect(sets.first.doctorId, 3);
      expect(sets.first.tomogramTypeId, 1);
      expect(sets.first.details.map((d) => d.id), [21, 22]);
      expect(sets.first.details.map((d) => d.tomogramPartId), [4, 5]);
      expect(sets.first.narrationsSummary, 'left forearm · right forearm');
      // Numeric strings parse the same as numbers.
      expect(sets.last.id, 8);
      expect(sets.last.details.single.tomogramPartId, 2);
      expect(sets.last.narrationsSummary, 'scalp');
    });

    test('a set without narrations summarises to null', () async {
      final dio = MockDio();
      when(() => dio.get<dynamic>('/tomogram', queryParameters: {'opid': 7})).thenAnswer(
        (_) async => _ok({
          'status': 'success',
          'data': [
            {
              'id': 1,
              'dateTime': '2026-09-08T14:32:00',
              'doctorId': 1,
              'tomogramTypeId': 1,
              'details': [
                {'id': 1, 'tomogramPartId': 1, 'narration': ''},
                {'id': 2, 'tomogramPartId': 2, 'narration': '  '},
              ],
            },
          ],
        }),
      );

      final sets = await DioTomogramHistoryApi(dio).list(7);
      expect(sets.single.details, hasLength(2));
      expect(sets.single.narrationsSummary, isNull);
    });

    test('maps a 404 to NotFoundFailure carrying the server message', () async {
      final dio = MockDio();
      final req = RequestOptions(path: '/tomogram');
      when(() => dio.get<dynamic>('/tomogram', queryParameters: any(named: 'queryParameters'))).thenThrow(
        DioException(
          requestOptions: req,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: req,
            statusCode: 404,
            data: {'status': 'fail', 'data': 'Invalid OP Number'},
          ),
        ),
      );

      await expectLater(
        DioTomogramHistoryApi(dio).list(1),
        throwsA(isA<NotFoundFailure>().having((f) => f.detail, 'detail', 'Invalid OP Number')),
      );
    });
  });

  group('TomogramSet.fromJson', () {
    Map<String, dynamic> raw(Object? dateTime, {Object? details}) => {
          'id': 1,
          'dateTime': dateTime,
          'doctorId': 1,
          'tomogramTypeId': 1,
          'details': details,
        };

    test('accepts epoch milliseconds for dateTime', () {
      final millis = DateTime(2026, 9, 8, 14, 32).millisecondsSinceEpoch;
      expect(TomogramSet.fromJson(raw(millis)).dateTime, DateTime(2026, 9, 8, 14, 32));
    });

    test('keeps the set with an epoch dateTime when the value is unreadable', () {
      // Deliberate: a malformed date shows as the epoch rather than dropping
      // the whole set, matching how the other DTOs default a bad int to 0.
      expect(TomogramSet.fromJson(raw('not a date')).dateTime, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('details that are missing or not a list become an empty list', () {
      expect(TomogramSet.fromJson(raw('2026-09-08T14:32:00')).details, isEmpty);
      expect(TomogramSet.fromJson(raw('2026-09-08T14:32:00', details: 'nope')).details, isEmpty);
      expect(TomogramSet.fromJson(raw('2026-09-08T14:32:00')).narrationsSummary, isNull);
    });
  });

  group('tomogramHistoryProvider', () {
    late MockTomogramHistoryApi history;
    late MockTomogramApi upload;
    late ProviderContainer container;

    setUp(() async {
      history = MockTomogramHistoryApi();
      upload = MockTomogramApi();
      // A finished upload also remembers its descriptions, which reads prefs.
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer(overrides: [
        tomogramHistoryApiProvider.overrideWithValue(history),
        tomogramApiProvider.overrideWithValue(upload),
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        uuidProvider.overrideWithValue(() => 'id'),
      ]);
      addTearDown(container.dispose);
    });

    TomogramSet set(int id) => TomogramSet(
          id: id,
          dateTime: DateTime(2026, 9, 8, 14, 32),
          doctorId: 1,
          tomogramTypeId: 1,
          details: const [TomogramSetDetail(id: 1, tomogramPartId: 1, narration: 'scalp')],
        );

    test('exposes the fetched sets for its opid', () async {
      when(() => history.list(42)).thenAnswer((_) async => [set(9), set(8)]);
      final sets = await container.read(tomogramHistoryProvider(42).future);
      expect(sets.map((s) => s.id), [9, 8]);
      expect(container.read(tomogramHistoryProvider(42)).value, hasLength(2));
      verify(() => history.list(42)).called(1);
    });

    test('exposes a fetch failure as an error state', () async {
      when(() => history.list(42)).thenThrow(const TimeoutFailure());
      await expectLater(container.read(tomogramHistoryProvider(42).future), throwsA(isA<TimeoutFailure>()));
      expect(container.read(tomogramHistoryProvider(42)).error, isA<TimeoutFailure>());
    });

    test('a successful upload refetches the history for that opid', () async {
      final dir = await Directory.systemTemp.createTemp('tomo_history');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      when(() => history.list(42)).thenAnswer((_) async => [set(9)]);
      when(() => upload.upload(42, any())).thenAnswer((_) async => const []);

      final historySub = container.listen(tomogramHistoryProvider(42), (_, _) {});
      final draftSub = container.listen(tomogramControllerProvider(42), (_, _) {});
      await container.read(tomogramHistoryProvider(42).future);

      final drafts = container.read(tomogramControllerProvider(42).notifier);
      drafts.addFiles([file.path]);
      await drafts.upload();
      await container.read(tomogramHistoryProvider(42).future);

      verify(() => history.list(42)).called(2);
      historySub.close();
      draftSub.close();
    });
  });
}
