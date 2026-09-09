import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/patient_lookup/application/patient_lookup_controller.dart';
import 'package:hms_uploader/features/patient_lookup/application/recent_searches_controller.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:hms_uploader/features/patient_lookup/presentation/widgets/op_search_bar.dart';

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
    // One lookup at a time: a second tap on Go or on a recent row would
    // otherwise fire a second request and push the tomogram route twice.
    if (ref.read(patientLookupControllerProvider).isLoading) return;
    final patient = await ref.read(patientLookupControllerProvider.notifier).search(opid);
    if (patient != null && mounted) widget.onPatientSelected(patient);
  }

  void _remove(int id) => ref.read(recentSearchesControllerProvider.notifier).remove(id);

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final type = context.dsType;
    final l10n = context.l10n;
    ref.listen(patientLookupControllerProvider, (prev, next) {
      final error = next.error;
      if (!next.isLoading && next.hasError && error is ApiFailure) {
        showDsBanner(context, l10n.homePatientError(error.describe(l10n)), kind: DsBannerKind.danger);
      }
    });
    final loading = ref.watch(patientLookupControllerProvider).isLoading;
    final recents = ref.watch(recentSearchesControllerProvider);

    // No back-press handling here: this is a StatefulShellRoute branch page, so
    // the system back press goes to the root navigator and AppShell owns it.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: DsAppBar(title: l10n.tomogramModuleTitle),
      body: Column(
        children: [
          OpSearchBar(onSubmit: _lookup, busy: loading),
          Expanded(
            child: loading
                ? ListView(
                    padding: const EdgeInsets.only(top: DsSpace.x2),
                    children: [DsSkeleton.row(), DsSkeleton.row(), DsSkeleton.row()],
                  )
                : recents.isEmpty
                    ? DsEmptyState(
                        illustration: SvgPicture.asset('assets/images/blank_canvas.svg'),
                        heading: l10n.homeEmptyTitle,
                        body: l10n.homeEmptyBody,
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.gutter, 0, DsSpace.gutter, DsSpace.x8),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.homeRecent, style: type.heading),
                              DsButton.ghost(
                                label: l10n.homeClear,
                                onPressed: () => ref.read(recentSearchesControllerProvider.notifier).clear(),
                              ),
                            ],
                          ),
                          const SizedBox(height: DsSpace.x2),
                          DsCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                for (final p in recents) ...[
                                  Dismissible(
                                    key: ValueKey('recent-${p.id}'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      color: ds.danger,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: DsSpace.x4),
                                      child: Icon(Icons.delete_outline, color: ds.textOnShell),
                                    ),
                                    onDismissed: (_) => _remove(p.id),
                                    child: DsListRow(
                                      leadingIcon: Icons.person_outline,
                                      title: p.name,
                                      trailingValue: '${p.opid}',
                                      trailingIcon: Icons.delete_outline,
                                      trailingTooltip: l10n.homeRemoveRecent,
                                      onTrailingTap: () => _remove(p.id),
                                      onTap: () => _lookup(p.opid),
                                    ),
                                  ),
                                  if (p != recents.last) Divider(height: 1, color: ds.borderSubtle),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
