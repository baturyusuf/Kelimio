//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_release_abandonment_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseReleaseAbandonmentResponse {
  /// Returns a new [CourseReleaseAbandonmentResponse] instance.
  CourseReleaseAbandonmentResponse({
    required this.abandonmentId,

    required this.courseId,

    required this.releaseId,

    required this.releaseRevision,

    required this.abandonedAt,

    required this.created,
  });

  @JsonKey(name: r'abandonmentId', required: true, includeIfNull: false)
  final String abandonmentId;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'releaseId', required: true, includeIfNull: false)
  final String releaseId;

  // minimum: 1
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  @JsonKey(name: r'abandonedAt', required: true, includeIfNull: false)
  final DateTime abandonedAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseReleaseAbandonmentResponse &&
          other.abandonmentId == abandonmentId &&
          other.courseId == courseId &&
          other.releaseId == releaseId &&
          other.releaseRevision == releaseRevision &&
          other.abandonedAt == abandonedAt &&
          other.created == created;

  @override
  int get hashCode =>
      abandonmentId.hashCode +
      courseId.hashCode +
      releaseId.hashCode +
      releaseRevision.hashCode +
      abandonedAt.hashCode +
      created.hashCode;

  factory CourseReleaseAbandonmentResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$CourseReleaseAbandonmentResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CourseReleaseAbandonmentResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
