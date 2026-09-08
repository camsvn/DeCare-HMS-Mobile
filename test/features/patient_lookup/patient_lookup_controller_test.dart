import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOpRegisterApi extends Mock implements OpRegisterApi {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockOpRegisterApi api;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = MockOpRegisterApi();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      opRegisterApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
  });

  test('search returns patient and records it in recents', () async {
    const jane = Patient(id: 1, opid: 42, name: 'Jane');
    when(() => api.getByOpId(42)).thenAnswer((_) async => jane);
    final sub = container.listen(patientLookupControllerProvider, (_, __) {});
    final result = await container.read(patientLookupControllerProvider.notifier).search(42);
    expect(result, jane);
    expect(container.read(patientLookupControllerProvider).value, jane);
    expect(container.read(recentSearchesControllerProvider), [jane]);
    sub.close();
  });

  test('search failure exposes error and records nothing', () async {
    when(() => api.getByOpId(any())).thenThrow(const NotFoundFailure('Invalid OP Number'));
    final sub = container.listen(patientLookupControllerProvider, (_, __) {});
    final result = await container.read(patientLookupControllerProvider.notifier).search(1);
    expect(result, isNull);
    expect(container.read(patientLookupControllerProvider).error, isA<NotFoundFailure>());
    expect(container.read(recentSearchesControllerProvider), isEmpty);
    sub.close();
  });

  test('DioOpRegisterApi queries opid and parses patient', () async {
    final dio = MockDio();
    when(() => dio.get<dynamic>('/opregister', queryParameters: {'opid': 42})).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: '/opregister'),
        statusCode: 200,
        data: {'status': 'success', 'data': {'id': 9, 'opid': 42, 'name': 'Jane'}},
      ),
    );
    expect(await DioOpRegisterApi(dio).getByOpId(42), const Patient(id: 9, opid: 42, name: 'Jane'));
  });
}
