import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/capture_controller.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:hms_uploader/features/tomogram/data/shot.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/label_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/photo_viewer.dart';

/// One capture session's shots in the [PhotoViewer].
///
/// This is what a thumbnail tap opens: a photo is something to look at before
/// deciding about it, so removing it is a button in here rather than the only
/// thing a tap on the strip could ever do. All this screen does is hand the
/// session's shots to the viewer and answer what it asks.
class ShotPreviewScreen extends ConsumerStatefulWidget {
  const ShotPreviewScreen({super.key, required this.initialIndex, required this.opid});

  /// The shot the strip was tapped on.
  final int initialIndex;

  /// Whose photos these are. Only the label sheet needs it, for the
  /// descriptions this patient's own uploads have used before.
  final int opid;

  @override
  ConsumerState<ShotPreviewScreen> createState() => _ShotPreviewScreenState();
}

class _ShotPreviewScreenState extends ConsumerState<ShotPreviewScreen> {
  /// Asks what this one shot is of, and re-describes only it. Cancelled, it
  /// leaves the label as it was — which is not the same as clearing it, which
  /// the sheet's own Clear does by returning `''`.
  Future<void> _relabel(Shot shot, List<String> suggestions) async {
    final label = await showLabelSheet(
      context,
      initial: shot.label,
      suggestions: suggestions,
    );
    if (label == null || !mounted) return;
    ref.read(captureControllerProvider.notifier).relabel(shot.path, label);
  }

  /// Shots are work the session still owns and the draft list has not seen,
  /// so this asks before throwing one away.
  Future<void> _remove(String path) async {
    final l10n = context.l10n;
    final remove = await showDsDialog(
      context,
      title: l10n.captureRemoveTitle,
      body: l10n.captureRemoveBody,
      confirmLabel: l10n.captureRemove,
      destructive: true,
    );
    if (!remove || !mounted) return;
    await ref.read(captureControllerProvider.notifier).remove(path);
  }

  @override
  Widget build(BuildContext context) {
    final shots = ref.watch(captureControllerProvider.select((s) => s.shots));
    // Watched, not read on tap: the patient's history is a provider this
    // screen depends on for as long as it is up, and reading an autoDispose
    // provider nothing listens to schedules its disposal on the spot.
    final suggestions = ref.watch(descriptionSuggestionsProvider(widget.opid));
    return PhotoViewer(
      photos: [for (final shot in shots) ViewerPhoto(path: shot.path, caption: shot.label)],
      initialIndex: widget.initialIndex,
      // Indexed against the list this build handed over, which is the list the
      // viewer is showing.
      onEditCaption: (index) => _relabel(shots[index], suggestions),
      onRemove: (index) => _remove(shots[index].path),
    );
  }
}
