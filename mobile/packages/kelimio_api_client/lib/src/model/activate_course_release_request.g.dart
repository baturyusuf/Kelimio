// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activate_course_release_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivateCourseReleaseRequest _$ActivateCourseReleaseRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ActivateCourseReleaseRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['expectedActiveReleaseId', 'impactBindingSha256'],
  );
  final val = ActivateCourseReleaseRequest(
    expectedActiveReleaseId: $checkedConvert(
      'expectedActiveReleaseId',
      (v) => v as String?,
    ),
    impactBindingSha256: $checkedConvert(
      'impactBindingSha256',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$ActivateCourseReleaseRequestToJson(
  ActivateCourseReleaseRequest instance,
) => <String, dynamic>{
  'expectedActiveReleaseId': instance.expectedActiveReleaseId,
  'impactBindingSha256': instance.impactBindingSha256,
};
