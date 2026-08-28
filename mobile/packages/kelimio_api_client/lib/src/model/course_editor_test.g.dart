// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_test.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorTest _$CourseEditorTestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseEditorTest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['title', 'passThreshold', 'questions']);
  final val = CourseEditorTest(
    id: $checkedConvert('id', (v) => v as String?),
    title: $checkedConvert('title', (v) => v as String),
    passThreshold: $checkedConvert('passThreshold', (v) => v as num),
    questions: $checkedConvert(
      'questions',
      (v) => (v as List<dynamic>)
          .map((e) => CourseEditorQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseEditorTestToJson(CourseEditorTest instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'title': instance.title,
      'passThreshold': instance.passThreshold,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
    };
