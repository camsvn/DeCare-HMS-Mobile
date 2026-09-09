/// One image inside an uploaded set.
class TomogramSetDetail {
  const TomogramSetDetail({required this.id, required this.tomogramPartId, required this.narration});

  final int id;
  final int tomogramPartId;
  final String narration;

  factory TomogramSetDetail.fromJson(Map<dynamic, dynamic> json) => TomogramSetDetail(
        id: _int(json['id']),
        tomogramPartId: _int(json['tomogramPartId']),
        narration: (json['narration'] ?? '').toString(),
      );
}

/// One upload of a patient's tomogram images, as `GET /tomogram?opid=N`
/// returns it.
class TomogramSet {
  const TomogramSet({
    required this.id,
    required this.dateTime,
    required this.doctorId,
    required this.tomogramTypeId,
    required this.details,
  });

  final int id;
  final DateTime dateTime;
  final int doctorId;
  final int tomogramTypeId;
  final List<TomogramSetDetail> details;

  factory TomogramSet.fromJson(Map<dynamic, dynamic> json) => TomogramSet(
        id: _int(json['id']),
        dateTime: _dateTime(json['dateTime']),
        doctorId: _int(json['doctorId']),
        tomogramTypeId: _int(json['tomogramTypeId']),
        details: switch (json['details']) {
          final List<dynamic> list => list.whereType<Map>().map(TomogramSetDetail.fromJson).toList(),
          _ => const [],
        },
      );

  /// The set's narrations joined for a one-line summary, or null when every
  /// image in the set was uploaded without a description.
  String? get narrationsSummary {
    final texts = details.map((d) => d.narration.trim()).where((n) => n.isNotEmpty);
    return texts.isEmpty ? null : texts.join(' · ');
  }
}

int _int(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;

/// Tolerates an ISO string or an epoch-millisecond number. An unreadable value
/// falls back to the epoch rather than dropping the whole set.
DateTime _dateTime(dynamic v) {
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
