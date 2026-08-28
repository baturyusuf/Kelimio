//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_matching_pair.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorMatchingPair {
  /// Returns a new [CourseEditorMatchingPair] instance.
  CourseEditorMatchingPair({
    required this.targetText,

    required this.translations,
  });

  @JsonKey(name: r'targetText', required: true, includeIfNull: false)
  final String targetText;

  @JsonKey(name: r'translations', required: true, includeIfNull: false)
  final Map<String, String> translations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorMatchingPair &&
          other.targetText == targetText &&
          other.translations == translations;

  @override
  int get hashCode => targetText.hashCode + translations.hashCode;

  factory CourseEditorMatchingPair.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorMatchingPairFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorMatchingPairToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
