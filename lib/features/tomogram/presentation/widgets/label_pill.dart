import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// The icon's side. Not a token: it is sized to the label text beside it
/// rather than to the icon scale, so the pill reads as one word with a mark.
const double _pillIconSize = 16;

/// The smallest a thumb should have to hit. The pill draws smaller than this
/// so it does not crowd the shutter row; its tap target does not.
const double _pillTapTarget = 44;

/// The × as drawn: the height of the pill beside it, so the two read as one
/// control rather than a control and a button that wandered in.
const double _pillClearSize = 28;

/// The pill's text half — the one that opens the sheet. Keyed so a test can
/// tap and measure it without going through the × next to it.
@visibleForTesting
const Key labelPillTextKey = Key('label-pill-text');

/// The pill's × . Keyed for the same reason, and absent when there is no
/// label to clear.
@visibleForTesting
const Key labelPillClearKey = Key('label-pill-clear');

/// The capture screen's label, as a pill above the shutter row: what the next
/// shots will be described as, and the way to change or drop it.
///
/// It is on the camera rather than in a form afterwards because the person
/// holding the phone is the one who knows which part they are photographing.
/// The copy names the photos it applies to — the ones not taken yet — because
/// "Add a label" left it to be guessed which photos a label would land on.
class LabelPill extends StatelessWidget {
  const LabelPill({
    super.key,
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  /// The session's label; `''` when the shots are going out undescribed.
  final String label;

  /// Opens the sheet, to set or change the label.
  final VoidCallback onTap;

  /// Drops the label on the spot. Its own control, because "these next ones
  /// are of nothing in particular" is a whole thought and should not need a
  /// sheet, a Clear and a dismiss.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final empty = label.isEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flexible, not the bare pill: a long description ellipsises inside
        // the row rather than pushing the × off the end of the panel.
        Flexible(child: _text(context, empty)),
        if (!empty) ...[
          const SizedBox(width: DsSpace.x1),
          _clear(context),
        ],
      ],
    );
  }

  Widget _text(BuildContext context, bool empty) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final text = empty ? l10n.captureLabelNext : l10n.captureNextPhotos(label);
    return Semantics(
      key: labelPillTextKey,
      container: true,
      button: true,
      label: text,
      // The action, not only the words: the node replaces everything under it,
      // so without this a reader is handed a button it cannot press.
      onTap: onTap,
      // The pill spells its state out in words the reader already has; the
      // text inside it would say the same thing a second time.
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(DsRadius.full),
        onTap: onTap,
        // The target is the thumb's, the pill is the eye's: the box grows to
        // 44 dp and centres the smaller pill inside it.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _pillTapTarget),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.x3, vertical: DsSpace.x2),
              decoration: BoxDecoration(
                color: ds.shellRaised,
                borderRadius: BorderRadius.circular(DsRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    empty ? Icons.label_outline : Icons.edit_outlined,
                    size: _pillIconSize,
                    color: empty ? ds.textOnShellMuted : ds.accentSolid,
                  ),
                  const SizedBox(width: DsSpace.x2),
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.withColor(empty ? ds.textOnShellMuted : ds.textOnShell),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _clear(BuildContext context) {
    final ds = context.ds;
    final l10n = context.l10n;
    return Semantics(
      key: labelPillClearKey,
      container: true,
      button: true,
      label: l10n.captureLabelClear,
      onTap: onClear,
      excludeSemantics: true,
      child: Tooltip(
        message: l10n.captureLabelClear,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onClear,
          // Same bargain as the pill: drawn at the pill's height, hit at the
          // thumb's.
          child: SizedBox.square(
            dimension: _pillTapTarget,
            child: Center(
              child: Container(
                width: _pillClearSize,
                height: _pillClearSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: ds.shellRaised, shape: BoxShape.circle),
                child: Icon(Icons.close, size: _pillIconSize, color: ds.textOnShellMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
