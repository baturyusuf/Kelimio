// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_topic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorTopic _$CourseEditorTopicFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseEditorTopic', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['title', 'tests']);
      final val = CourseEditorTopic(
        id: $checkedConvert('id', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String),
        tests: $checkedConvert(
          'tests',
          (v) => (v as List<dynamic>)
              .map((e) => CourseEditorTest.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CourseEditorTopicToJson(CourseEditorTopic instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'title': instance.title,
      'tests': instance.tests.map((e) => e.toJson()).toList(),
    };
