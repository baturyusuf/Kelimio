// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_part_declaration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPartDeclaration _$CourseImportPartDeclarationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPartDeclaration', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['partNumber', 'sizeBytes', 'sha256']);
  final val = CourseImportPartDeclaration(
    partNumber: $checkedConvert('partNumber', (v) => (v as num).toInt()),
    sizeBytes: $checkedConvert('sizeBytes', (v) => (v as num).toInt()),
    sha256: $checkedConvert('sha256', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPartDeclarationToJson(
  CourseImportPartDeclaration instance,
) => <String, dynamic>{
  'partNumber': instance.partNumber,
  'sizeBytes': instance.sizeBytes,
  'sha256': instance.sha256,
};
