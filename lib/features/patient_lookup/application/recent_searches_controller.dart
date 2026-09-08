import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:hms_uploader/features/patient_lookup/data/recent_searches_repository.dart';

const int recentSearchesCap = 10;

class RecentSearchesController extends Notifier<List<Patient>> {
  @override
  List<Patient> build() => ref.watch(recentSearchesRepositoryProvider).read();

  void add(Patient patient) {
    final next = [patient, ...state.where((p) => p.id != patient.id)];
    _set(next.length > recentSearchesCap ? next.sublist(0, recentSearchesCap) : next);
  }

  void remove(int id) => _set(state.where((p) => p.id != id).toList());

  void clear() => _set(const []);

  void _set(List<Patient> next) {
    state = next;
    ref.read(recentSearchesRepositoryProvider).write(next);
  }
}

final recentSearchesControllerProvider =
    NotifierProvider<RecentSearchesController, List<Patient>>(RecentSearchesController.new);
