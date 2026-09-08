import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('tomo'));
  tearDown(() => dir.delete(recursive: true));

  setUpAll(() {
    registerFallbackValue(Options());
  });

  test('upload builds multipart with opid, images and narrations', () async {
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 1]);
    final b = File('${dir.path}/b.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 2]);
    final dio = MockDio();
    when(() => dio.post<dynamic>('/tomogram', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/tomogram'),
              statusCode: 200,
              data: {
                'status': 'success',
                'data': [
                  {'id': 1, 'masterid': 7, 'tomogrampartid': 2, 'narration': 'left arm'},
                ],
              },
            ));

    final results = await DioTomogramApi(dio).upload(42, [
      TomogramDraft(id: 'aaa', filePath: a.path, description: 'left arm'),
      TomogramDraft(id: 'bbb', filePath: b.path, description: 'right arm'),
    ]);

    expect(results.single.masterid, 7);
    final captured = verify(() => dio.post<dynamic>('/tomogram',
        data: captureAny(named: 'data'), options: captureAny(named: 'options'))).captured;
    final form = captured[0] as FormData;
    final options = captured[1] as Options;
    // dart:core MapEntry has no value equality, so compare key/value pairs
    // directly rather than relying on containsAll's default `==` matching.
    expect(form.fields.map((e) => '${e.key}=${e.value}'), containsAll([
      'opid=42',
      'narrations[0]=left arm',
      'narrations[1]=right arm',
    ]));
    expect(form.files.map((e) => e.key), ['images', 'images']);
    expect(form.files.map((e) => e.value.filename), ['imageaaa.jpg', 'imagebbb.jpg']);
    expect(form.files.first.value.contentType.toString(), 'image/jpeg');
    expect(options.sendTimeout, uploadTimeout);
    expect(options.receiveTimeout, uploadTimeout);
  });

  test('upload maps errors to ApiFailure', () async {
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    final dio = MockDio();
    final req = RequestOptions(path: '/tomogram');
    when(() => dio.post<dynamic>(any(), data: any(named: 'data'), options: any(named: 'options')))
        .thenThrow(DioException(requestOptions: req, type: DioExceptionType.sendTimeout));
    expect(
      () => DioTomogramApi(dio).upload(1, [TomogramDraft(id: 'x', filePath: a.path)]),
      throwsA(isA<TimeoutFailure>()),
    );
  });
}
