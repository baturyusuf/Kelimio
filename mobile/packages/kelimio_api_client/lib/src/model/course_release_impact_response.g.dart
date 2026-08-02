// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_release_impact_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseReleaseImpactResponse _$CourseReleaseImpactResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseReleaseImpactResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'targetReleaseId',
      'expectedActiveReleaseId',
      'sourceChangeSetId',
      'operation',
      'releaseRevision',
      'targetQuestionCount',
      'unchangedQuestionCount',
      'changedQuestionCount',
      'addedQuestionCount',
      'removedQuestionCount',
      'affectedEnrollmentCount',
      'requiredClientCapabilities',
      'impactBindingSha256',
    ],
  );
  final val = CourseReleaseImpactResponse(
    courseId: $checkedConvert('courseId', (v) => v as String),
    targetReleaseId: $checkedConvert('targetReleaseId', (v) => v as String),
    expectedActiveReleaseId: $checkedConvert(
      'expectedActiveReleaseId',
      (v) => v as String?,
    ),
    sourceChangeSetId: $checkedConvert('sourceChangeSetId', (v) => v as String),
    operation: $checkedConvert(
      'operation',
      (v) => $enumDecode(_$CourseReleaseOperationEnumMap, v),
    ),
    releaseRevision: $checkedConvert(
      'releaseRevision',
      (v) => (v as num).toInt(),
    ),
    targetQuestionCount: $checkedConvert(
      'targetQuestionCount',
      (v) => (v as num).toInt(),
    ),
    unchangedQuestionCount: $checkedConvert(
      'unchangedQuestionCount',
      (v) => (v as num).toInt(),
    ),
    changedQuestionCount: $checkedConvert(
      'changedQuestionCount',
      (v) => (v as num).toInt(),
    ),
    addedQuestionCount: $checkedConvert(
      'addedQuestionCount',
      (v) => (v as num).toInt(),
    ),
    removedQuestionCount: $checkedConvert(
      'removedQuestionCount',
      (v) => (v as num).toInt(),
    ),
    affectedEnrollmentCount: $checkedConvert(
      'affectedEnrollmentCount',
      (v) => (v as num).toInt(),
    ),
    requiredClientCapabilities: $checkedConvert(
      'requiredClientCapabilities',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    impactBindingSha256: $checkedConvert(
      'impactBindingSha256',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseReleaseImpactResponseToJson(
  CourseReleaseImpactResponse instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'targetReleaseId': instance.targetReleaseId,
  'expectedActiveReleaseId': instance.expectedActiveReleaseId,
  'sourceChangeSetId': instance.sourceChangeSetId,
  'operation': _$CourseReleaseOperationEnumMap[instance.operation]!,
  'releaseRevision': instance.releaseRevision,
  'targetQuestionCount': instance.targetQuestionCount,
  'unchangedQuestionCount': instance.unchangedQuestionCount,
  'changedQuestionCount': instance.changedQuestionCount,
  'addedQuestionCount': instance.addedQuestionCount,
  'removedQuestionCount': instance.removedQuestionCount,
  'affectedEnrollmentCount': instance.affectedEnrollmentCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities.toList(),
  'impactBindingSha256': instance.impactBindingSha256,
};

const _$CourseReleaseOperationEnumMap = {
  CourseReleaseOperation.INITIAL_PUBLICATION: 'INITIAL_PUBLICATION',
  CourseReleaseOperation.PUBLICATION: 'PUBLICATION',
  CourseReleaseOperation.ROLLBACK: 'ROLLBACK',
};
