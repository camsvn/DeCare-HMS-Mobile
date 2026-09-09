/// How many non-network failures an entry survives before the queue stops
/// retrying it on its own and waits for the user.
const int maxUploadAttempts = 5;

/// One staged photo inside a [PendingUpload].
class PendingFile {
  const PendingFile({required this.path, required this.description});

  final String path;
  final String description;

  Map<String, dynamic> toJson() => {'path': path, 'description': description};

  factory PendingFile.fromJson(Map<dynamic, dynamic> json) => PendingFile(
        path: (json['path'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
      );
}

/// One upload waiting to reach the server: the patient it belongs to, the
/// staged copies of its photos, and how often it has been refused so far.
class PendingUpload {
  const PendingUpload({
    required this.id,
    required this.opid,
    required this.patientName,
    required this.files,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final int opid;

  /// Shown in the pending-uploads sheet, so the user recognises the entry
  /// without a lookup round trip.
  final String patientName;
  final List<PendingFile> files;
  final DateTime createdAt;
  final int attempts;

  /// The reason the server gave for the last refusal, if any.
  final String? lastError;

  /// Out of automatic retries: only an explicit retry moves this entry again.
  bool get isFailed => attempts >= maxUploadAttempts;

  PendingUpload copyWith({
    List<PendingFile>? files,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
  }) =>
      PendingUpload(
        id: id,
        opid: opid,
        patientName: patientName,
        files: files ?? this.files,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'opid': opid,
        'patientName': patientName,
        'files': files.map((f) => f.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };

  factory PendingUpload.fromJson(Map<dynamic, dynamic> json) => PendingUpload(
        id: (json['id'] ?? '').toString(),
        opid: _int(json['opid']),
        patientName: (json['patientName'] ?? '').toString(),
        files: switch (json['files']) {
          final List<dynamic> list => list.whereType<Map>().map(PendingFile.fromJson).toList(),
          _ => const [],
        },
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        attempts: _int(json['attempts']),
        lastError: json['lastError'] is String ? json['lastError'] as String : null,
      );
}

int _int(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
