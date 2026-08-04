// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_starter_course_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalStarterCourseResponse _$LocalStarterCourseResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LocalStarterCourseResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['courseId', 'created', 'sourceWorkbookSha256'],
  );
  final val = LocalStarterCourseResponse(
    courseId: $checkedConvert('courseId', (v) => v as String),
    created: $checkedConvert('created', (v) => v as bool),
    sourceWorkbookSha256: $checkedConvert(
      'sourceWorkbookSha256',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$LocalStarterCourseResponseToJson(
  LocalStarterCourseResponse instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'created': instance.created,
  'sourceWorkbookSha256': instance.sourceWorkbookSha256,
};
