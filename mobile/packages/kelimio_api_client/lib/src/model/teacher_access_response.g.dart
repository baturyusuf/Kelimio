// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_access_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherAccessResponse _$TeacherAccessResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TeacherAccessResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'eligible',
      'termsAccepted',
      'productionFeaturesEnabled',
      'requiredTermsVersion',
    ],
  );
  final val = TeacherAccessResponse(
    eligible: $checkedConvert('eligible', (v) => v as bool),
    termsAccepted: $checkedConvert('termsAccepted', (v) => v as bool),
    productionFeaturesEnabled: $checkedConvert(
      'productionFeaturesEnabled',
      (v) => v as bool,
    ),
    requiredTermsVersion: $checkedConvert(
      'requiredTermsVersion',
      (v) => v as String,
    ),
  );
  return val;
});

Map<String, dynamic> _$TeacherAccessResponseToJson(
  TeacherAccessResponse instance,
) => <String, dynamic>{
  'eligible': instance.eligible,
  'termsAccepted': instance.termsAccepted,
  'productionFeaturesEnabled': instance.productionFeaturesEnabled,
  'requiredTermsVersion': instance.requiredTermsVersion,
};
