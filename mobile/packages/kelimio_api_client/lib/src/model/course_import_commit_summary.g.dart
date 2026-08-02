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
  'committedAt': instance.committedAt.toIso8601String(),
};
