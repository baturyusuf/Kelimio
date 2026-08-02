// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_commit_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportCommitSummary _$CourseImportCommitSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportCommitSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'contentChangeSetId',
      'draftReleaseId',
      'sourceRowCount',
      'questionCount',
      'matchingQuestionCount',
      'requiredClientCapabilities',
      'committedAt',
    ],
  );
  final val = CourseImportCommitSummary(
    courseId: $checkedConvert('courseId', (v) => v as String),
    contentChangeSetId: $checkedConvert(
      'contentChangeSetId',
      (v) => v as String,
    ),
    draftReleaseId: $checkedConvert('draftReleaseId', (v) => v as String),
    sourceRowCount: $checkedConvert(
      'sourceRowCount',
      (v) => (v as num).toInt(),
    ),
    questionCount: $checkedConvert('questionCount', (v) => (v as num).toInt()),
    matchingQuestionCount: $checkedConvert(
      'matchingQuestionCount',
      (v) => (v as num).toInt(),
    ),
    requiredClientCapabilities: $checkedConvert(
      'requiredClientCapabilities',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    committedAt: $checkedConvert(
      'committedAt',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseImportCommitSummaryToJson(
  CourseImportCommitSummary instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'contentChangeSetId': instance.contentChangeSetId,
  'draftReleaseId': instance.draftReleaseId,
  'sourceRowCount': instance.sourceRowCount,
  'questionCount': instance.questionCount,
  'matchingQuestionCount': instance.matchingQuestionCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities.toList(),
  'committedAt': instance.committedAt.toIso8601String(),
};
