import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/design/widgets/ds_card.dart';
import 'package:hms_uploader/core/design/widgets/ds_icon_tile.dart';

/// Dashboard tile for one module.
class ModuleCard extends StatefulWidget {
  const ModuleCard({super.key, required this.icon, required this.title, required this.subtitle, this.badge, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  State<ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: DsMotion.of(context, DsMotion.fast),
        curve: DsMotion.curve,
        // Expand so the card fills its grid cell like its neighbours; a loose
        // stack would shrink-wrap it to its text.
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The merge covers the tappable card, so its title, subtitle and
            // button flag read as one node. The badge floats above it, outside
            // the merge, keeping the node — and the label — of a live value.
            MergeSemantics(
              child: DsCard(
                onTap: widget.onTap,
                padding: const EdgeInsets.all(DsSpace.x3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DsIconTile(icon: widget.icon),
                    const SizedBox(height: DsSpace.x3),
                    Text(widget.title, style: type.heading, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: type.label.withColor(ds.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            if (widget.badge != null)
              Positioned(
                top: DsSpace.x3,
                right: DsSpace.x3,
                // Centred against the icon tile, as when they shared a row.
                // It ignores pointers — the text under a finger would
                // otherwise swallow the card's tap — but keeps its semantics.
                child: IgnorePointer(
                  child: SizedBox(
                    height: DsIconTile.defaultSize,
                    child: Center(child: widget.badge!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dashed tile shown while only one module is registered.
class ModulePlaceholderCard extends StatelessWidget {
  const ModulePlaceholderCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return CustomPaint(
      painter: _DashedBorderPainter(color: ds.borderSubtle, radius: DsRadius.medium),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.x3),
          child: Text(label, style: context.dsType.label.withColor(ds.textSecondary), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, (d + dash).clamp(0, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}
