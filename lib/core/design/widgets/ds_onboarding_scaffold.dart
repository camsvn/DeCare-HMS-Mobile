import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_motion.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Navy brand area on top, white card rising from below. Shared by the
/// Configure URL and Login screens so they read as one flow.
class DsOnboardingScaffold extends StatefulWidget {
  const DsOnboardingScaffold({super.key, required this.card});

  final Widget card;

  @override
  State<DsOnboardingScaffold> createState() => _DsOnboardingScaffoldState();
}

class _DsOnboardingScaffoldState extends State<DsOnboardingScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: DsMotion.slow)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final curved = CurvedAnimation(parent: _c, curve: DsMotion.curve);
    return Scaffold(
      backgroundColor: ds.shell,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpace.x8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/images/hms_circle.svg', width: 72, height: 72),
                  const SizedBox(width: DsSpace.x4),
                  Text(context.l10n.appTitle, style: type.display.withColor(ds.textOnShell)),
                ],
              ),
            ),
            Expanded(
              child: SlideTransition(
                position: reduce
                    ? const AlwaysStoppedAnimation(Offset.zero)
                    : Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
                child: FadeTransition(
                  opacity: reduce ? const AlwaysStoppedAnimation(1) : curved,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ds.card,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(DsRadius.sheet)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(DsSpace.x6, DsSpace.x6, DsSpace.x6, DsSpace.x8),
                      child: widget.card,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
