// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_invitation_accepted.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseInvitationAccepted _$CourseInvitationAcceptedFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseInvitationAccepted', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'enrollmentId',
      'supportLanguage',
      'acceptedAt',
    ],
  );
  final val = CourseInvitationAccepted(
    courseId: $checkedConvert('courseId', (v) => v as String),
    enrollmentId: $checkedConvert('enrollmentId', (v) => v as String),
    supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
    acceptedAt: $checkedConvert(
      'acceptedAt',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseInvitationAcceptedToJson(
  CourseInvitationAccepted instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'enrollmentId': instance.enrollmentId,
  'supportLanguage': instance.supportLanguage,
  'acceptedAt': instance.acceptedAt.toIso8601String(),
};
