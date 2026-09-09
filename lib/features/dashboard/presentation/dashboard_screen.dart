import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/dashboard/presentation/widgets/context_strip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.modules, this.onOpenModule});

  final List<AppModule> modules;

  /// Defaults to `context.push(entryRoute)`. Injectable for tests.
  final void Function(BuildContext context, AppModule module)? onOpenModule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.dsType;
    final open = onOpenModule ?? (ctx, m) => ctx.push(m.entryRoute);
    return Scaffold(
      appBar: DsAppBar(title: l10n.appTitle, automaticallyImplyLeading: false),
      body: Column(
        children: [
          const ContextStrip(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(DsSpace.gutter),
              children: [
                Text(l10n.dashboardModules, style: type.heading),
                const SizedBox(height: DsSpace.x3),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: DsSpace.x3,
                  crossAxisSpacing: DsSpace.x3,
                  childAspectRatio: 1.15,
                  children: [
                    for (var i = 0; i < modules.length; i++)
                      _Staggered(
                        index: i,
                        child: ModuleCard(
                          icon: modules[i].icon,
                          title: modules[i].title(l10n),
                          subtitle: modules[i].subtitle(l10n),
                          badge: modules[i].badge?.call(ref),
                          onTap: () => open(context, modules[i]),
                        ),
                      ),
                    if (modules.length == 1) ModulePlaceholderCard(label: l10n.dashboardMorePlaceholder),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and rises a child in, delayed by its index. Runs once per mount.
class _Staggered extends StatefulWidget {
  const _Staggered({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Staggered> createState() => _StaggeredState();
}

class _StaggeredState extends State<_Staggered> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery is only readable from here on, so the reduced-motion-aware
    // duration and the staggered start are both set up once dependencies land.
    _c.duration = DsMotion.of(context, DsMotion.base);
    if (_start != null) return;
    _start = Timer(DsMotion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: DsMotion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}
