// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_invitation_created.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseInvitationCreated _$CourseInvitationCreatedFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseInvitationCreated', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['id', 'courseId', 'token', 'maxUses', 'expiresAt'],
  );
  final val = CourseInvitationCreated(
    id: $checkedConvert('id', (v) => v as String),
    courseId: $checkedConvert('courseId', (v) => v as String),
    token: $checkedConvert('token', (v) => v as String),
    maxUses: $checkedConvert('maxUses', (v) => (v as num).toInt()),
    expiresAt: $checkedConvert('expiresAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$CourseInvitationCreatedToJson(
  CourseInvitationCreated instance,
) => <String, dynamic>{
  'id': instance.id,
  'courseId': instance.courseId,
  'token': instance.token,
  'maxUses': instance.maxUses,
  'expiresAt': instance.expiresAt.toIso8601String(),
};
