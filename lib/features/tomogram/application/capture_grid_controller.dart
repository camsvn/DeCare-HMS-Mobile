import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';

/// Whether the composition grid is drawn over the camera preview.
///
/// A per-device preference rather than per-session: someone who frames with a
/// grid frames every photo with it, and re-enabling it on every visit to the
/// capture screen is the kind of friction that makes a feature unused.
class CaptureGridController extends Notifier<bool> {
  static const key = 'capture_grid';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(key) ?? false;

  Future<void> toggle() async {
    final next = !state;
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(key, next);
  }
}

final captureGridProvider = NotifierProvider<CaptureGridController, bool>(CaptureGridController.new);
