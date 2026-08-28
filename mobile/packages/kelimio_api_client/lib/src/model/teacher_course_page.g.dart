// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherCoursePage _$TeacherCoursePageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TeacherCoursePage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['items']);
      final val = TeacherCoursePage(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map(
                (e) => TeacherCourseSummary.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
        ),
        nextCursor: $checkedConvert('nextCursor', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$TeacherCoursePageToJson(TeacherCoursePage instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      if (instance.nextCursor case final value?) 'nextCursor': value,
    };
