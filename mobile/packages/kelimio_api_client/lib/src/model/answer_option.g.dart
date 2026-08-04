// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'answer_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnswerOption _$AnswerOptionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AnswerOption', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'text']);
      final val = AnswerOption(
        id: $checkedConvert('id', (v) => v as String),
        text: $checkedConvert('text', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$AnswerOptionToJson(AnswerOption instance) =>
    <String, dynamic>{'id': instance.id, 'text': instance.text};
