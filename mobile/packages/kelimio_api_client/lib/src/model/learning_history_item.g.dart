// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_history_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LearningHistoryItem _$LearningHistoryItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LearningHistoryItem', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'attemptId',
      'courseId',
      'courseName',
      'testTitle',
      'status',
      'answeredCount',
      'correctCount',
      'totalQuestions',
      'finishedAt',
    ],
  );
  final val = LearningHistoryItem(
    attemptId: $checkedConvert('attemptId', (v) => v as String),
    courseId: $checkedConvert('courseId', (v) => v as String),
    courseName: $checkedConvert('courseName', (v) => v as String),
    testTitle: $checkedConvert('testTitle', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$LearningHistoryItemStatusEnumEnumMap, v),
    ),
    answeredCount: $checkedConvert('answeredCount', (v) => (v as num).toInt()),
    correctCount: $checkedConvert('correctCount', (v) => (v as num).toInt()),
    totalQuestions: $checkedConvert(
      'totalQuestions',
      (v) => (v as num).toInt(),
    ),
    finishedAt: $checkedConvert(
      'finishedAt',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$LearningHistoryItemToJson(
  LearningHistoryItem instance,
) => <String, dynamic>{
  'attemptId': instance.attemptId,
  'courseId': instance.courseId,
  'courseName': instance.courseName,
  'testTitle': instance.testTitle,
  'status': _$LearningHistoryItemStatusEnumEnumMap[instance.status]!,
  'answeredCount': instance.answeredCount,
  'correctCount': instance.correctCount,
  'totalQuestions': instance.totalQuestions,
  'finishedAt': instance.finishedAt.toIso8601String(),
};

const _$LearningHistoryItemStatusEnumEnumMap = {
  LearningHistoryItemStatusEnum.COMPLETED_PASS: 'COMPLETED_PASS',
  LearningHistoryItemStatusEnum.COMPLETED_FAIL: 'COMPLETED_FAIL',
};
