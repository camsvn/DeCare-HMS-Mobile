import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/app/app.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/utils/stale_cache_sweep.dart';
import 'package:hms_uploader/features/auth/auth.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  // Where the offline upload queue keeps its staged photos.
  final documentsDir = await getApplicationDocumentsDirectory();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDocumentsDirProvider.overrideWithValue(documentsDir),
    // Bridge feature state into the core network layer without core importing features.
    serverUrlProvider.overrideWith((ref) => ref.watch(serverConfigControllerProvider).valueOrNull),
    accessTokenProvider.overrideWith((ref) => ref.watch(sessionControllerProvider).valueOrNull?.accessToken),
    refreshAccessTokenProvider
        .overrideWith((ref) => () => ref.read(sessionControllerProvider.notifier).refreshAccessToken()),
  ]);
  // Load persisted state before the first frame so the redirect gate is exact.
  await container.read(serverConfigControllerProvider.future);
  await container.read(sessionControllerProvider.future);

  // Drain whatever the last run could not upload, and keep watching the
  // network. Not awaited: the first frame must not wait on an upload.
  unawaited(container.read(uploadQueueProvider.notifier).start());
  // Photos a previous run left in the cache because the process died before
  // the screen owning them could clean up. Not awaited either.
  unawaited(getTemporaryDirectory().then(sweepStaleCache).catchError((Object e) {
    debugPrint('sweepStaleCache failed: $e');
    return 0;
  }));

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
