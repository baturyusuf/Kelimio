// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submit_answer_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubmitAnswerRequest _$SubmitAnswerRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SubmitAnswerRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['submissionId', 'questionRevisionId']);
  final val = SubmitAnswerRequest(
    submissionId: $checkedConvert('submissionId', (v) => v as String),
    questionRevisionId: $checkedConvert(
      'questionRevisionId',
      (v) => v as String,
    ),
    selectedOptionId: $checkedConvert('selectedOptionId', (v) => v as String?),
    typedAnswer: $checkedConvert('typedAnswer', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$SubmitAnswerRequestToJson(
  SubmitAnswerRequest instance,
) => <String, dynamic>{
  'submissionId': instance.submissionId,
  'questionRevisionId': instance.questionRevisionId,
  if (instance.selectedOptionId case final value?) 'selectedOptionId': value,
  if (instance.typedAnswer case final value?) 'typedAnswer': value,
};
