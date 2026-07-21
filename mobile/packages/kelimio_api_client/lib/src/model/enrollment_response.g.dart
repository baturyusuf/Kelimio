// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enrollment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnrollmentResponse _$EnrollmentResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnrollmentResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'courseId',
          'supportLanguage',
          'status',
          'enrolledAt',
        ],
      );
      final val = EnrollmentResponse(
        id: $checkedConvert('id', (v) => v as String),
        courseId: $checkedConvert('courseId', (v) => v as String),
        supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(_$EnrollmentResponseStatusEnumEnumMap, v),
        ),
        enrolledAt: $checkedConvert(
          'enrolledAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$EnrollmentResponseToJson(EnrollmentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'courseId': instance.courseId,
      'supportLanguage': instance.supportLanguage,
      'status': _$EnrollmentResponseStatusEnumEnumMap[instance.status]!,
      'enrolledAt': instance.enrolledAt.toIso8601String(),
    };

const _$EnrollmentResponseStatusEnumEnumMap = {
  EnrollmentResponseStatusEnum.ACTIVE: 'ACTIVE',
};
