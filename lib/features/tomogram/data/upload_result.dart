class UploadResult {
  const UploadResult({required this.id, required this.masterid, required this.tomogrampartid, required this.narration});

  final int id;
  final int masterid;
  final int tomogrampartid;
  final String narration;

  factory UploadResult.fromJson(Map<dynamic, dynamic> json) => UploadResult(
        id: _int(json['id']),
        masterid: _int(json['masterid']),
        tomogrampartid: _int(json['tomogrampartid']),
        narration: (json['narration'] ?? '').toString(),
      );

  static int _int(dynamic v) => v is int ? v : int.tryParse(v.toString()) ?? 0;
}
