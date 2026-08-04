// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commit_course_import_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CommitCourseImportRequest _$CommitCourseImportRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CommitCourseImportRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['approvalBindingSha256']);
  final val = CommitCourseImportRequest(
    approvalBindingSha256: $checkedConvert(
      'approvalBindingSha256',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$CommitCourseImportRequestToJson(
  CommitCourseImportRequest instance,
) => <String, dynamic>{'approvalBindingSha256': instance.approvalBindingSha256};
