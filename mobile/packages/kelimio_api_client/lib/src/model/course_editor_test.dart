//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_question.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_test.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorTest {
  /// Returns a new [CourseEditorTest] instance.
  CourseEditorTest({
    this.id,

    required this.title,

    required this.passThreshold,

    required this.questions,
  });

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  // minimum: 0.5
  // maximum: 1
  @JsonKey(name: r'passThreshold', required: true, includeIfNull: false)
  final num passThreshold;

  @JsonKey(name: r'questions', required: true, includeIfNull: false)
  final List<CourseEditorQuestion> questions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorTest &&
          other.id == id &&
          other.title == title &&
          other.passThreshold == passThreshold &&
          other.questions == questions;

  @override
  int get hashCode =>
      (id == null ? 0 : id.hashCode) +
      title.hashCode +
      passThreshold.hashCode +
      questions.hashCode;

  factory CourseEditorTest.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorTestFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorTestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
