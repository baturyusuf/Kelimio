//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/teacher_course_analytics_metrics.dart';
import 'package:json_annotation/json_annotation.dart';

part 'teacher_course_analytics.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherCourseAnalytics {
  /// Returns a new [TeacherCourseAnalytics] instance.
  TeacherCourseAnalytics({
    required this.courseId,

    required this.courseReleaseId,

    required this.updating,

    this.metrics,

    this.updatedAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'courseReleaseId', required: true, includeIfNull: false)
  final String courseReleaseId;

  /// True while learning delivery or active-release reprojection is unresolved; metrics are then null.
  @JsonKey(name: r'updating', required: true, includeIfNull: false)
  final bool updating;

  @JsonKey(name: r'metrics', required: false, includeIfNull: false)
  final TeacherCourseAnalyticsMetrics? metrics;

  @JsonKey(name: r'updatedAt', required: false, includeIfNull: false)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCourseAnalytics &&
          other.courseId == courseId &&
          other.courseReleaseId == courseReleaseId &&
          other.updating == updating &&
          other.metrics == metrics &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      courseReleaseId.hashCode +
      updating.hashCode +
      (metrics == null ? 0 : metrics.hashCode) +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory TeacherCourseAnalytics.fromJson(Map<String, dynamic> json) =>
      _$TeacherCourseAnalyticsFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherCourseAnalyticsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
