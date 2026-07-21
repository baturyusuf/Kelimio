// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseSummary _$CourseSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseSummary', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'name',
          'targetLanguage',
          'supportLanguages',
          'accessType',
          'visibility',
          'enrolled',
        ],
      );
      final val = CourseSummary(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String?),
        targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
        supportLanguages: $checkedConvert(
          'supportLanguages',
          (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
        ),
        accessType: $checkedConvert(
          'accessType',
          (v) => $enumDecode(_$CourseSummaryAccessTypeEnumEnumMap, v),
        ),
        visibility: $checkedConvert(
          'visibility',
          (v) => $enumDecode(_$CourseSummaryVisibilityEnumEnumMap, v),
        ),
        enrolled: $checkedConvert('enrolled', (v) => v as bool),
      );
      return val;
    });

Map<String, dynamic> _$CourseSummaryToJson(CourseSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.description case final value?) 'description': value,
      'targetLanguage': instance.targetLanguage,
      'supportLanguages': instance.supportLanguages.toList(),
      'accessType': _$CourseSummaryAccessTypeEnumEnumMap[instance.accessType]!,
      'visibility': _$CourseSummaryVisibilityEnumEnumMap[instance.visibility]!,
      'enrolled': instance.enrolled,
    };

const _$CourseSummaryAccessTypeEnumEnumMap = {
  CourseSummaryAccessTypeEnum.FREE: 'FREE',
  CourseSummaryAccessTypeEnum.PAID: 'PAID',
};

const _$CourseSummaryVisibilityEnumEnumMap = {
  CourseSummaryVisibilityEnum.PUBLIC: 'PUBLIC',
  CourseSummaryVisibilityEnum.PRIVATE: 'PRIVATE',
};
