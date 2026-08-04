// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_presigned_part.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPresignedPart _$CourseImportPresignedPartFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPresignedPart', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['partNumber', 'sizeBytes', 'url', 'requiredHeaders'],
  );
  final val = CourseImportPresignedPart(
    partNumber: $checkedConvert('partNumber', (v) => (v as num).toInt()),
    sizeBytes: $checkedConvert('sizeBytes', (v) => (v as num).toInt()),
    url: $checkedConvert('url', (v) => v as String),
    requiredHeaders: $checkedConvert(
      'requiredHeaders',
      (v) => CourseImportPartHeaders.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPresignedPartToJson(
  CourseImportPresignedPart instance,
) => <String, dynamic>{
  'partNumber': instance.partNumber,
  'sizeBytes': instance.sizeBytes,
  'url': instance.url,
  'requiredHeaders': instance.requiredHeaders.toJson(),
};
