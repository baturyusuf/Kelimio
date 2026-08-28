// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_course_invitation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCourseInvitationRequest _$CreateCourseInvitationRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateCourseInvitationRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['maxUses', 'expiresInHours']);
  final val = CreateCourseInvitationRequest(
    maxUses: $checkedConvert('maxUses', (v) => (v as num?)?.toInt() ?? 1),
    expiresInHours: $checkedConvert(
      'expiresInHours',
      (v) => (v as num?)?.toInt() ?? 168,
    ),
  );
  return val;
});

Map<String, dynamic> _$CreateCourseInvitationRequestToJson(
  CreateCourseInvitationRequest instance,
) => <String, dynamic>{
  'maxUses': instance.maxUses,
  'expiresInHours': instance.expiresInHours,
};
