// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_upload_session_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportUploadSessionResponse _$CourseImportUploadSessionResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportUploadSessionResponse', json, (
  $checkedConvert,
) {
  $checkKeys(json, requiredKeys: const ['created', 'import', 'upload']);
  final val = CourseImportUploadSessionResponse(
    created: $checkedConvert('created', (v) => v as bool),
    import_: $checkedConvert(
      'import',
      (v) => CourseImportStatusResponse.fromJson(v as Map<String, dynamic>),
    ),
    upload: $checkedConvert(
      'upload',
      (v) => v == null
          ? null
          : CourseImportUploadInstructions.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
}, fieldKeyMap: const {'import_': 'import'});

Map<String, dynamic> _$CourseImportUploadSessionResponseToJson(
  CourseImportUploadSessionResponse instance,
) => <String, dynamic>{
  'created': instance.created,
  'import': instance.import_.toJson(),
  'upload': instance.upload?.toJson(),
};
