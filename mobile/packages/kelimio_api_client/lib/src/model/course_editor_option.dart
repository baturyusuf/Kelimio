//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_option.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorOption {
  /// Returns a new [CourseEditorOption] instance.
  CourseEditorOption({
    required this.text,

    required this.correct,

    required this.translations,
  });

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  @JsonKey(name: r'correct', required: true, includeIfNull: false)
  final bool correct;

  @JsonKey(name: r'translations', required: true, includeIfNull: false)
  final Map<String, String> translations;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorOption &&
          other.text == text &&
          other.correct == correct &&
          other.translations == translations;

  @override
  int get hashCode => text.hashCode + correct.hashCode + translations.hashCode;

  factory CourseEditorOption.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorOptionFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorOptionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
