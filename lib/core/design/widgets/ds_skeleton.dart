import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// Shimmering placeholder blocks.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton._({super.key, required this.height, required this.rows});

  factory DsSkeleton.row({Key? key}) => DsSkeleton._(key: key, height: 56, rows: 1);
  factory DsSkeleton.card({Key? key, double height = 120}) => DsSkeleton._(key: key, height: height, rows: 1);

  final double height;
  final int rows;

  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DsMotion.shimmer)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          margin: const EdgeInsets.symmetric(horizontal: DsSpace.gutter, vertical: DsSpace.x1),
          decoration: BoxDecoration(
            borderRadius: DsRadius.mediumAll,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: [ds.borderSubtle, ds.card, ds.borderSubtle],
            ),
          ),
        );
      },
    );
  }
}
