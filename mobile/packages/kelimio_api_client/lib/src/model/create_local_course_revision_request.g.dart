// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_local_course_revision_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateLocalCourseRevisionRequest _$CreateLocalCourseRevisionRequestFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('CreateLocalCourseRevisionRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['baseReleaseId']);
      final val = CreateLocalCourseRevisionRequest(
        baseReleaseId: $checkedConvert('baseReleaseId', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$CreateLocalCourseRevisionRequestToJson(
  CreateLocalCourseRevisionRequest instance,
) => <String, dynamic>{'baseReleaseId': instance.baseReleaseId};
