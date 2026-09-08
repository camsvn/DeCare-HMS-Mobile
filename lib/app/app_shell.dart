import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/app/tab_bar.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';

/// Hosts the two tab branches under the custom tab bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: HideWithKeyboard(
        child: AppTabBar(currentIndex: navigationShell.currentIndex, onTap: _goBranch),
      ),
    );
  }
}
