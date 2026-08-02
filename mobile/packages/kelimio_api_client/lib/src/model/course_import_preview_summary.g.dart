// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_preview_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPreviewSummary _$CourseImportPreviewSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPreviewSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'isValid',
      'rowCount',
      'questionCount',
      'matchingQuestionCount',
      'requiredClientCapabilities',
      'levelCount',
      'unitCount',
      'topicCount',
      'testCount',
      'warningCount',
      'errorCount',
      'validationReportSha256',
      'allocationSha256',
      'previewSha256',
      'settings',
    ],
  );
  final val = CourseImportPreviewSummary(
    isValid: $checkedConvert('isValid', (v) => v as bool),
    rowCount: $checkedConvert('rowCount', (v) => (v as num).toInt()),
    questionCount: $checkedConvert(
      'questionCount',
      (v) => (v as num?)?.toInt(),
    ),
    matchingQuestionCount: $checkedConvert(
      'matchingQuestionCount',
      (v) => (v as num?)?.toInt(),
    ),
    requiredClientCapabilities: $checkedConvert(
      'requiredClientCapabilities',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toSet(),
    ),
    levelCount: $checkedConvert('levelCount', (v) => (v as num).toInt()),
    unitCount: $checkedConvert('unitCount', (v) => (v as num).toInt()),
    topicCount: $checkedConvert('topicCount', (v) => (v as num).toInt()),
    testCount: $checkedConvert('testCount', (v) => (v as num).toInt()),
    warningCount: $checkedConvert('warningCount', (v) => (v as num).toInt()),
    errorCount: $checkedConvert('errorCount', (v) => (v as num).toInt()),
    validationReportSha256: $checkedConvert(
      'validationReportSha256',
      (v) => v as String,
    ),
    allocationSha256: $checkedConvert('allocationSha256', (v) => v as String?),
    previewSha256: $checkedConvert('previewSha256', (v) => v as String?),
    settings: $checkedConvert(
      'settings',
      (v) => v == null
          ? null
          : CourseImportPreviewSettings.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPreviewSummaryToJson(
  CourseImportPreviewSummary instance,
) => <String, dynamic>{
  'isValid': instance.isValid,
  'rowCount': instance.rowCount,
  'questionCount': instance.questionCount,
  'matchingQuestionCount': instance.matchingQuestionCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities?.toList(),
  'levelCount': instance.levelCount,
  'unitCount': instance.unitCount,
  'topicCount': instance.topicCount,
  'testCount': instance.testCount,
  'warningCount': instance.warningCount,
  'errorCount': instance.errorCount,
  'validationReportSha256': instance.validationReportSha256,
  'allocationSha256': instance.allocationSha256,
  'previewSha256': instance.previewSha256,
  'settings': instance.settings?.toJson(),
};
