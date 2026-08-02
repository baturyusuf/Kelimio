// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer_recorded_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnswerRecordedResponse _$AnswerRecordedResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AnswerRecordedResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'submissionId',
      'correct',
      'activeScoreDelta',
      'lifetimeScoreDelta',
      'activeQuestionScore',
      'lifetimeScore',
      'energy',
      'attemptState',
    ],
  );
  final val = AnswerRecordedResponse(
    submissionId: $checkedConvert('submissionId', (v) => v as String),
    correct: $checkedConvert('correct', (v) => v as bool),
    correctOptionId: $checkedConvert('correctOptionId', (v) => v as String?),
    correctAnswerText: $checkedConvert(
      'correctAnswerText',
      (v) => v as String?,
    ),
    activeScoreDelta: $checkedConvert(
      'activeScoreDelta',
      (v) => (v as num).toInt(),
    ),
    lifetimeScoreDelta: $checkedConvert(
      'lifetimeScoreDelta',
      (v) => (v as num).toInt(),
    ),
    activeQuestionScore: $checkedConvert(
      'activeQuestionScore',
      (v) => (v as num).toInt(),
    ),
    lifetimeScore: $checkedConvert('lifetimeScore', (v) => (v as num).toInt()),
    energy: $checkedConvert(
      'energy',
      (v) => EnergyResponse.fromJson(v as Map<String, dynamic>),
    ),
    attemptState: $checkedConvert(
      'attemptState',
      (v) => $enumDecode(_$AttemptStateEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$AnswerRecordedResponseToJson(
  AnswerRecordedResponse instance,
) => <String, dynamic>{
  'submissionId': instance.submissionId,
  'correct': instance.correct,
  if (instance.correctOptionId case final value?) 'correctOptionId': value,
  if (instance.correctAnswerText case final value?) 'correctAnswerText': value,
  'activeScoreDelta': instance.activeScoreDelta,
  'lifetimeScoreDelta': instance.lifetimeScoreDelta,
  'activeQuestionScore': instance.activeQuestionScore,
  'lifetimeScore': instance.lifetimeScore,
  'energy': instance.energy.toJson(),
  'attemptState': _$AttemptStateEnumMap[instance.attemptState]!,
};

const _$AttemptStateEnumMap = {
  AttemptState.IN_PROGRESS: 'IN_PROGRESS',
  AttemptState.COMPLETED_PASS: 'COMPLETED_PASS',
  AttemptState.COMPLETED_FAIL: 'COMPLETED_FAIL',
  AttemptState.INTERRUPTED_ENERGY: 'INTERRUPTED_ENERGY',
};
