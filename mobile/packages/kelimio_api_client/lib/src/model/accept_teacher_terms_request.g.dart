// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accept_teacher_terms_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AcceptTeacherTermsRequest _$AcceptTeacherTermsRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AcceptTeacherTermsRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['termsVersion']);
  final val = AcceptTeacherTermsRequest(
    termsVersion: $checkedConvert('termsVersion', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$AcceptTeacherTermsRequestToJson(
  AcceptTeacherTermsRequest instance,
) => <String, dynamic>{'termsVersion': instance.termsVersion};
