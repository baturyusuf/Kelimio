//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'matching_selection.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MatchingSelection {
  /// Returns a new [MatchingSelection] instance.
  MatchingSelection({required this.targetItemId, required this.supportItemId});

  /// Independently generated random UUIDv4 for one public matching-side item. It is unrelated to text, authored pair identity, insertion order, the opposite-side item ID, or any shared namespace.
  @JsonKey(name: r'targetItemId', required: true, includeIfNull: false)
  final String targetItemId;

  /// Independently generated random UUIDv4 for one public matching-side item. It is unrelated to text, authored pair identity, insertion order, the opposite-side item ID, or any shared namespace.
  @JsonKey(name: r'supportItemId', required: true, includeIfNull: false)
  final String supportItemId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchingSelection &&
          other.targetItemId == targetItemId &&
          other.supportItemId == supportItemId;

  @override
  int get hashCode => targetItemId.hashCode + supportItemId.hashCode;

  factory MatchingSelection.fromJson(Map<String, dynamic> json) =>
      _$MatchingSelectionFromJson(json);

  Map<String, dynamic> toJson() => _$MatchingSelectionToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'targetItemId')) {
      json[r'targetItemId'] = '[REDACTED]';
    }
    if (json.containsKey(r'supportItemId')) {
      json[r'supportItemId'] = '[REDACTED]';
    }
    return json.toString();
  }
}
