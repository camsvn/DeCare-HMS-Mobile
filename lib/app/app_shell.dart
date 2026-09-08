import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/tab_bar.dart';
import 'package:hms_uploader/core/widgets/exit_on_double_back.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';

/// Hosts the two tab branches under the custom tab bar.
///
/// The shell owns the back-press handling for both branches: go_router routes a
/// system back press to the ROOT navigator whenever the active branch navigator
/// cannot pop, so a [PopScope] inside a branch page is never consulted. Off the
/// first tab, back returns to it (react-navigation's `firstRoute` behaviour);
/// on the first tab, back arms double-press-to-exit.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _exitKey = GlobalKey<ExitOnDoubleBackState>();

  void _goBranch(int index) => widget.navigationShell
      .goBranch(index, initialLocation: index == widget.navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          _goBranch(0);
          return;
        }
        _exitKey.currentState?.handleBack();
      },
      child: ExitOnDoubleBack(
        key: _exitKey,
        interceptPop: false,
        child: Scaffold(
          body: widget.navigationShell,
          bottomNavigationBar: HideWithKeyboard(
            child: AppTabBar(currentIndex: widget.navigationShell.currentIndex, onTap: _goBranch),
          ),
        ),
      ),
    );
  }
}
