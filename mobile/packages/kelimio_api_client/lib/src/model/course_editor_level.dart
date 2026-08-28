//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_unit.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_level.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorLevel {
  /// Returns a new [CourseEditorLevel] instance.
  CourseEditorLevel({this.id, required this.title, required this.units});

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'units', required: true, includeIfNull: false)
  final List<CourseEditorUnit> units;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorLevel &&
          other.id == id &&
          other.title == title &&
          other.units == units;

  @override
  int get hashCode =>
      (id == null ? 0 : id.hashCode) + title.hashCode + units.hashCode;

  factory CourseEditorLevel.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorLevelFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorLevelToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
