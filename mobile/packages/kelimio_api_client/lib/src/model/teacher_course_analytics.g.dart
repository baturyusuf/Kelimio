// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherCourseAnalytics _$TeacherCourseAnalyticsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TeacherCourseAnalytics', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['courseId', 'courseReleaseId', 'updating'],
  );
  final val = TeacherCourseAnalytics(
    courseId: $checkedConvert('courseId', (v) => v as String),
    courseReleaseId: $checkedConvert('courseReleaseId', (v) => v as String),
    updating: $checkedConvert('updating', (v) => v as bool),
    metrics: $checkedConvert(
      'metrics',
      (v) => v == null
          ? null
          : TeacherCourseAnalyticsMetrics.fromJson(v as Map<String, dynamic>),
    ),
    updatedAt: $checkedConvert(
      'updatedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$TeacherCourseAnalyticsToJson(
  TeacherCourseAnalytics instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'courseReleaseId': instance.courseReleaseId,
  'updating': instance.updating,
  if (instance.metrics?.toJson() case final value?) 'metrics': value,
  if (instance.updatedAt?.toIso8601String() case final value?)
    'updatedAt': value,
};
