import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/suggestion_chips.dart';

/// What a description may run to. Long enough for "Left forearm, lateral" and
/// short enough that the server's narration column takes it.
const int labelMaxLength = 200;

/// Asks what the next shots are of.
///
/// Resolves to the description to use — `''` to clear one already set — or to
/// null when the sheet was cancelled or dismissed, which leaves the session's
/// label as it was.
Future<String?> showLabelSheet(
  BuildContext context, {
  required String initial,
  required List<String> suggestions,
}) =>
    showDsSheet<String>(
      context,
      builder: (sheetContext) => [
        _LabelSheet(sheetContext: sheetContext, initial: initial, suggestions: suggestions),
      ],
    );

class _LabelSheet extends ConsumerStatefulWidget {
  const _LabelSheet({
    required this.sheetContext,
    required this.initial,
    required this.suggestions,
  });

  /// The sheet route's own context: what the buttons pop, as `showDsSheet`
  /// asks, rather than the caller's.
  final BuildContext sheetContext;

  final String initial;
  final List<String> suggestions;

  @override
  ConsumerState<_LabelSheet> createState() => _LabelSheetState();
}

class _LabelSheetState extends ConsumerState<_LabelSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _use() => Navigator.of(widget.sheetContext).pop(_controller.text.trim());

  /// A pick fills the field rather than committing: the offered word is often
  /// most of the answer ("Left forearm" → "Left forearm, lateral").
  void _pick(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(offset: suggestion.length);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.dsType;
    final l10n = context.l10n;
    // Which of the offered chips came from this device rather than from the
    // patient's uploads: only those can be un-offered.
    final recent = ref.watch(recentLabelsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x2, DsSpace.gutter, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.captureLabelTitle, style: type.heading),
          const SizedBox(height: DsSpace.x3),
          DsTextField(
            controller: _controller,
            autofocus: true,
            hint: l10n.captureLabelHint,
            maxLength: labelMaxLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _use(),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: DsSpace.x3),
            SuggestionChips(
              suggestions: widget.suggestions,
              onPick: _pick,
              removable: {for (final label in recent) label.toLowerCase()},
              onLongPress: (suggestion) => unawaited(confirmForgetSuggestion(
                context,
                ref.read(recentLabelsProvider.notifier),
                suggestion,
              )),
              wrap: true,
            ),
          ],
          const SizedBox(height: DsSpace.x4),
          // Wrapped rather than a row: three buttons at a large text size
          // would otherwise run off the end of the sheet.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: DsSpace.x2,
            runSpacing: DsSpace.x2,
            children: [
              DsButton.ghost(
                label: l10n.commonCancel,
                onPressed: () => Navigator.of(widget.sheetContext).pop(),
              ),
              // Only for a label there is something to clear: an empty sheet
              // already has "Cancel" for leaving it alone.
              if (widget.initial.isNotEmpty)
                DsButton.ghost(
                  label: l10n.captureLabelClear,
                  onPressed: () => Navigator.of(widget.sheetContext).pop(''),
                ),
              DsButton.primary(label: l10n.captureLabelUse, expand: false, onPressed: _use),
            ],
          ),
        ],
      ),
    );
  }
}
