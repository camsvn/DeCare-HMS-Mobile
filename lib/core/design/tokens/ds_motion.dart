import 'package:flutter/widgets.dart';

abstract final class DsMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
  static const Duration shimmer = Duration(milliseconds: 1200);
  static const Duration stagger = Duration(milliseconds: 30);

  /// Collapses any duration to [fast] when the OS asks for reduced motion.
  static Duration resolve(Duration duration, {required bool disableAnimations}) =>
      disableAnimations ? fast : duration;

  static Duration of(BuildContext context, Duration duration) =>
      resolve(duration, disableAnimations: MediaQuery.disableAnimationsOf(context));
}
