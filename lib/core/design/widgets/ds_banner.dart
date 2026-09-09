import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

enum DsBannerKind { success, warning, danger, info }

/// Queued top banners: each shows for 2.5 s, then the next one plays.
void showDsBanner(BuildContext context, String message, {DsBannerKind kind = DsBannerKind.info}) {
  _DsBannerQueue.instance.enqueue(Overlay.of(context, rootOverlay: true), message, kind);
}

/// The queue is a process-wide singleton, so a banner left mid-flight by one
/// test would suppress the next test's banners. Widget tests reset it first.
@visibleForTesting
void resetDsBannersForTest() => _DsBannerQueue.instance.resetForTest();

class _DsBannerQueue {
  _DsBannerQueue._();
  static final instance = _DsBannerQueue._();

  final Queue<(OverlayState, String, DsBannerKind)> _pending = Queue();
  bool _showing = false;

  @visibleForTesting
  void resetForTest() {
    _pending.clear();
    _showing = false;
  }

  void enqueue(OverlayState overlay, String message, DsBannerKind kind) {
    _pending.add((overlay, message, kind));
    _next();
  }

  void _next() {
    if (_showing || _pending.isEmpty) return;
    final (overlay, message, kind) = _pending.removeFirst();
    if (!overlay.mounted) return _next();
    _showing = true;
    late OverlayEntry entry;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      if (entry.mounted) entry.remove();
      _showing = false;
      _next();
    }

    entry = OverlayEntry(
      builder: (_) => _DsBannerView(
        message: message,
        kind: kind,
        onDone: release,
      ),
    );
    overlay.insert(entry);
  }
}

class _DsBannerView extends StatefulWidget {
  const _DsBannerView({required this.message, required this.kind, required this.onDone});

  final String message;
  final DsBannerKind kind;
  final VoidCallback onDone;

  @override
  State<_DsBannerView> createState() => _DsBannerViewState();
}

class _DsBannerViewState extends State<_DsBannerView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DsMotion.base);
  Timer? _dismiss;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismiss = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _controller.dispose();
    scheduleMicrotask(widget.onDone);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final (color, icon) = switch (widget.kind) {
      DsBannerKind.success => (ds.success, Icons.check_circle_outline),
      DsBannerKind.warning => (ds.warning, Icons.warning_amber_outlined),
      DsBannerKind.danger => (ds.danger, Icons.error_outline),
      DsBannerKind.info => (ds.shellRaised, Icons.info_outline),
    };
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: DsMotion.curve)),
        child: Material(
          color: color,
          child: Padding(
            padding: EdgeInsets.fromLTRB(DsSpace.gutter, top + DsSpace.x3, DsSpace.gutter, DsSpace.x3),
            child: Row(
              children: [
                Icon(icon, color: ds.textOnShell, size: 20),
                const SizedBox(width: DsSpace.x3),
                Expanded(child: Text(widget.message, style: context.dsType.body.withColor(ds.textOnShell))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
