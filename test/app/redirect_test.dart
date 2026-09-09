import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/app/router.dart';
import 'package:hms_uploader/core/navigation/route_paths.dart';

void main() {
  group('computeRedirect', () {
    test('no server url always goes to configure', () {
      for (final loc in [RoutePaths.login, RoutePaths.dashboard, RoutePaths.settings, RoutePaths.about]) {
        expect(computeRedirect(location: loc, hasServerUrl: false, sessionValid: false), RoutePaths.configure);
      }
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: false, sessionValid: false), isNull);
    });

    test('url without session goes to login, configure allowed', () {
      expect(computeRedirect(location: RoutePaths.dashboard, hasServerUrl: true, sessionValid: false), RoutePaths.login);
      expect(computeRedirect(location: RoutePaths.tomogram(4), hasServerUrl: true, sessionValid: false), RoutePaths.login);
      expect(computeRedirect(location: RoutePaths.login, hasServerUrl: true, sessionValid: false), isNull);
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: true, sessionValid: false), isNull);
    });

    test('valid session leaves auth screens for home', () {
      expect(computeRedirect(location: RoutePaths.login, hasServerUrl: true, sessionValid: true), RoutePaths.dashboard);
      expect(computeRedirect(location: RoutePaths.configure, hasServerUrl: true, sessionValid: true), RoutePaths.dashboard);
      expect(computeRedirect(location: RoutePaths.dashboard, hasServerUrl: true, sessionValid: true), isNull);
      expect(computeRedirect(location: RoutePaths.about, hasServerUrl: true, sessionValid: true), isNull);
    });
  });
}
