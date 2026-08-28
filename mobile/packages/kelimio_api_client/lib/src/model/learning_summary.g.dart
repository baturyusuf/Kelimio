// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningSummary _$LearningSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LearningSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'activeScore',
      'lifetimeScore',
      'answeredQuestions',
      'correctAnswers',
      'completedAttempts',
      'passedAttempts',
      'enrolledCourses',
      'completedCourses',
      'currentStreakDays',
      'history',
    ],
  );
  final val = LearningSummary(
    activeScore: $checkedConvert('activeScore', (v) => (v as num).toInt()),
    lifetimeScore: $checkedConvert('lifetimeScore', (v) => (v as num).toInt()),
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
    enrolledCourses: $checkedConvert(
      'enrolledCourses',
      (v) => (v as num).toInt(),
    ),
    completedCourses: $checkedConvert(
      'completedCourses',
      (v) => (v as num).toInt(),
    ),
    currentStreakDays: $checkedConvert(
      'currentStreakDays',
      (v) => (v as num).toInt(),
    ),
    history: $checkedConvert(
      'history',
      (v) => (v as List<dynamic>)
          .map((e) => LearningHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$LearningSummaryToJson(LearningSummary instance) =>
    <String, dynamic>{
      'activeScore': instance.activeScore,
      'lifetimeScore': instance.lifetimeScore,
      'answeredQuestions': instance.answeredQuestions,
      'correctAnswers': instance.correctAnswers,
      'completedAttempts': instance.completedAttempts,
      'passedAttempts': instance.passedAttempts,
      'enrolledCourses': instance.enrolledCourses,
      'completedCourses': instance.completedCourses,
      'currentStreakDays': instance.currentStreakDays,
      'history': instance.history.map((e) => e.toJson()).toList(),
    };
