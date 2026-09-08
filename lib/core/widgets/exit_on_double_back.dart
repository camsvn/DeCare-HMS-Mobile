import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Double-press back to exit, matching the React Native `useBackButtonHandler`.
class ExitOnDoubleBack extends StatefulWidget {
  const ExitOnDoubleBack({
    super.key,
    required this.child,
    this.exit,
    this.window = const Duration(seconds: 3),
  });

  final Widget child;
  final VoidCallback? exit;
  final Duration window;

  @override
  State<ExitOnDoubleBack> createState() => ExitOnDoubleBackState();
}

class ExitOnDoubleBackState extends State<ExitOnDoubleBack> {
  Timer? _armTimer;
  bool get _armed => _armTimer?.isActive ?? false;

  void handleBack() {
    if (_armed) {
      _armTimer?.cancel();
      _armTimer = null;
      (widget.exit ?? SystemNavigator.pop)();
      return;
    }
    _armTimer = Timer(widget.window, () => _armTimer = null);
    showFlash(context, context.l10n.commonPressBackAgain, type: FlashType.warning);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) handleBack();
      },
      child: widget.child,
    );
  }
}
