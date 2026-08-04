//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_preview_settings.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPreviewSettings {
  /// Returns a new [CourseImportPreviewSettings] instance.
  CourseImportPreviewSettings({
    required this.courseName,

    required this.targetLanguageCode,

    required this.targetLanguageName,

    required this.supportLanguageCodes,

    required this.defaultSupportLanguageCode,

    required this.defaultTestMode,

    required this.visibility,

    required this.targetTestSize,

    required this.minimumLastAutomaticTestSize,

    required this.fillFixedTests,

    required this.completionThresholdPercent,

    required this.pricingSource,

    required this.maximumTypedAlternativeAnswers,

    required this.offlineMode,
  });

  @JsonKey(name: r'courseName', required: true, includeIfNull: false)
  final String courseName;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'targetLanguageCode', required: true, includeIfNull: false)
  final String targetLanguageCode;

  @JsonKey(name: r'targetLanguageName', required: true, includeIfNull: false)
  final String targetLanguageName;

  @JsonKey(name: r'supportLanguageCodes', required: true, includeIfNull: false)
  final Set<String> supportLanguageCodes;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(
    name: r'defaultSupportLanguageCode',
    required: true,
    includeIfNull: false,
  )
  final String defaultSupportLanguageCode;

  @JsonKey(name: r'defaultTestMode', required: true, includeIfNull: false)
  final CourseImportPreviewSettingsDefaultTestModeEnum defaultTestMode;

  @JsonKey(name: r'visibility', required: true, includeIfNull: false)
  final CourseImportPreviewSettingsVisibilityEnum visibility;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'targetTestSize', required: true, includeIfNull: false)
  final int targetTestSize;

  // minimum: 1
  // maximum: 10000
  @JsonKey(
    name: r'minimumLastAutomaticTestSize',
    required: true,
    includeIfNull: false,
  )
  final int minimumLastAutomaticTestSize;

  @JsonKey(name: r'fillFixedTests', required: true, includeIfNull: false)
  final bool fillFixedTests;

  // minimum: 50
  // maximum: 100
  @JsonKey(
    name: r'completionThresholdPercent',
    required: true,
    includeIfNull: false,
  )
  final int completionThresholdPercent;

  @JsonKey(name: r'pricingSource', required: true, includeIfNull: false)
  final CourseImportPreviewSettingsPricingSourceEnum pricingSource;

  @JsonKey(
    name: r'maximumTypedAlternativeAnswers',
    required: true,
    includeIfNull: false,
  )
  final CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnum
  maximumTypedAlternativeAnswers;

  @JsonKey(name: r'offlineMode', required: true, includeIfNull: false)
  final CourseImportPreviewSettingsOfflineModeEnum offlineMode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPreviewSettings &&
          other.courseName == courseName &&
          other.targetLanguageCode == targetLanguageCode &&
          other.targetLanguageName == targetLanguageName &&
          other.supportLanguageCodes == supportLanguageCodes &&
          other.defaultSupportLanguageCode == defaultSupportLanguageCode &&
          other.defaultTestMode == defaultTestMode &&
          other.visibility == visibility &&
          other.targetTestSize == targetTestSize &&
          other.minimumLastAutomaticTestSize == minimumLastAutomaticTestSize &&
          other.fillFixedTests == fillFixedTests &&
          other.completionThresholdPercent == completionThresholdPercent &&
          other.pricingSource == pricingSource &&
          other.maximumTypedAlternativeAnswers ==
              maximumTypedAlternativeAnswers &&
          other.offlineMode == offlineMode;

  @override
  int get hashCode =>
      courseName.hashCode +
      targetLanguageCode.hashCode +
      targetLanguageName.hashCode +
      supportLanguageCodes.hashCode +
      defaultSupportLanguageCode.hashCode +
      defaultTestMode.hashCode +
      visibility.hashCode +
      targetTestSize.hashCode +
      minimumLastAutomaticTestSize.hashCode +
      fillFixedTests.hashCode +
      completionThresholdPercent.hashCode +
      pricingSource.hashCode +
      maximumTypedAlternativeAnswers.hashCode +
      offlineMode.hashCode;

  factory CourseImportPreviewSettings.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPreviewSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPreviewSettingsToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'courseName')) {
      json[r'courseName'] = '[REDACTED]';
    }
    if (json.containsKey(r'targetLanguageName')) {
      json[r'targetLanguageName'] = '[REDACTED]';
    }
    if (json.containsKey(r'supportLanguageCodes')) {
      json[r'supportLanguageCodes'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportPreviewSettingsDefaultTestModeEnum {
  @JsonValue(r'MIXED')
  MIXED(r'MIXED'),
  @JsonValue(r'WORD')
  WORD(r'WORD'),
  @JsonValue(r'MATCHING')
  MATCHING(r'MATCHING'),
  @JsonValue(r'MULTIPLE_CHOICE_CLOZE')
  MULTIPLE_CHOICE_CLOZE(r'MULTIPLE_CHOICE_CLOZE'),
  @JsonValue(r'TYPED_CLOZE')
  TYPED_CLOZE(r'TYPED_CLOZE');

  const CourseImportPreviewSettingsDefaultTestModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewSettingsVisibilityEnum {
  @JsonValue(r'PUBLIC')
  PUBLIC(r'PUBLIC'),
  @JsonValue(r'PRIVATE')
  PRIVATE(r'PRIVATE');

  const CourseImportPreviewSettingsVisibilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewSettingsPricingSourceEnum {
  @JsonValue(r'APPLICATION')
  APPLICATION(r'APPLICATION');

  const CourseImportPreviewSettingsPricingSourceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnum {
  @JsonValue(1)
  number1('1');

  const CourseImportPreviewSettingsMaximumTypedAlternativeAnswersEnum(
    this.value,
  );

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewSettingsOfflineModeEnum {
  @JsonValue(r'SCORELESS_PRACTICE')
  SCORELESS_PRACTICE(r'SCORELESS_PRACTICE');

  const CourseImportPreviewSettingsOfflineModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
