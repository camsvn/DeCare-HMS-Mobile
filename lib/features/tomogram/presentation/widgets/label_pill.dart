import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// The icon's side. Not a token: it is sized to the label text beside it
/// rather than to the icon scale, so the pill reads as one word with a mark.
const double _pillIconSize = 16;

/// The smallest a thumb should have to hit. The pill draws smaller than this
/// so it does not crowd the shutter row; its tap target does not.
const double _pillTapTarget = 44;

/// The capture screen's label, as a pill above the shutter row: what the next
/// shots will be described as, and the way to change it.
///
/// It is on the camera rather than in a form afterwards because the person
/// holding the phone is the one who knows which part they are photographing.
class LabelPill extends StatelessWidget {
  const LabelPill({super.key, required this.label, required this.onTap});

  /// The session's label; `''` when the shots are going out undescribed.
  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    final empty = label.isEmpty;
    return Semantics(
      container: true,
      button: true,
      label: empty ? l10n.captureAddLabel : l10n.captureLabelled(label),
      // The action, not only the words: the node replaces everything under it,
      // so without this a reader is handed a button it cannot press.
      onTap: onTap,
      // The pill spells its state out in words the reader already has; the
      // text inside it would say the label a second time, without the
      // "Labelled" that makes it mean something.
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
                  // Flexible, not fixed: a long description ellipsises rather
                  // than pushing the pill past the panel it sits in.
                  Flexible(
                    child: Text(
                      empty ? l10n.captureAddLabel : label,
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
}
