import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_history_api.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';

/// The sets already uploaded for one OP number. Invalidated by
/// `TomogramController.upload()` so a fresh upload shows up immediately.
class TomogramHistoryController extends AsyncNotifier<List<TomogramSet>> {
  TomogramHistoryController(this.opid);

  final int opid;

  @override
  Future<List<TomogramSet>> build() => ref.read(tomogramHistoryApiProvider).list(opid);
}

final tomogramHistoryProvider = AsyncNotifierProvider.autoDispose
    .family<TomogramHistoryController, List<TomogramSet>, int>(TomogramHistoryController.new);
