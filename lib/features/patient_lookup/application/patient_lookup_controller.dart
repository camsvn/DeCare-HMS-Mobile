import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/riverpod/riverpod_compat.dart';
import 'package:hms_uploader/features/patient_lookup/data/op_register_api.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

/// Looks a patient up by OP number. Recents are none of its business: the
/// lookup screen records the patient once the screen it opened is done with it,
/// so the list it is standing on does not reorder mid-tap.
class PatientLookupController extends AsyncNotifier<Patient?> {
  // Not async: an async build() completes via a scheduled microtask, which
  // can arrive after search() has already set an error/data state and
  // silently overwrite it back to AsyncData(null). Returning a plain value
  // resolves the initial state synchronously, so there is nothing left to
  // race against.
  @override
  Patient? build() => null;

  /// Returns the patient on success, null on failure (state carries the error).
  Future<Patient?> search(int opid) async {
    state = const AsyncLoading<Patient?>().keepingPrevious(state);
    try {
      final patient = await ref.read(opRegisterApiProvider).getByOpId(opid);
      // The screen may have gone while the request was out; a disposed
      // notifier's state cannot be written, and nobody is looking anyway.
      if (ref.mounted) state = AsyncData(patient);
      return patient;
    } catch (e, st) {
      if (ref.mounted) state = AsyncError<Patient?>(e, st).keepingPrevious(state);
      return null;
    }
  }
}

final patientLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<PatientLookupController, Patient?>(PatientLookupController.new);
