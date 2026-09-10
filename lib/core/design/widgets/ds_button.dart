import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

enum DsButtonVariant { primary, secondary, ghost, destructive }

/// Button with four variants, inline loading state and a 0.98 press scale.
class DsButton extends StatefulWidget {
  const DsButton._({
    super.key,
    required this.variant,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
    this.icon,
    this.height = 44,
  });

  const DsButton.primary({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.primary, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.secondary({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.secondary, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.ghost({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = false, IconData? icon, double height = 40})
      : this._(key: key, variant: DsButtonVariant.ghost, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);
  const DsButton.destructive({Key? key, required String label, required VoidCallback? onPressed, bool loading = false, bool expand = true, IconData? icon, double height = 44})
      : this._(key: key, variant: DsButtonVariant.destructive, label: label, onPressed: onPressed, loading: loading, expand: expand, icon: icon, height: height);

  final DsButtonVariant variant;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;
  final IconData? icon;
  final double height;

  @override
  State<DsButton> createState() => _DsButtonState();
}

class _DsButtonState extends State<DsButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;

    final Color fg;
    final Color? bg;
    final Gradient? gradient;
    final Border? border;
    switch (widget.variant) {
      case DsButtonVariant.primary:
        fg = ds.textOnShell;
        bg = null;
        gradient = ds.accentGradient;
        border = null;
      case DsButtonVariant.secondary:
        fg = ds.textPrimary;
        bg = ds.card;
        gradient = null;
        border = Border.all(color: ds.borderSubtle);
      case DsButtonVariant.ghost:
        fg = ds.accentText;
        bg = null;
        gradient = null;
        border = null;
      case DsButtonVariant.destructive:
        fg = ds.textOnShell;
        bg = ds.danger;
        gradient = null;
        border = null;
    }

    final child = widget.loading
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: DsSpace.x2)],
              Text(widget.label, style: type.body.copyWith(fontWeight: FontWeight.w600, color: fg)),
            ],
          );

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        child: GestureDetector(
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? 0.98 : 1,
            duration: DsMotion.of(context, DsMotion.fast),
            curve: DsMotion.curve,
            child: Opacity(
              opacity: _enabled || widget.loading ? 1 : 0.5,
              child: Container(
                height: widget.height,
                width: widget.expand ? double.infinity : null,
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.x4),
                // A Container with an alignment grows to its constraints, which
                // would stretch a non-expanding button across a bounded parent;
                // only the expanding variant centres its label that way.
                alignment: widget.expand ? Alignment.center : null,
                decoration: BoxDecoration(
                  color: bg,
                  gradient: gradient,
                  border: border,
                  borderRadius: DsRadius.smallAll,
                ),
                // Non-expanding: shrink-wrap the width but still centre the
                // label vertically inside the fixed height.
                child: widget.expand ? child : Center(widthFactor: 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
