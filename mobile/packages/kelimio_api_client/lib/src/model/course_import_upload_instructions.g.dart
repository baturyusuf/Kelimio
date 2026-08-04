// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_upload_instructions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportUploadInstructions _$CourseImportUploadInstructionsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportUploadInstructions', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['expiresAt', 'parts']);
  final val = CourseImportUploadInstructions(
    expiresAt: $checkedConvert('expiresAt', (v) => DateTime.parse(v as String)),
    parts: $checkedConvert(
      'parts',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                CourseImportPresignedPart.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportUploadInstructionsToJson(
  CourseImportUploadInstructions instance,
) => <String, dynamic>{
  'expiresAt': instance.expiresAt.toIso8601String(),
  'parts': instance.parts.map((e) => e.toJson()).toList(),
};
