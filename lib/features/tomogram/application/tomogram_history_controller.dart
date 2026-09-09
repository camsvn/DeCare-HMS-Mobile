import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_history_api.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';

/// The sets already uploaded for one OP number. Invalidated by
/// `TomogramController.upload()` so a fresh upload shows up immediately.
class TomogramHistoryController extends AutoDisposeFamilyAsyncNotifier<List<TomogramSet>, int> {
  @override
  Future<List<TomogramSet>> build(int arg) => ref.read(tomogramHistoryApiProvider).list(arg);
}

final tomogramHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<TomogramHistoryController, List<TomogramSet>, int>(TomogramHistoryController.new);
