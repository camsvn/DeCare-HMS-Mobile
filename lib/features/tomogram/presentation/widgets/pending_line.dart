import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/upload_queue_controller.dart';

/// One line telling the user this patient still has photos in the offline
/// queue, so the empty draft list below it does not read as lost work.
///
/// Owns its outer gutter and collapses to nothing when there is no queued
/// entry, so the tomogram screen keeps no gap for it.
class PendingLine extends ConsumerWidget {
  const PendingLine({super.key, required this.opid});

  final int opid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(pendingForOpidProvider(opid));
    if (entry == null) return const SizedBox.shrink();
    final ds = context.ds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x3, DsSpace.gutter, 0),
      child: DsCard(
        padding: const EdgeInsets.symmetric(horizontal: DsSpace.cardPadding, vertical: DsSpace.x3),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined, size: 20, color: ds.textSecondary),
            const SizedBox(width: DsSpace.x3),
            Expanded(
              child: Text(
                context.l10n.tomogramPendingLine(entry.files.length),
                style: context.dsType.body.withColor(ds.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
