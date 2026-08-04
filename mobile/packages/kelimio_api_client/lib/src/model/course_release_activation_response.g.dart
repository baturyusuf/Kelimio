// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_release_activation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseReleaseActivationResponse _$CourseReleaseActivationResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseReleaseActivationResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'activationId',
      'courseId',
      'releaseId',
      'previousReleaseId',
      'sourceChangeSetId',
      'operation',
      'releaseRevision',
      'questionCount',
      'requiredClientCapabilities',
      'coursePublicationStatus',
      'reprojectionStatus',
      'activatedAt',
      'created',
    ],
  );
  final val = CourseReleaseActivationResponse(
    activationId: $checkedConvert('activationId', (v) => v as String),
    courseId: $checkedConvert('courseId', (v) => v as String),
    releaseId: $checkedConvert('releaseId', (v) => v as String),
    previousReleaseId: $checkedConvert(
      'previousReleaseId',
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
    questionCount: $checkedConvert('questionCount', (v) => (v as num).toInt()),
    requiredClientCapabilities: $checkedConvert(
      'requiredClientCapabilities',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    coursePublicationStatus: $checkedConvert(
      'coursePublicationStatus',
      (v) => $enumDecode(
        _$CourseReleaseActivationResponseCoursePublicationStatusEnumEnumMap,
        v,
      ),
    ),
    reprojectionStatus: $checkedConvert(
      'reprojectionStatus',
      (v) => $enumDecode(
        _$CourseReleaseActivationResponseReprojectionStatusEnumEnumMap,
        v,
      ),
    ),
    activatedAt: $checkedConvert(
      'activatedAt',
      (v) => DateTime.parse(v as String),
    ),
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$CourseReleaseActivationResponseToJson(
  CourseReleaseActivationResponse instance,
) => <String, dynamic>{
  'activationId': instance.activationId,
  'courseId': instance.courseId,
  'releaseId': instance.releaseId,
  'previousReleaseId': instance.previousReleaseId,
  'sourceChangeSetId': instance.sourceChangeSetId,
  'operation': _$CourseReleaseOperationEnumMap[instance.operation]!,
  'releaseRevision': instance.releaseRevision,
  'questionCount': instance.questionCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities.toList(),
  'coursePublicationStatus':
      _$CourseReleaseActivationResponseCoursePublicationStatusEnumEnumMap[instance
          .coursePublicationStatus]!,
  'reprojectionStatus':
      _$CourseReleaseActivationResponseReprojectionStatusEnumEnumMap[instance
          .reprojectionStatus]!,
  'activatedAt': instance.activatedAt.toIso8601String(),
  'created': instance.created,
};

const _$CourseReleaseOperationEnumMap = {
  CourseReleaseOperation.INITIAL_PUBLICATION: 'INITIAL_PUBLICATION',
  CourseReleaseOperation.PUBLICATION: 'PUBLICATION',
  CourseReleaseOperation.ROLLBACK: 'ROLLBACK',
};

const _$CourseReleaseActivationResponseCoursePublicationStatusEnumEnumMap = {
  CourseReleaseActivationResponseCoursePublicationStatusEnum.PUBLISHED:
      'PUBLISHED',
  CourseReleaseActivationResponseCoursePublicationStatusEnum.HIDDEN: 'HIDDEN',
};

const _$CourseReleaseActivationResponseReprojectionStatusEnumEnumMap = {
  CourseReleaseActivationResponseReprojectionStatusEnum.PENDING: 'PENDING',
  CourseReleaseActivationResponseReprojectionStatusEnum.FAILED: 'FAILED',
  CourseReleaseActivationResponseReprojectionStatusEnum.COMPLETED: 'COMPLETED',
  CourseReleaseActivationResponseReprojectionStatusEnum.DEAD: 'DEAD',
};
