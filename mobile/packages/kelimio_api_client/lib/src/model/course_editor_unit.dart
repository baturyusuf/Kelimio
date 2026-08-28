//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_topic.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_unit.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorUnit {
  /// Returns a new [CourseEditorUnit] instance.
  CourseEditorUnit({this.id, required this.title, required this.topics});

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'topics', required: true, includeIfNull: false)
  final List<CourseEditorTopic> topics;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorUnit &&
          other.id == id &&
          other.title == title &&
          other.topics == topics;

  @override
  int get hashCode =>
      (id == null ? 0 : id.hashCode) + title.hashCode + topics.hashCode;

  factory CourseEditorUnit.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorUnitFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorUnitToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
