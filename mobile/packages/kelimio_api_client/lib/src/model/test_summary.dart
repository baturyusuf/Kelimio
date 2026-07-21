//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'test_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TestSummary {
  /// Returns a new [TestSummary] instance.
  TestSummary({
    required this.id,

    required this.revisionId,

    required this.name,

    required this.position,

    required this.questionCount,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'revisionId', required: true, includeIfNull: false)
  final String revisionId;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  // minimum: 1
  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final int position;

  // minimum: 1
  @JsonKey(name: r'questionCount', required: true, includeIfNull: false)
  final int questionCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestSummary &&
          other.id == id &&
          other.revisionId == revisionId &&
          other.name == name &&
          other.position == position &&
          other.questionCount == questionCount;

  @override
  int get hashCode =>
      id.hashCode +
      revisionId.hashCode +
      name.hashCode +
      position.hashCode +
      questionCount.hashCode;

  factory TestSummary.fromJson(Map<String, dynamic> json) =>
      _$TestSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$TestSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
