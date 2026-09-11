import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';

void main() {
  test('keepingPrevious carries the old data through loading and error', () {
    const data = AsyncData<int>(1);
    final loading = const AsyncLoading<int>().keepingPrevious(data);
    expect(loading.isLoading, isTrue);
    expect(loading.value, 1);
    final error = AsyncError<int>('boom', StackTrace.empty).keepingPrevious(loading);
    expect(error.hasError, isTrue);
    expect(error.value, 1);
  });

  test('noRetry never schedules a retry', () {
    expect(noRetry(0, Exception()), isNull);
    expect(noRetry(5, StateError('x')), isNull);
  });
}
