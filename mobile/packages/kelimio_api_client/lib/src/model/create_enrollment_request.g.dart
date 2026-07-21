// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_enrollment_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateEnrollmentRequest _$CreateEnrollmentRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CreateEnrollmentRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['supportLanguage']);
  final val = CreateEnrollmentRequest(
    supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$CreateEnrollmentRequestToJson(
  CreateEnrollmentRequest instance,
) => <String, dynamic>{'supportLanguage': instance.supportLanguage};
