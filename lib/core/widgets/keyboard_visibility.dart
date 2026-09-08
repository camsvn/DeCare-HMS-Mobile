import 'package:flutter/widgets.dart';

bool isKeyboardVisible(BuildContext context) => MediaQuery.viewInsetsOf(context).bottom > 0;

/// Renders [child] only while the soft keyboard is hidden.
class HideWithKeyboard extends StatelessWidget {
  const HideWithKeyboard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isKeyboardVisible(context) ? const SizedBox.shrink() : child,
    );
  }
}
