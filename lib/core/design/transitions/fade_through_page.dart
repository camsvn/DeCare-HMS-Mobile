import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';

/// Fade-through: the incoming page fades in and rises 8 dp; the outgoing
/// page fades out. Collapses to a plain fade under reduced motion.
class FadeThroughPage<T> extends Page<T> {
  const FadeThroughPage({required this.child, super.key, super.name, super.arguments});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _FadeThroughPageRoute<T>(this, context);
}

class _FadeThroughPageRoute<T> extends PageRoute<T> {
  _FadeThroughPageRoute(FadeThroughPage<T> page, BuildContext context)
      : transitionDuration = DsMotion.of(context, DsMotion.base),
        reverseTransitionDuration = DsMotion.of(context, DsMotion.fast),
        super(settings: page);

  /// Read the child through [settings] rather than capturing it, so that a
  /// Page update on the same key swaps the content in place. A shell route
  /// rebuilds its child on every branch switch and would otherwise be frozen
  /// on the first one.
  FadeThroughPage<T> get _page => settings as FadeThroughPage<T>;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(scopesRoute: true, explicitChildNodes: true, child: _page.child);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final fade = CurvedAnimation(parent: animation, curve: DsMotion.curve);
    final rise = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: DsMotion.curve));
    final out = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(parent: secondary, curve: Curves.easeIn));
    Widget result = FadeTransition(opacity: fade, child: child);
    if (!reduce) result = SlideTransition(position: rise, child: result);
    return FadeTransition(opacity: out, child: result);
  }
}
