import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_envelope.dart';
import 'package:hms_uploader/core/network/api_failure.dart';

void main() {
  test('returns data on success', () {
    expect(unwrapEnvelope({'status': 'success', 'data': {'a': 1}}), {'a': 1});
  });
  test('returns null data on success with null', () {
    expect(unwrapEnvelope({'status': 'success', 'data': null}), isNull);
  });
  test('throws RejectedFailure with message on fail', () {
    expect(
      () => unwrapEnvelope({'status': 'fail', 'data': 'Invalid opid'}),
      throwsA(isA<RejectedFailure>().having((f) => f.detail, 'detail', 'Invalid opid')),
    );
  });
  test('throws RejectedFailure with message on error', () {
    expect(
      () => unwrapEnvelope({'status': 'error', 'message': 'boom'}),
      throwsA(isA<RejectedFailure>().having((f) => f.detail, 'detail', 'boom')),
    );
  });
  test('throws BadDataFailure when body is not a map', () {
    expect(() => unwrapEnvelope('nope'), throwsA(isA<BadDataFailure>()));
    expect(() => unwrapEnvelope(null), throwsA(isA<BadDataFailure>()));
  });
}
