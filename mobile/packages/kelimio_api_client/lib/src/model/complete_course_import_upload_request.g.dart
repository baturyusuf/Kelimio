// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'complete_course_import_upload_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CompleteCourseImportUploadRequest _$CompleteCourseImportUploadRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CompleteCourseImportUploadRequest', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['sourceSha256', 'parts']);
  final val = CompleteCourseImportUploadRequest(
    sourceSha256: $checkedConvert('sourceSha256', (v) => v as String),
    parts: $checkedConvert(
      'parts',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                CompletedCourseImportPart.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CompleteCourseImportUploadRequestToJson(
  CompleteCourseImportUploadRequest instance,
) => <String, dynamic>{
  'sourceSha256': instance.sourceSha256,
  'parts': instance.parts.map((e) => e.toJson()).toList(),
};
