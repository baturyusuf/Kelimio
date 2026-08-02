// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_activation_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportActivationSummary _$CourseImportActivationSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportActivationSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'releaseId',
      'operation',
      'activatedAt',
      'reprojectionStatus',
    ],
  );
  final val = CourseImportActivationSummary(
    releaseId: $checkedConvert('releaseId', (v) => v as String),
    operation: $checkedConvert(
      'operation',
      (v) => $enumDecode(_$CourseReleaseOperationEnumMap, v),
    ),
    activatedAt: $checkedConvert(
      'activatedAt',
      (v) => DateTime.parse(v as String),
    ),
    reprojectionStatus: $checkedConvert(
      'reprojectionStatus',
      (v) => $enumDecode(
        _$CourseImportActivationSummaryReprojectionStatusEnumEnumMap,
        v,
      ),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportActivationSummaryToJson(
  CourseImportActivationSummary instance,
) => <String, dynamic>{
  'releaseId': instance.releaseId,
  'operation': _$CourseReleaseOperationEnumMap[instance.operation]!,
  'activatedAt': instance.activatedAt.toIso8601String(),
  'reprojectionStatus':
      _$CourseImportActivationSummaryReprojectionStatusEnumEnumMap[instance
          .reprojectionStatus]!,
};

const _$CourseReleaseOperationEnumMap = {
  CourseReleaseOperation.INITIAL_PUBLICATION: 'INITIAL_PUBLICATION',
  CourseReleaseOperation.PUBLICATION: 'PUBLICATION',
  CourseReleaseOperation.ROLLBACK: 'ROLLBACK',
};

const _$CourseImportActivationSummaryReprojectionStatusEnumEnumMap = {
  CourseImportActivationSummaryReprojectionStatusEnum.PENDING: 'PENDING',
  CourseImportActivationSummaryReprojectionStatusEnum.FAILED: 'FAILED',
  CourseImportActivationSummaryReprojectionStatusEnum.COMPLETED: 'COMPLETED',
  CourseImportActivationSummaryReprojectionStatusEnum.DEAD: 'DEAD',
};
