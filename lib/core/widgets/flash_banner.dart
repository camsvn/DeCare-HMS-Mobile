import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';

enum FlashType { danger, warning, success, info }

OverlayEntry? _current;

/// Top-anchored transient banner, equivalent to react-native-flash-message.
void showFlash(BuildContext context, String message, {FlashType type = FlashType.info}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  _current = null;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlashBanner(
      message: message,
      type: type,
      onDone: () {
        if (_current == entry) _current = null;
        entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _FlashBanner extends StatefulWidget {
  const _FlashBanner({required this.message, required this.type, required this.onDone});

  final String message;
  final FlashType type;
  final VoidCallback onDone;

  @override
  State<_FlashBanner> createState() => _FlashBannerState();
}

class _FlashBannerState extends State<_FlashBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.type) {
        FlashType.danger => AppColors.error,
        FlashType.warning => AppColors.orange,
        FlashType.success => const Color(0xFF2E7D32),
        FlashType.info => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        ),
        child: Material(
          color: _color,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, top + AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
