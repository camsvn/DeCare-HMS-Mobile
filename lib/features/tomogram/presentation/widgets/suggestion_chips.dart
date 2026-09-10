import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/tomogram/application/recent_labels_controller.dart';

/// Asks whether to stop offering [suggestion] on this device, and forgets it
/// when the answer is yes.
///
/// Shared by every place chips are shown, so the question is worded once and
/// the answer means the same thing everywhere.
Future<void> confirmForgetSuggestion(
  BuildContext context,
  RecentLabelsController labels,
  String suggestion,
) async {
  final l10n = context.l10n;
  final forget = await showDsDialog(
    context,
    title: l10n.suggestionForgetTitle,
    body: l10n.suggestionForgetBody,
    confirmLabel: l10n.suggestionForget,
    destructive: true,
  );
  if (!forget) return;
  await labels.forget(suggestion);
}

/// The smallest a thumb should have to hit. A chip is drawn smaller than this;
/// its tap target is not.
const double _chipTapTarget = 44;

/// Descriptions worth offering, newest first, as a row of chips that fill a
/// field when picked.
///
/// It knows nothing about where the list came from or what the picked text is
/// for: the capture screen's label sheet and the draft list's cards both hand
/// it a list and a callback.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({
    super.key,
    required this.suggestions,
    required this.onPick,
    this.onLongPress,
    this.removable = const {},
    this.wrap = false,
    this.onShell = false,
  });

  final List<String> suggestions;

  /// The chip that was tapped. Filling a field rather than submitting one:
  /// the picked text is a starting point, not an answer.
  final ValueChanged<String> onPick;

  /// [Wrap] rather than a scrolling row, for a sheet where the chips have the
  /// width to sit on two lines and nothing to scroll against.
  final bool wrap;

  /// Chips styled for the camera's shell rather than a card.
  final bool onShell;

  /// A chip was held down. Only ever called for a [removable] one.
  final ValueChanged<String>? onLongPress;

  /// Which suggestions this device could stop offering, lower-cased — its own
  /// recent labels. The patient's uploaded narrations are not among them:
  /// they are what the server says, and nothing here can unsay it.
  final Set<String> removable;

  @override
  Widget build(BuildContext context) {
    // No row at all when there is nothing to offer: an empty "Suggestions"
    // group is a promise the screen cannot keep.
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final chips = [for (final suggestion in suggestions) _chip(suggestion)];
    return Semantics(
      container: true,
      header: true,
      label: context.l10n.tomogramSuggestions,
      child: wrap
          ? Wrap(spacing: DsSpace.x2, runSpacing: DsSpace.x2, children: chips)
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: DsSpace.x2),
                    chips[i],
                  ],
                ],
              ),
            ),
    );
  }

  Widget _chip(String suggestion) {
    final onLongPress = this.onLongPress;
    final canForget = onLongPress != null && removable.contains(suggestion.toLowerCase());
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(DsRadius.full),
        onTap: () => onPick(suggestion),
        onLongPress: canForget ? () => onLongPress(suggestion) : null,
        // A chip is a small thing to draw and a normal thing to hit: the
        // target grows to 44 dp with the chip centred inside it.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _chipTapTarget),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: DsChip(text: suggestion, onShell: onShell),
          ),
        ),
      ),
    );
  }
}
