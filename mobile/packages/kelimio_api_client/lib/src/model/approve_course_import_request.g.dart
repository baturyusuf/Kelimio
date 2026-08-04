// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'approve_course_import_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApproveCourseImportRequest _$ApproveCourseImportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ApproveCourseImportRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['approvalBindingSha256']);
  final val = ApproveCourseImportRequest(
    approvalBindingSha256: $checkedConvert(
      'approvalBindingSha256',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$ApproveCourseImportRequestToJson(
  ApproveCourseImportRequest instance,
) => <String, dynamic>{'approvalBindingSha256': instance.approvalBindingSha256};
