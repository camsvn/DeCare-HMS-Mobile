import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';

void main() {
  test('json round trip and equality', () {
    const p = Patient(id: 1, opid: 123, name: 'Jane');
    expect(Patient.fromJson(p.toJson()), p);
    expect(Patient.fromJson({'id': 1, 'opid': 123, 'name': 'Jane', 'extra': true}), p);
  });
  test('fromJson tolerates numeric strings', () {
    expect(Patient.fromJson({'id': '1', 'opid': '7', 'name': 'x'}), const Patient(id: 1, opid: 7, name: 'x'));
  });
}
