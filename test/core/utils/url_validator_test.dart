import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/url_validator.dart';

void main() {
  group('isValidServerUrl', () {
    for (final ok in [
      'http://cutis.decare.team',
      'https://www.decare.team',
      'decare.team',
      'my-hms.example.com',
      'http://192.168.1.10:3000',
      'localhost:3000',
      'http://localhost',
      'http://10.0.0.5:8080/hms',
      'HTTP://DECARE.TEAM',
      'cutis.decare.team:3000',
      'https://a.b.c.example.org/path',
    ]) {
      test('accepts $ok', () => expect(isValidServerUrl(ok), isTrue, reason: ok));
    }
    for (final bad in ['', 'not a url', 'http://', 'ftp://x.com', 'foo', 'http://exa mple.com']) {
      test('rejects "$bad"', () => expect(isValidServerUrl(bad), isFalse, reason: bad));
    }
  });

  group('normalizeServerUrl', () {
    test('adds http scheme when missing', () {
      expect(normalizeServerUrl('decare.team'), 'http://decare.team');
    });
    test('keeps https', () {
      expect(normalizeServerUrl('https://decare.team'), 'https://decare.team');
    });
    test('trims whitespace and trailing slash', () {
      expect(normalizeServerUrl('  http://decare.team/  '), 'http://decare.team');
    });
    test('returns null for invalid input', () {
      expect(normalizeServerUrl('not a url'), isNull);
    });
  });
}
