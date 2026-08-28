// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accept_course_invitation_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcceptCourseInvitationRequest _$AcceptCourseInvitationRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AcceptCourseInvitationRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['supportLanguage']);
  final val = AcceptCourseInvitationRequest(
    supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$AcceptCourseInvitationRequestToJson(
  AcceptCourseInvitationRequest instance,
) => <String, dynamic>{'supportLanguage': instance.supportLanguage};
