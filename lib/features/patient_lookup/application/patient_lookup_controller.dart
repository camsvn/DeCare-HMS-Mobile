import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/patient_lookup/application/recent_searches_controller.dart';
import 'package:hms_uploader/features/patient_lookup/data/op_register_api.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';

/// Looks a patient up by OP number. Successful lookups are pushed into recents.
class PatientLookupController extends AutoDisposeAsyncNotifier<Patient?> {
  // Not async: an async build() completes via a scheduled microtask, which
  // can arrive after search() has already set an error/data state and
  // silently overwrite it back to AsyncData(null). Returning a plain value
  // resolves the initial state synchronously, so there is nothing left to
  // race against.
  @override
  Patient? build() => null;

  /// Returns the patient on success, null on failure (state carries the error).
  Future<Patient?> search(int opid) async {
    state = const AsyncLoading<Patient?>().copyWithPrevious(state);
    try {
      final patient = await ref.read(opRegisterApiProvider).getByOpId(opid);
      ref.read(recentSearchesControllerProvider.notifier).add(patient);
      state = AsyncData(patient);
      return patient;
    } catch (e, st) {
      state = AsyncError<Patient?>(e, st).copyWithPrevious(state);
      return null;
    }
  }
}

final patientLookupControllerProvider =
    AsyncNotifierProvider.autoDispose<PatientLookupController, Patient?>(PatientLookupController.new);
