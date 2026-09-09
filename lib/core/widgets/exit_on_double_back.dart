import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hms_uploader/core/design/widgets/ds_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Double-press back to exit, matching the React Native `useBackButtonHandler`.
///
/// By default this installs its own [PopScope], which works only where the
/// widget sits directly under the navigator that receives the back press (the
/// root routes: Login and Configure). Inside a `StatefulShellRoute` branch the
/// back press is delivered to the ROOT navigator, so the branch page's own
/// [PopScope] is never consulted; there, set [interceptPop] to false and have
/// the shell's [PopScope] call [ExitOnDoubleBackState.handleBack] instead.
class ExitOnDoubleBack extends StatefulWidget {
  const ExitOnDoubleBack({
    super.key,
    required this.child,
    this.exit,
    this.window = const Duration(seconds: 3),
    this.interceptPop = true,
  });

  final Widget child;
  final VoidCallback? exit;
  final Duration window;

  /// When false, no [PopScope] is installed and the caller drives
  /// [ExitOnDoubleBackState.handleBack] itself.
  final bool interceptPop;

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
    showDsBanner(context, context.l10n.commonPressBackAgain, kind: DsBannerKind.warning);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.interceptPop) return widget.child;
    // Only arm the double press where there is nothing to go back to. Configure
    // pushed from Login has a route below it and should just pop.
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvoked: (didPop) {
        if (!didPop) handleBack();
      },
      child: widget.child,
    );
  }
}
