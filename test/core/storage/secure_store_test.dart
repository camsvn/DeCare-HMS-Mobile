import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';

void main() {
  test('InMemorySecureStore round-trips and deletes', () async {
    final s = InMemorySecureStore();
    expect(await s.read('k'), isNull);
    await s.write('k', 'v');
    expect(await s.read('k'), 'v');
    await s.write('k', null);
    expect(await s.read('k'), isNull);
    await s.write('k', 'v2');
    await s.delete('k');
    expect(await s.read('k'), isNull);
  });
}
