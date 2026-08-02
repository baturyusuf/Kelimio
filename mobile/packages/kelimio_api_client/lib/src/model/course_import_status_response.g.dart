// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_status_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportStatusResponse _$CourseImportStatusResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportStatusResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'status',
      'originalFileName',
      'declaredMediaType',
      'fileSizeBytes',
      'rulesVersion',
      'processingAttempts',
      'createdAt',
      'updatedAt',
      'uploadExpiresAt',
      'preview',
      'approvalBindingSha256',
      'approvedAt',
      'commit',
      'failureCode',
    ],
  );
  final val = CourseImportStatusResponse(
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$CourseImportStatusEnumMap, v),
    ),
    originalFileName: $checkedConvert('originalFileName', (v) => v as String),
    declaredMediaType: $checkedConvert(
      'declaredMediaType',
      (v) => $enumDecode(
        _$CourseImportStatusResponseDeclaredMediaTypeEnumEnumMap,
        v,
      ),
    ),
    fileSizeBytes: $checkedConvert('fileSizeBytes', (v) => (v as num).toInt()),
    rulesVersion: $checkedConvert(
      'rulesVersion',
      (v) =>
          $enumDecode(_$CourseImportStatusResponseRulesVersionEnumEnumMap, v),
    ),
    processingAttempts: $checkedConvert(
      'processingAttempts',
      (v) => (v as num).toInt(),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    updatedAt: $checkedConvert('updatedAt', (v) => DateTime.parse(v as String)),
    uploadExpiresAt: $checkedConvert(
      'uploadExpiresAt',
      (v) => DateTime.parse(v as String),
    ),
    preview: $checkedConvert(
      'preview',
      (v) => v == null
          ? null
          : CourseImportPreviewSummary.fromJson(v as Map<String, dynamic>),
    ),
    approvalBindingSha256: $checkedConvert(
      'approvalBindingSha256',
      (v) => v as String?,
    ),
    approvedAt: $checkedConvert(
      'approvedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    commit: $checkedConvert(
      'commit',
      (v) => v == null
          ? null
          : CourseImportCommitSummary.fromJson(v as Map<String, dynamic>),
    ),
    failureCode: $checkedConvert('failureCode', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CourseImportStatusResponseToJson(
  CourseImportStatusResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': _$CourseImportStatusEnumMap[instance.status]!,
  'originalFileName': instance.originalFileName,
  'declaredMediaType':
      _$CourseImportStatusResponseDeclaredMediaTypeEnumEnumMap[instance
          .declaredMediaType]!,
  'fileSizeBytes': instance.fileSizeBytes,
  'rulesVersion':
      _$CourseImportStatusResponseRulesVersionEnumEnumMap[instance
          .rulesVersion]!,
  'processingAttempts': instance.processingAttempts,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'uploadExpiresAt': instance.uploadExpiresAt.toIso8601String(),
  'preview': instance.preview?.toJson(),
  'approvalBindingSha256': instance.approvalBindingSha256,
  'approvedAt': instance.approvedAt?.toIso8601String(),
  'commit': instance.commit?.toJson(),
  'failureCode': instance.failureCode,
};

const _$CourseImportStatusEnumMap = {
  CourseImportStatus.UPLOADING: 'UPLOADING',
  CourseImportStatus.QUEUED: 'QUEUED',
  CourseImportStatus.PROCESSING: 'PROCESSING',
  CourseImportStatus.PREVIEW_READY: 'PREVIEW_READY',
  CourseImportStatus.VALIDATION_FAILED: 'VALIDATION_FAILED',
  CourseImportStatus.MALWARE_REJECTED: 'MALWARE_REJECTED',
  CourseImportStatus.PROCESSING_FAILED: 'PROCESSING_FAILED',
  CourseImportStatus.EXPIRED: 'EXPIRED',
  CourseImportStatus.APPROVED: 'APPROVED',
  CourseImportStatus.COMMITTED: 'COMMITTED',
};

const _$CourseImportStatusResponseDeclaredMediaTypeEnumEnumMap = {
  CourseImportStatusResponseDeclaredMediaTypeEnum
          .applicationSlashVndPeriodOpenxmlformatsOfficedocumentPeriodSpreadsheetmlPeriodSheet:
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

const _$CourseImportStatusResponseRulesVersionEnumEnumMap = {
  CourseImportStatusResponseRulesVersionEnum.xlsxV1: 'xlsx-v1',
};
