/// One photo taken in a capture session: the file the camera wrote, and the
/// description it was taken under.
///
/// The label rides with the shot rather than being applied afterwards: the
/// person holding the camera knows which part they just photographed, and the
/// draft list picks the label up as the photo's description.
class Shot {
  const Shot({required this.path, this.label = ''});

  /// The captured JPEG's path.
  final String path;

  /// The description this shot was taken under; `''` when it was taken
  /// without one.
  final String label;

  Shot copyWith({String? label}) => Shot(path: path, label: label ?? this.label);

  @override
  bool operator ==(Object other) =>
      other is Shot && other.path == path && other.label == label;

  @override
  int get hashCode => Object.hash(path, label);

  @override
  String toString() => 'Shot($path, label: "$label")';
}
