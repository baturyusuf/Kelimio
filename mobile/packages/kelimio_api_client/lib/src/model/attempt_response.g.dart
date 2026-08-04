// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attempt_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttemptResponse _$AttemptResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AttemptResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'testId',
          'testRevisionId',
          'supportLanguage',
          'state',
          'questions',
          'startedAt',
        ],
      );
      final val = AttemptResponse(
        id: $checkedConvert('id', (v) => v as String),
        testId: $checkedConvert('testId', (v) => v as String),
        testRevisionId: $checkedConvert('testRevisionId', (v) => v as String),
        supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
        state: $checkedConvert(
          'state',
          (v) => $enumDecode(_$AttemptStateEnumMap, v),
        ),
        questions: $checkedConvert(
          'questions',
          (v) => (v as List<dynamic>)
              .map((e) => QuestionPayload.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        startedAt: $checkedConvert(
          'startedAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AttemptResponseToJson(AttemptResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'testId': instance.testId,
      'testRevisionId': instance.testRevisionId,
      'supportLanguage': instance.supportLanguage,
      'state': _$AttemptStateEnumMap[instance.state]!,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
      'startedAt': instance.startedAt.toIso8601String(),
    };

const _$AttemptStateEnumMap = {
  AttemptState.IN_PROGRESS: 'IN_PROGRESS',
  AttemptState.COMPLETED_PASS: 'COMPLETED_PASS',
  AttemptState.COMPLETED_FAIL: 'COMPLETED_FAIL',
  AttemptState.INTERRUPTED_ENERGY: 'INTERRUPTED_ENERGY',
};
