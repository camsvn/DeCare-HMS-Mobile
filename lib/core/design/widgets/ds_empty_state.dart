import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

class DsEmptyState extends StatelessWidget {
  const DsEmptyState({super.key, this.illustration, required this.heading, required this.body, this.action});

  final Widget? illustration;
  final String heading;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DsSpace.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              SizedBox(height: 180, child: illustration),
              const SizedBox(height: DsSpace.x6),
            ],
            Text(heading, style: type.heading, textAlign: TextAlign.center),
            const SizedBox(height: DsSpace.x1),
            Text(body, style: type.body.withColor(ds.textSecondary), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: DsSpace.x4), action!],
          ],
        ),
      ),
    );
  }
}
