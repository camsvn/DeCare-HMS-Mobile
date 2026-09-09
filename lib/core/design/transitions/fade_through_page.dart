import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';

/// Fade-through: the incoming page fades in and rises 8 dp; the outgoing
/// page fades out. Collapses to a plain fade under reduced motion.
class FadeThroughPage<T> extends Page<T> {
  const FadeThroughPage({required this.child, super.key, super.name, super.arguments});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      transitionDuration: DsMotion.of(context, DsMotion.base),
      reverseTransitionDuration: DsMotion.of(context, DsMotion.fast),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (context, animation, secondary, child) {
        final reduce = MediaQuery.disableAnimationsOf(context);
        final fade = CurvedAnimation(parent: animation, curve: DsMotion.curve);
        final rise = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: DsMotion.curve));
        final out = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: secondary, curve: Curves.easeIn));
        Widget result = FadeTransition(opacity: fade, child: child);
        if (!reduce) result = SlideTransition(position: rise, child: result);
        return FadeTransition(opacity: out, child: result);
      },
    );
  }
}
