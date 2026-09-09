import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';

/// 3 dp indeterminate bar painted with the accent gradient.
class DsProgressBar extends StatefulWidget {
  const DsProgressBar({super.key});

  @override
  State<DsProgressBar> createState() => _DsProgressBarState();
}

class _DsProgressBarState extends State<DsProgressBar> with SingleTickerProviderStateMixin {
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
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth * 0.35;
            final x = -w + (c.maxWidth + w) * _controller.value;
            return Stack(
              children: [
                Container(color: ds.borderSubtle),
                Positioned(
                  left: x,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: ds.accentGradient)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
