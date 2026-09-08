import 'package:flutter/widgets.dart';

/// Whether the soft keyboard is up.
///
/// Read straight off the [FlutterView] rather than through [MediaQuery]: a
/// [Scaffold] strips the bottom view inset from the MediaQuery it hands its
/// body, so `MediaQuery.viewInsetsOf(context).bottom` is always 0 for widgets
/// inside a Scaffold body. The view insets are in physical pixels; only the
/// `> 0` test matters here.
bool isKeyboardVisible(BuildContext context) => View.of(context).viewInsets.bottom > 0;

/// Renders [child] only while the soft keyboard is hidden.
///
/// Rebuilds from [didChangeMetrics] rather than from a [MediaQuery] dependency:
/// a [Scaffold] both zeroes the bottom view inset for its body's MediaQuery and
/// leaves that MediaQueryData unchanged when the keyboard opens, so a
/// MediaQuery-driven rebuild never arrives inside a Scaffold body.
class HideWithKeyboard extends StatefulWidget {
  const HideWithKeyboard({super.key, required this.child});

  final Widget child;

  @override
  State<HideWithKeyboard> createState() => _HideWithKeyboardState();
}

class _HideWithKeyboardState extends State<HideWithKeyboard> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isKeyboardVisible(context) ? const SizedBox.shrink() : widget.child,
    );
  }
}
