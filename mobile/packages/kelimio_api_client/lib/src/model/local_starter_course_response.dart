//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'local_starter_course_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocalStarterCourseResponse {
  /// Returns a new [LocalStarterCourseResponse] instance.
  LocalStarterCourseResponse({
    required this.courseId,

    required this.created,

    required this.sourceWorkbookSha256,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @JsonKey(name: r'sourceWorkbookSha256', required: true, includeIfNull: false)
  final String sourceWorkbookSha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalStarterCourseResponse &&
          other.courseId == courseId &&
          other.created == created &&
          other.sourceWorkbookSha256 == sourceWorkbookSha256;

  @override
  int get hashCode =>
      courseId.hashCode + created.hashCode + sourceWorkbookSha256.hashCode;

  factory LocalStarterCourseResponse.fromJson(Map<String, dynamic> json) =>
      _$LocalStarterCourseResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LocalStarterCourseResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
