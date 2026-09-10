import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/description_suggestions.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_controller.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_draft.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/label_sheet.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/photo_viewer.dart';

/// The drafts waiting to upload, in the [PhotoViewer].
///
/// A card shows a photo 16:10 and cropped, which is enough to tell them apart
/// and not enough to check one: this is where the photo is actually looked at,
/// and where its description can be fixed without scrolling back to the card.
class DraftPreviewScreen extends ConsumerStatefulWidget {
  const DraftPreviewScreen({super.key, required this.opid, required this.initialIndex});

  /// Whose drafts these are: the list to show, and whose past narrations the
  /// description sheet offers.
  final int opid;

  /// The card that was tapped to get here.
  final int initialIndex;

  @override
  ConsumerState<DraftPreviewScreen> createState() => _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends ConsumerState<DraftPreviewScreen> {
  TomogramController get _drafts =>
      ref.read(tomogramControllerProvider(widget.opid).notifier);

  /// Asks what this one photo is of. Cancelled, it leaves the description as
  /// it was — which is not the same as clearing it, which the sheet's own
  /// Clear does by returning `''` and hands the photo back to inheriting the
  /// one before it.
  Future<void> _describe(TomogramDraft draft, List<String> suggestions) async {
    final text = await showLabelSheet(
      context,
      initial: draft.description.trim(),
      suggestions: suggestions,
    );
    if (text == null || !mounted) return;
    _drafts.updateDescription(draft.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drafts = ref.watch(tomogramControllerProvider(widget.opid).select((s) => s.drafts));
    // Watched, not read on tap, for the reason the capture screen's own
    // comment gives: an autoDispose provider nothing listens to is disposed
    // the moment it is read.
    final suggestions = ref.watch(descriptionSuggestionsProvider(widget.opid));
    final notifier = _drafts;

    /// A blank description is not nothing here: it uploads with the previous
    /// photo's, and the caption says so rather than offering a label the
    /// photo effectively already has.
    String? hintFor(int i) {
      final inherited = notifier.inheritedDescriptionFor(i);
      return inherited == null ? null : l10n.tomogramSameAsPrevious(inherited);
    }

    return PhotoViewer(
      photos: [
        for (var i = 0; i < drafts.length; i++)
          ViewerPhoto(
            path: drafts[i].filePath,
            caption: drafts[i].description.trim(),
            captionHint: hintFor(i),
          ),
      ],
      initialIndex: widget.initialIndex,
      onEditCaption: (index) => _describe(drafts[index], suggestions),
      // No question asked, as on the card: a draft is a photo the list is
      // still assembling, and its delete has never confirmed.
      onRemove: (index) => notifier.remove(drafts[index].id),
    );
  }
}
