// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finish_attempt_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FinishAttemptResponse _$FinishAttemptResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FinishAttemptResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'attemptId',
      'state',
      'correctCount',
      'questionCount',
      'correctRatio',
      'completedAt',
    ],
  );
  final val = FinishAttemptResponse(
    attemptId: $checkedConvert('attemptId', (v) => v as String),
    state: $checkedConvert(
      'state',
      (v) => $enumDecode(_$AttemptStateEnumMap, v),
    ),
    correctCount: $checkedConvert('correctCount', (v) => (v as num).toInt()),
    questionCount: $checkedConvert('questionCount', (v) => (v as num).toInt()),
    correctRatio: $checkedConvert('correctRatio', (v) => v as num),
    completedAt: $checkedConvert(
      'completedAt',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$FinishAttemptResponseToJson(
  FinishAttemptResponse instance,
) => <String, dynamic>{
  'attemptId': instance.attemptId,
  'state': _$AttemptStateEnumMap[instance.state]!,
  'correctCount': instance.correctCount,
  'questionCount': instance.questionCount,
  'correctRatio': instance.correctRatio,
  'completedAt': instance.completedAt.toIso8601String(),
};

const _$AttemptStateEnumMap = {
  AttemptState.IN_PROGRESS: 'IN_PROGRESS',
  AttemptState.COMPLETED_PASS: 'COMPLETED_PASS',
  AttemptState.COMPLETED_FAIL: 'COMPLETED_FAIL',
  AttemptState.INTERRUPTED_ENERGY: 'INTERRUPTED_ENERGY',
};
