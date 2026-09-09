import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';
import 'package:hms_uploader/core/widgets/app_buttons.dart';
import 'package:hms_uploader/core/widgets/app_header.dart';
import 'package:hms_uploader/core/widgets/flash_banner.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/core/widgets/loader_modal.dart';
import 'package:hms_uploader/features/patient_lookup/application/patient_lookup_controller.dart';
import 'package:hms_uploader/features/patient_lookup/application/recent_searches_controller.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/home_empty_state.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/op_search_bar.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/recent_search_row.dart';

/// Patient lookup: OP number search plus recent searches. [onPatientSelected]
/// fires after a successful lookup (the route wires it to the tomogram screen).
class PatientLookupScreen extends ConsumerStatefulWidget {
  const PatientLookupScreen({super.key, required this.onPatientSelected});

  final ValueChanged<Patient> onPatientSelected;

  @override
  ConsumerState<PatientLookupScreen> createState() => _PatientLookupScreenState();
}

class _PatientLookupScreenState extends ConsumerState<PatientLookupScreen> {
  Future<void> _lookup(int opid) async {
    final patient = await ref.read(patientLookupControllerProvider.notifier).search(opid);
    if (patient != null && mounted) widget.onPatientSelected(patient);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(patientLookupControllerProvider, (prev, next) {
      final error = next.error;
      if (!next.isLoading && next.hasError && error is ApiFailure) {
        showFlash(context, l10n.homePatientError(error.describe(l10n)), type: FlashType.danger);
      }
    });
    final loading = ref.watch(patientLookupControllerProvider).isLoading;
    final recents = ref.watch(recentSearchesControllerProvider);

    // No back-press handling here: this is a StatefulShellRoute branch page, so
    // the system back press goes to the root navigator and AppShell owns it.
    return LoaderModal(
      visible: loading,
      text: l10n.homeFetchingPatient,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            AppHeader(title: l10n.commonHeader),
            Expanded(
              child: recents.isEmpty
                  ? const HomeEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(l10n.homeRecentSearches, style: AppTextStyles.bold),
                            LinkButton(
                              label: l10n.homeClearAll,
                              color: AppColors.dim,
                              onPressed: () => ref.read(recentSearchesControllerProvider.notifier).clear(),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (final p in recents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: RecentSearchRow(
                              patient: p,
                              onTap: () => _lookup(p.opid),
                              onDelete: () => ref.read(recentSearchesControllerProvider.notifier).remove(p.id),
                            ),
                          ),
                      ],
                    ),
            ),
            OpSearchBar(onSubmit: _lookup),
          ],
        ),
      ),
    );
  }
}
