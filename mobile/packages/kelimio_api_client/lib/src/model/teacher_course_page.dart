//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/teacher_course_summary.dart';
import 'package:json_annotation/json_annotation.dart';

part 'teacher_course_page.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherCoursePage {
  /// Returns a new [TeacherCoursePage] instance.
  TeacherCoursePage({required this.items, this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<TeacherCourseSummary> items;

  @JsonKey(name: r'nextCursor', required: false, includeIfNull: false)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCoursePage &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode =>
      items.hashCode + (nextCursor == null ? 0 : nextCursor.hashCode);

  factory TeacherCoursePage.fromJson(Map<String, dynamic> json) =>
      _$TeacherCoursePageFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherCoursePageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
