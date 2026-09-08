class TomogramDraft {
  const TomogramDraft({required this.id, required this.filePath, this.description = ''});

  final String id;
  final String filePath;
  final String description;

  TomogramDraft copyWith({String? description}) =>
      TomogramDraft(id: id, filePath: filePath, description: description ?? this.description);
}
