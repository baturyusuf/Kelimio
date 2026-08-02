// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'completed_course_import_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompletedCourseImportPart _$CompletedCourseImportPartFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompletedCourseImportPart', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['partNumber', 'eTag', 'sha256']);
  final val = CompletedCourseImportPart(
    partNumber: $checkedConvert('partNumber', (v) => (v as num).toInt()),
    eTag: $checkedConvert('eTag', (v) => v as String),
    sha256: $checkedConvert('sha256', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CompletedCourseImportPartToJson(
  CompletedCourseImportPart instance,
) => <String, dynamic>{
  'partNumber': instance.partNumber,
  'eTag': instance.eTag,
  'sha256': instance.sha256,
};
