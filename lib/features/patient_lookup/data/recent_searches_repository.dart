import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/patient_lookup/data/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesRepository {
  RecentSearchesRepository(this._prefs);

  static const _key = 'recent_searches';
  final SharedPreferences _prefs;

  List<Patient> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.whereType<Map>().map(Patient.fromJson).toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<Patient> patients) =>
      _prefs.setString(_key, jsonEncode(patients.map((p) => p.toJson()).toList()));
}

final recentSearchesRepositoryProvider = Provider<RecentSearchesRepository>(
  (ref) => RecentSearchesRepository(ref.watch(sharedPreferencesProvider)),
);
