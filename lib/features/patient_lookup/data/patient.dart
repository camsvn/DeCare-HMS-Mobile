class Patient {
  const Patient({required this.id, required this.opid, required this.name});

  final int id;
  final int opid;
  final String name;

  factory Patient.fromJson(Map<dynamic, dynamic> json) => Patient(
        id: _int(json['id']),
        opid: _int(json['opid']),
        name: (json['name'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'opid': opid, 'name': name};

  static int _int(dynamic v) => v is int ? v : int.parse(v.toString());

  @override
  bool operator ==(Object other) =>
      other is Patient && other.id == id && other.opid == opid && other.name == name;

  @override
  int get hashCode => Object.hash(id, opid, name);

  @override
  String toString() => 'Patient($id, $opid, $name)';
}
