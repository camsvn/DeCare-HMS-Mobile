import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/widgets/ds_list_row.dart';

/// A shimmering placeholder block. It owns no margin: the caller places it,
/// the same way it will place the content that replaces it.
class DsSkeleton extends StatefulWidget {
  const DsSkeleton._({super.key, required this.height});

  /// Stands in for one [DsListRow].
  factory DsSkeleton.row({Key? key}) => DsSkeleton._(key: key, height: DsListRow.height);

  /// Stands in for a card of [height].
  factory DsSkeleton.card({Key? key, double height = 120}) => DsSkeleton._(key: key, height: height);

  final double height;

  @override
  State<DsSkeleton> createState() => _DsSkeletonState();
}

class _DsSkeletonState extends State<DsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DsMotion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Never start the shimmer under reduced motion: it would run forever and
    // pin the frame scheduler.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

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
