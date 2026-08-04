// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_course_import_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCourseImportRequest _$CreateCourseImportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateCourseImportRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'originalFileName',
      'declaredMediaType',
      'fileSizeBytes',
      'sourceSha256',
      'parts',
    ],
  );
  final val = CreateCourseImportRequest(
    originalFileName: $checkedConvert('originalFileName', (v) => v as String),
    declaredMediaType: $checkedConvert(
      'declaredMediaType',
      (v) => $enumDecode(
        _$CreateCourseImportRequestDeclaredMediaTypeEnumEnumMap,
        v,
      ),
    ),
    fileSizeBytes: $checkedConvert('fileSizeBytes', (v) => (v as num).toInt()),
    sourceSha256: $checkedConvert('sourceSha256', (v) => v as String),
    parts: $checkedConvert(
      'parts',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                CourseImportPartDeclaration.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateCourseImportRequestToJson(
  CreateCourseImportRequest instance,
) => <String, dynamic>{
  'originalFileName': instance.originalFileName,
  'declaredMediaType':
      _$CreateCourseImportRequestDeclaredMediaTypeEnumEnumMap[instance
          .declaredMediaType]!,
  'fileSizeBytes': instance.fileSizeBytes,
  'sourceSha256': instance.sourceSha256,
  'parts': instance.parts.map((e) => e.toJson()).toList(),
};

const _$CreateCourseImportRequestDeclaredMediaTypeEnumEnumMap = {
  CreateCourseImportRequestDeclaredMediaTypeEnum
          .applicationSlashVndPeriodOpenxmlformatsOfficedocumentPeriodSpreadsheetmlPeriodSheet:
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};
