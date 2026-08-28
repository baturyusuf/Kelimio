//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_test.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_topic.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorTopic {
  /// Returns a new [CourseEditorTopic] instance.
  CourseEditorTopic({this.id, required this.title, required this.tests});

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'tests', required: true, includeIfNull: false)
  final List<CourseEditorTest> tests;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorTopic &&
          other.id == id &&
          other.title == title &&
          other.tests == tests;

  @override
  int get hashCode =>
      (id == null ? 0 : id.hashCode) + title.hashCode + tests.hashCode;

  factory CourseEditorTopic.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorTopicFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorTopicToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
