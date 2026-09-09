import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Bridge feature state into the core network layer without core importing features.
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
    refreshAccessTokenProvider
        .overrideWith((ref) => () => ref.read(sessionControllerProvider.notifier).refreshAccessToken()),
  ]);
  // Load persisted state before the first frame so the redirect gate is exact.
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);

  // Keep framework errors visible and stop an unhandled async error from
  // taking the isolate down in release.
  FlutterError.onError = (d) => FlutterError.presentError(d);
  PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('Unhandled: $e\n$st');
    return true;
  };

  runApp(UncontrolledProviderScope(container: container, child: const HmsApp()));
  FlutterNativeSplash.remove();
}
