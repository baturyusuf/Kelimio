// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_progress_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseProgressResponse _$CourseProgressResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseProgressResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'courseReleaseId',
      'answeredQuestions',
      'correctAnswers',
      'completedAttempts',
      'passedAttempts',
      'activeScore',
      'lifetimeScore',
      'projectionVersion',
      'updating',
      'updatedAt',
    ],
  );
  final val = CourseProgressResponse(
    courseId: $checkedConvert('courseId', (v) => v as String),
    courseReleaseId: $checkedConvert('courseReleaseId', (v) => v as String),
    answeredQuestions: $checkedConvert(
      'answeredQuestions',
      (v) => (v as num).toInt(),
    ),
    correctAnswers: $checkedConvert(
      'correctAnswers',
      (v) => (v as num).toInt(),
    ),
    completedAttempts: $checkedConvert(
      'completedAttempts',
      (v) => (v as num).toInt(),
    ),
    passedAttempts: $checkedConvert(
      'passedAttempts',
      (v) => (v as num).toInt(),
    ),
    activeScore: $checkedConvert('activeScore', (v) => (v as num).toInt()),
    lifetimeScore: $checkedConvert('lifetimeScore', (v) => (v as num).toInt()),
    projectionVersion: $checkedConvert(
      'projectionVersion',
      (v) => (v as num).toInt(),
    ),
    updating: $checkedConvert('updating', (v) => v as bool),
    updatedAt: $checkedConvert(
      'updatedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseProgressResponseToJson(
  CourseProgressResponse instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'courseReleaseId': instance.courseReleaseId,
  'answeredQuestions': instance.answeredQuestions,
  'correctAnswers': instance.correctAnswers,
  'completedAttempts': instance.completedAttempts,
  'passedAttempts': instance.passedAttempts,
  'activeScore': instance.activeScore,
  'lifetimeScore': instance.lifetimeScore,
  'projectionVersion': instance.projectionVersion,
  'updating': instance.updating,
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
