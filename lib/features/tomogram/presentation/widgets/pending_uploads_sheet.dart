import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/upload_queue_controller.dart';
import 'package:hms_uploader/features/tomogram/data/pending_upload.dart';

/// The offline queue: one row per waiting upload, with a retry for all of them
/// and a per-row discard.
Future<void> showPendingUploadsSheet(BuildContext context) => showDsSheet<void>(
      context,
      builder: (_) => const [_PendingUploads()],
    );

/// Everything in the sheet that is not a queue row: the drag handle, the
/// heading, the retry footer and the sheet's trailing gap. Subtracted from the
/// height the sheet is allowed so the rows know what is left for them.
const double _sheetChromeHeight = 150;

class _PendingUploads extends ConsumerWidget {
  const _PendingUploads();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ds = context.ds;
    final type = context.dsType;
    final queue = ref.watch(uploadQueueProvider);
    final entries = queue.valueOrNull ?? const <PendingUpload>[];
    final notifier = ref.read(uploadQueueProvider.notifier);

    // showModalBottomSheet caps a sheet like this one at 9/16 of the screen,
    // and the sheet lays its children out with unbounded height, so the row
    // list has to cap itself — an uncapped list pushes the retry footer off
    // the screen as soon as the queue passes a few entries.
    final rowsMaxHeight = (MediaQuery.sizeOf(context).height * 9 / 16 - _sheetChromeHeight)
        .clamp(DsListRow.height, double.infinity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x3, DsSpace.gutter, DsSpace.x2),
          child: Text(l10n.queueTitle, style: type.heading),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: rowsMaxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries) ...[
                  DsListRow(
                    title: entry.patientName,
                    leadingIcon: Icons.cloud_upload_outlined,
                    trailingValue: '${entry.files.length}',
                    trailingIcon: Icons.delete_outline,
                    trailingTooltip: l10n.queueDiscard,
                    destructive: entry.isFailed,
                    onTrailingTap: () => _discard(context, ref, entry),
                  ),
                  if (entry.lastError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.x3, 0, DsSpace.x3, DsSpace.x3),
                      child: Text(
                        l10n.queueFailedLine(entry.attempts, entry.lastError!),
                        style: type.label.withColor(ds.danger),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(DsSpace.gutter),
          child: DsButton.primary(
            label: l10n.queueRetry,
            loading: notifier.isProcessing,
            onPressed: entries.isEmpty ? null : notifier.retryAll,
          ),
        ),
      ],
    );
  }

  Future<void> _discard(BuildContext context, WidgetRef ref, PendingUpload entry) async {
    final l10n = context.l10n;
    final discard = await showDsDialog(
      context,
      title: l10n.queueDiscardTitle,
      body: l10n.queueDiscardBody,
      confirmLabel: l10n.queueDiscard,
      destructive: true,
    );
    if (!discard) return;
    await ref.read(uploadQueueProvider.notifier).discard(entry.id);
  }
}
