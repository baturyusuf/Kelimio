// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_preview_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPreviewSettings _$CourseImportPreviewSettingsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPreviewSettings', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseName',
      'targetLanguageCode',
      'targetLanguageName',
      'supportLanguageCodes',
      'defaultSupportLanguageCode',
      'defaultTestMode',
      'visibility',
      'targetTestSize',
      'minimumLastAutomaticTestSize',
      'fillFixedTests',
      'completionThresholdPercent',
      'pricingSource',
      'maximumTypedAlternativeAnswers',
      'offlineMode',
    ],
  );
  final val = CourseImportPreviewSettings(
    courseName: $checkedConvert('courseName', (v) => v as String),
    targetLanguageCode: $checkedConvert(
      'targetLanguageCode',
      (v) => v as String,
    ),
    targetLanguageName: $checkedConvert(
      'targetLanguageName',
      (v) => v as String,
    ),
    supportLanguageCodes: $checkedConvert(
      'supportLanguageCodes',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    defaultSupportLanguageCode: $checkedConvert(
      'defaultSupportLanguageCode',
      (v) => v as String,
    ),
    defaultTestMode: $checkedConvert(
      'defaultTestMode',
      (v) => $enumDecode(
        _$CourseImportPreviewSettingsDefaultTestModeEnumEnumMap,
        v,
      ),
    ),
    visibility: $checkedConvert(
      'visibility',
      (v) => $enumDecode(_$CourseImportPreviewSettingsVisibilityEnumEnumMap, v),
    ),
    targetTestSize: $checkedConvert(
      'targetTestSize',
      (v) => (v as num).toInt(),
    ),
    minimumLastAutomaticTestSize: $checkedConvert(
      'minimumLastAutomaticTestSize',
      (v) => (v as num).toInt(),
    ),
    fillFixedTests: $checkedConvert('fillFixedTests', (v) => v as bool),
    completionThresholdPercent: $checkedConvert(
      'completionThresholdPercent',
      (v) => (v as num).toInt(),
    ),
    pricingSource: $checkedConvert(
      'pricingSource',
      (v) =>
          $enumDecode(_$CourseImportPreviewSettingsPricingSourceEnumEnumMap, v),
    ),
    maximumTypedAlternativeAnswers: $checkedConvert(
      'maximumTypedAlternativeAnswers',
      (v) => $enumDecode(
        _$CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnumEnumMap,
        v,
      ),
    ),
    offlineMode: $checkedConvert(
      'offlineMode',
      (v) =>
          $enumDecode(_$CourseImportPreviewSettingsOfflineModeEnumEnumMap, v),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPreviewSettingsToJson(
  CourseImportPreviewSettings instance,
) => <String, dynamic>{
  'courseName': instance.courseName,
  'targetLanguageCode': instance.targetLanguageCode,
  'targetLanguageName': instance.targetLanguageName,
  'supportLanguageCodes': instance.supportLanguageCodes.toList(),
  'defaultSupportLanguageCode': instance.defaultSupportLanguageCode,
  'defaultTestMode':
      _$CourseImportPreviewSettingsDefaultTestModeEnumEnumMap[instance
          .defaultTestMode]!,
  'visibility':
      _$CourseImportPreviewSettingsVisibilityEnumEnumMap[instance.visibility]!,
  'targetTestSize': instance.targetTestSize,
  'minimumLastAutomaticTestSize': instance.minimumLastAutomaticTestSize,
  'fillFixedTests': instance.fillFixedTests,
  'completionThresholdPercent': instance.completionThresholdPercent,
  'pricingSource':
      _$CourseImportPreviewSettingsPricingSourceEnumEnumMap[instance
          .pricingSource]!,
  'maximumTypedAlternativeAnswers':
      _$CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnumEnumMap[instance
          .maximumTypedAlternativeAnswers]!,
  'offlineMode':
      _$CourseImportPreviewSettingsOfflineModeEnumEnumMap[instance
          .offlineMode]!,
};

const _$CourseImportPreviewSettingsDefaultTestModeEnumEnumMap = {
  CourseImportPreviewSettingsDefaultTestModeEnum.MIXED: 'MIXED',
  CourseImportPreviewSettingsDefaultTestModeEnum.WORD: 'WORD',
  CourseImportPreviewSettingsDefaultTestModeEnum.MATCHING: 'MATCHING',
  CourseImportPreviewSettingsDefaultTestModeEnum.MULTIPLE_CHOICE_CLOZE:
      'MULTIPLE_CHOICE_CLOZE',
  CourseImportPreviewSettingsDefaultTestModeEnum.TYPED_CLOZE: 'TYPED_CLOZE',
};

const _$CourseImportPreviewSettingsVisibilityEnumEnumMap = {
  CourseImportPreviewSettingsVisibilityEnum.PUBLIC: 'PUBLIC',
  CourseImportPreviewSettingsVisibilityEnum.PRIVATE: 'PRIVATE',
};

const _$CourseImportPreviewSettingsPricingSourceEnumEnumMap = {
  CourseImportPreviewSettingsPricingSourceEnum.APPLICATION: 'APPLICATION',
};

const _$CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnumEnumMap = {
  CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnum.number1: 1,
};

const _$CourseImportPreviewSettingsOfflineModeEnumEnumMap = {
  CourseImportPreviewSettingsOfflineModeEnum.SCORELESS_PRACTICE:
      'SCORELESS_PRACTICE',
};
