import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';

/// The Tomogram dashboard card's badge: how many patients the module
/// remembers, or nothing at all when it remembers none.
class RecentCountBadge extends ConsumerWidget {
  const RecentCountBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(recentSearchesControllerProvider).length;
    if (count == 0) return const SizedBox.shrink();
    return DsChip(text: '$count', mono: true);
  }
}
