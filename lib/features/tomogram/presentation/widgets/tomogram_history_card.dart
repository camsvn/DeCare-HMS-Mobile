import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/tomogram_history_controller.dart';
import 'package:hms_uploader/features/tomogram/data/tomogram_set.dart';
import 'package:intl/intl.dart';

final DateFormat _dateFormat = DateFormat('d MMM HH:mm');

String _formatDate(DateTime dateTime) => _dateFormat.format(dateTime.toLocal());

/// How many sets the expanded card lists. The card sits in the tomogram
/// screen's non-scrolling [Column], directly above the `Expanded` draft list,
/// so an uncapped list would push that list to zero height and overflow the
/// viewport. The collapsed chip still carries the full count.
const int historyExpandedMax = 5;

/// The sets already uploaded for a patient: a count and the last upload date,
/// expanding to one row per set.
///
/// Owns its outer gutter so that a patient with no history collapses the space
/// entirely rather than leaving a gap above the draft list.
class TomogramHistoryCard extends ConsumerStatefulWidget {
  const TomogramHistoryCard({super.key, required this.opid});

  final int opid;

  @override
  ConsumerState<TomogramHistoryCard> createState() => _TomogramHistoryCardState();
}

class _TomogramHistoryCardState extends ConsumerState<TomogramHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ref.watch(tomogramHistoryProvider(widget.opid)).when(
          loading: () => _shell(child: DsSkeleton.row()),
          error: (_, _) => _shell(
            child: Text(
              context.l10n.tomogramHistoryError,
              style: context.dsType.body.withColor(context.ds.textSecondary),
            ),
          ),
          // Only the loaded card is tappable: there is nothing to expand while
          // it is loading or has failed, so it must not offer ink either.
          data: (sets) => sets.isEmpty
              ? const SizedBox.shrink()
              : _shell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: _body(sets),
                ),
        );
  }

  Widget _shell({required Widget child, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x3, DsSpace.gutter, 0),
        child: DsCard(onTap: onTap, child: child),
      );

  Widget _body(List<TomogramSet> sets) {
    final l10n = context.l10n;
    final ds = context.ds;
    final type = context.dsType;
    return AnimatedSize(
      duration: DsMotion.of(context, DsMotion.base),
      curve: DsMotion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DsIconTile(icon: Icons.history, size: 32),
              const SizedBox(width: DsSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tomogramHistoryTitle, style: type.heading),
                    Text(
                      l10n.tomogramHistoryLast(_formatDate(sets.first.dateTime)),
                      style: type.label.withColor(ds.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.x2),
              DsChip(text: l10n.tomogramHistoryCount(sets.length), mono: true),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: ds.textSecondary),
            ],
          ),
          if (_expanded) ...[
            for (final set in sets.take(historyExpandedMax)) ...[
              const SizedBox(height: DsSpace.x3),
              _SetRow(set: set),
            ],
            if (sets.length > historyExpandedMax) ...[
              const SizedBox(height: DsSpace.x3),
              Text(
                l10n.tomogramHistoryMore(sets.length - historyExpandedMax),
                style: type.label.withColor(ds.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.set});

  final TomogramSet set;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_formatDate(set.dateTime), style: type.mono.withColor(ds.textSecondary)),
        const SizedBox(width: DsSpace.x3),
        Expanded(
          child: Text(
            set.narrationsSummary ?? context.l10n.tomogramHistoryNoNarration,
            style: type.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
