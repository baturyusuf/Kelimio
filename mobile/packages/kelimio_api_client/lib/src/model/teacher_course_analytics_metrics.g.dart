// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_analytics_metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherCourseAnalyticsMetrics _$TeacherCourseAnalyticsMetricsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TeacherCourseAnalyticsMetrics', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['learnersWithRecordedActivity']);
  final val = TeacherCourseAnalyticsMetrics(
    learnersWithRecordedActivity: $checkedConvert(
      'learnersWithRecordedActivity',
      (v) => (v as num).toInt(),
    ),
    performance: $checkedConvert(
      'performance',
      (v) => v == null
          ? null
          : TeacherCoursePerformance.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$TeacherCourseAnalyticsMetricsToJson(
  TeacherCourseAnalyticsMetrics instance,
) => <String, dynamic>{
  'learnersWithRecordedActivity': instance.learnersWithRecordedActivity,
  if (instance.performance?.toJson() case final value?) 'performance': value,
};
