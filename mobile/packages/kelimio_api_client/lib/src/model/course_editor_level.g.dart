// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_level.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorLevel _$CourseEditorLevelFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseEditorLevel', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['title', 'units']);
      final val = CourseEditorLevel(
        id: $checkedConvert('id', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String),
        units: $checkedConvert(
          'units',
          (v) => (v as List<dynamic>)
              .map((e) => CourseEditorUnit.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CourseEditorLevelToJson(CourseEditorLevel instance) =>
    <String, dynamic>{
      if (instance.id case final value?) 'id': value,
      'title': instance.title,
      'units': instance.units.map((e) => e.toJson()).toList(),
    };
