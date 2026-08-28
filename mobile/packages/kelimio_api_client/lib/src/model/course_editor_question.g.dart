// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_question.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorQuestion _$CourseEditorQuestionFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseEditorQuestion', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['type', 'translations', 'options', 'matchingPairs'],
  );
  final val = CourseEditorQuestion(
    id: $checkedConvert('id', (v) => v as String?),
    type: $checkedConvert(
      'type',
      (v) => $enumDecode(_$CourseEditorQuestionTypeEnumEnumMap, v),
    ),
    prompt: $checkedConvert('prompt', (v) => v as String?),
    correctAnswer: $checkedConvert('correctAnswer', (v) => v as String?),
    alternativeCorrectAnswer: $checkedConvert(
      'alternativeCorrectAnswer',
      (v) => v as String?,
    ),
    translations: $checkedConvert(
      'translations',
      (v) => Map<String, String>.from(v as Map),
    ),
    options: $checkedConvert(
      'options',
      (v) => (v as List<dynamic>)
          .map((e) => CourseEditorOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    matchingPairs: $checkedConvert(
      'matchingPairs',
      (v) => (v as List<dynamic>)
          .map(
            (e) => CourseEditorMatchingPair.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseEditorQuestionToJson(
  CourseEditorQuestion instance,
) => <String, dynamic>{
  if (instance.id case final value?) 'id': value,
  'type': _$CourseEditorQuestionTypeEnumEnumMap[instance.type]!,
  if (instance.prompt case final value?) 'prompt': value,
  if (instance.correctAnswer case final value?) 'correctAnswer': value,
  if (instance.alternativeCorrectAnswer case final value?)
    'alternativeCorrectAnswer': value,
  'translations': instance.translations,
  'options': instance.options.map((e) => e.toJson()).toList(),
  'matchingPairs': instance.matchingPairs.map((e) => e.toJson()).toList(),
};

const _$CourseEditorQuestionTypeEnumEnumMap = {
  CourseEditorQuestionTypeEnum.WORD_MULTIPLE_CHOICE: 'WORD_MULTIPLE_CHOICE',
  CourseEditorQuestionTypeEnum.MULTIPLE_CHOICE_CLOZE: 'MULTIPLE_CHOICE_CLOZE',
  CourseEditorQuestionTypeEnum.TYPED_CLOZE: 'TYPED_CLOZE',
  CourseEditorQuestionTypeEnum.MATCHING: 'MATCHING',
};
