//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/teacher_course_performance.dart';
import 'package:json_annotation/json_annotation.dart';

part 'teacher_course_analytics_metrics.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherCourseAnalyticsMetrics {
  /// Returns a new [TeacherCourseAnalyticsMetrics] instance.
  TeacherCourseAnalyticsMetrics({
    required this.learnersWithRecordedActivity,

    this.performance,
  });

  // minimum: 0
  @JsonKey(
    name: r'learnersWithRecordedActivity',
    required: true,
    includeIfNull: false,
  )
  final int learnersWithRecordedActivity;

  @JsonKey(name: r'performance', required: false, includeIfNull: false)
  final TeacherCoursePerformance? performance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCourseAnalyticsMetrics &&
          other.learnersWithRecordedActivity == learnersWithRecordedActivity &&
          other.performance == performance;

  @override
  int get hashCode =>
      learnersWithRecordedActivity.hashCode +
      (performance == null ? 0 : performance.hashCode);

  factory TeacherCourseAnalyticsMetrics.fromJson(Map<String, dynamic> json) =>
      _$TeacherCourseAnalyticsMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherCourseAnalyticsMetricsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
