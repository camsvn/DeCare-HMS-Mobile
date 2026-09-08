import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';

String token(DateTime exp) {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${b64({'alg': 'HS256'})}.${b64({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.s';
}

void main() {
  test('isValid follows refresh token expiry', () {
    final now = DateTime.utc(2026, 9, 8);
    final live = Session(accessToken: 'a', refreshToken: token(now.add(const Duration(days: 1))));
    final dead = Session(accessToken: 'a', refreshToken: token(now.subtract(const Duration(days: 1))));
    expect(live.isValid(now: now), isTrue);
    expect(dead.isValid(now: now), isFalse);
  });

  test('repository round-trips through secure store', () async {
    final repo = SessionRepository(InMemorySecureStore());
    expect(await repo.read(), isNull);
    await repo.save(const Session(accessToken: 'a', refreshToken: 'r'));
    final s = await repo.read();
    expect(s?.accessToken, 'a');
    expect(s?.refreshToken, 'r');
    await repo.clear();
    expect(await repo.read(), isNull);
  });
}
