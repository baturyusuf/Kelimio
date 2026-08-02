//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'matching_item.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MatchingItem {
  /// Returns a new [MatchingItem] instance.
  MatchingItem({required this.id, required this.text});

  /// Independently generated random UUIDv4 for one public matching-side item. It is unrelated to text, authored pair identity, insertion order, the opposite-side item ID, or any shared namespace.
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchingItem && other.id == id && other.text == text;

  @override
  int get hashCode => id.hashCode + text.hashCode;

  factory MatchingItem.fromJson(Map<String, dynamic> json) =>
      _$MatchingItemFromJson(json);

  Map<String, dynamic> toJson() => _$MatchingItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
