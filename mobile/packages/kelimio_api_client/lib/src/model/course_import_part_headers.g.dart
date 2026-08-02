// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_part_headers.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPartHeaders _$CourseImportPartHeadersFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPartHeaders', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['contentLength', 'sha256']);
  final val = CourseImportPartHeaders(
    contentLength: $checkedConvert('contentLength', (v) => v as String),
    sha256: $checkedConvert('sha256', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPartHeadersToJson(
  CourseImportPartHeaders instance,
) => <String, dynamic>{
  'contentLength': instance.contentLength,
  'sha256': instance.sha256,
};
