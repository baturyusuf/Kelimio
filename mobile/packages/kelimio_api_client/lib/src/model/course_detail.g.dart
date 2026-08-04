// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseDetail _$CourseDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CourseDetail', json, ($checkedConvert) {
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
          'ownerDisplayName',
          'releaseId',
          'tests',
        ],
      );
      final val = CourseDetail(
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
          (v) => $enumDecode(_$CourseDetailAccessTypeEnumEnumMap, v),
        ),
        visibility: $checkedConvert(
          'visibility',
          (v) => $enumDecode(_$CourseDetailVisibilityEnumEnumMap, v),
        ),
        enrolled: $checkedConvert('enrolled', (v) => v as bool),
        ownerDisplayName: $checkedConvert(
          'ownerDisplayName',
          (v) => v as String,
        ),
        releaseId: $checkedConvert('releaseId', (v) => v as String),
        tests: $checkedConvert(
          'tests',
          (v) => (v as List<dynamic>)
              .map((e) => TestSummary.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CourseDetailToJson(CourseDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      if (instance.description case final value?) 'description': value,
      'targetLanguage': instance.targetLanguage,
      'supportLanguages': instance.supportLanguages.toList(),
      'accessType': _$CourseDetailAccessTypeEnumEnumMap[instance.accessType]!,
      'visibility': _$CourseDetailVisibilityEnumEnumMap[instance.visibility]!,
      'enrolled': instance.enrolled,
      'ownerDisplayName': instance.ownerDisplayName,
      'releaseId': instance.releaseId,
      'tests': instance.tests.map((e) => e.toJson()).toList(),
    };

const _$CourseDetailAccessTypeEnumEnumMap = {
  CourseDetailAccessTypeEnum.FREE: 'FREE',
  CourseDetailAccessTypeEnum.PAID: 'PAID',
};

const _$CourseDetailVisibilityEnumEnumMap = {
  CourseDetailVisibilityEnum.PUBLIC: 'PUBLIC',
  CourseDetailVisibilityEnum.PRIVATE: 'PRIVATE',
};
