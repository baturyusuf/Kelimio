// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_performance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherCoursePerformance _$TeacherCoursePerformanceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TeacherCoursePerformance', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'answeredQuestions',
      'correctAnswers',
      'completedAttempts',
      'passedAttempts',
    ],
  );
  final val = TeacherCoursePerformance(
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
  );
  return val;
});

Map<String, dynamic> _$TeacherCoursePerformanceToJson(
  TeacherCoursePerformance instance,
) => <String, dynamic>{
  'answeredQuestions': instance.answeredQuestions,
  'correctAnswers': instance.correctAnswers,
  'completedAttempts': instance.completedAttempts,
  'passedAttempts': instance.passedAttempts,
};
