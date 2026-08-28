// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorOption _$CourseEditorOptionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseEditorOption', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['text', 'correct', 'translations']);
      final val = CourseEditorOption(
        text: $checkedConvert('text', (v) => v as String),
        correct: $checkedConvert('correct', (v) => v as bool),
        translations: $checkedConvert(
          'translations',
          (v) => Map<String, String>.from(v as Map),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CourseEditorOptionToJson(CourseEditorOption instance) =>
    <String, dynamic>{
      'text': instance.text,
      'correct': instance.correct,
      'translations': instance.translations,
    };
