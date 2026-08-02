// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_approval_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportApprovalResponse _$CourseImportApprovalResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportApprovalResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'importId',
      'status',
      'approvalBindingSha256',
      'approvedAt',
      'created',
    ],
  );
  final val = CourseImportApprovalResponse(
    importId: $checkedConvert('importId', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$CourseImportApprovalResponseStatusEnumEnumMap, v),
    ),
    approvalBindingSha256: $checkedConvert(
      'approvalBindingSha256',
      (v) => v as String,
    ),
    approvedAt: $checkedConvert(
      'approvedAt',
      (v) => DateTime.parse(v as String),
    ),
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$CourseImportApprovalResponseToJson(
  CourseImportApprovalResponse instance,
) => <String, dynamic>{
  'importId': instance.importId,
  'status': _$CourseImportApprovalResponseStatusEnumEnumMap[instance.status]!,
  'approvalBindingSha256': instance.approvalBindingSha256,
  'approvedAt': instance.approvedAt.toIso8601String(),
  'created': instance.created,
};

const _$CourseImportApprovalResponseStatusEnumEnumMap = {
  CourseImportApprovalResponseStatusEnum.APPROVED: 'APPROVED',
};
