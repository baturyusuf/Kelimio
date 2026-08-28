// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_unit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorUnit _$CourseEditorUnitFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseEditorUnit', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['title', 'topics']);
      final val = CourseEditorUnit(
        id: $checkedConvert('id', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String),
        topics: $checkedConvert(
          'topics',
          (v) => (v as List<dynamic>)
              .map((e) => CourseEditorTopic.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CourseEditorUnitToJson(CourseEditorUnit instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'title': instance.title,
      'topics': instance.topics.map((e) => e.toJson()).toList(),
    };
