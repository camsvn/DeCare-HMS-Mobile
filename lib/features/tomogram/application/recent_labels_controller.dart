import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/data/recent_labels_repository.dart';

/// The device's recent descriptions, newest first, kept in step with what is
/// persisted so the suggestion row updates the moment a set is captured.
class RecentLabelsController extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(recentLabelsRepositoryProvider).read();

  /// Remembers [labels] as the newest, in the order given. Re-reads rather
  /// than merging again here: the repository owns the trimming, the
  /// case-insensitive dedupe, the length cap and the count cap.
  Future<void> remember(Iterable<String> labels) async {
    final repository = ref.read(recentLabelsRepositoryProvider);
    await repository.remember(labels);
    state = repository.read();
  }

  /// Stops offering [label]. What the device has typed before is a guess, and
  /// a wrong guess that keeps coming back is worse than no guess.
  Future<void> forget(String label) async {
    final repository = ref.read(recentLabelsRepositoryProvider);
    await repository.forget(label);
    state = repository.read();
  }
}

final recentLabelsProvider = NotifierProvider<RecentLabelsController, List<String>>(
  RecentLabelsController.new,
);
