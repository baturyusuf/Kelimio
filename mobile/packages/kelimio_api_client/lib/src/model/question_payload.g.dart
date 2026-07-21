// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestionPayload _$QuestionPayloadFromJson(Map<String, dynamic> json) =>
    $checkedCreate('QuestionPayload', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'questionId',
          'questionRevisionId',
          'type',
          'position',
          'prompt',
          'options',
        ],
      );
      final val = QuestionPayload(
        questionId: $checkedConvert('questionId', (v) => v as String),
        questionRevisionId: $checkedConvert(
          'questionRevisionId',
          (v) => v as String,
        ),
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(_$QuestionPayloadTypeEnumEnumMap, v),
        ),
        position: $checkedConvert('position', (v) => (v as num).toInt()),
        prompt: $checkedConvert('prompt', (v) => v as String),
        options: $checkedConvert(
          'options',
          (v) => (v as List<dynamic>)
              .map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$QuestionPayloadToJson(QuestionPayload instance) =>
    <String, dynamic>{
      'questionId': instance.questionId,
      'questionRevisionId': instance.questionRevisionId,
      'type': _$QuestionPayloadTypeEnumEnumMap[instance.type]!,
      'position': instance.position,
      'prompt': instance.prompt,
      'options': instance.options.map((e) => e.toJson()).toList(),
    };

const _$QuestionPayloadTypeEnumEnumMap = {
  QuestionPayloadTypeEnum.WORD_MULTIPLE_CHOICE: 'WORD_MULTIPLE_CHOICE',
};
