// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_commit_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportCommitResponse _$CourseImportCommitResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportCommitResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'importId',
      'status',
      'courseId',
      'contentChangeSetId',
      'draftReleaseId',
      'sourceRowCount',
      'questionCount',
      'matchingQuestionCount',
      'requiredClientCapabilities',
      'committedAt',
      'created',
    ],
  );
  final val = CourseImportCommitResponse(
    importId: $checkedConvert('importId', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$CourseImportCommitResponseStatusEnumEnumMap, v),
    ),
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
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$CourseImportCommitResponseToJson(
  CourseImportCommitResponse instance,
) => <String, dynamic>{
  'importId': instance.importId,
  'status': _$CourseImportCommitResponseStatusEnumEnumMap[instance.status]!,
  'courseId': instance.courseId,
  'contentChangeSetId': instance.contentChangeSetId,
  'draftReleaseId': instance.draftReleaseId,
  'sourceRowCount': instance.sourceRowCount,
  'questionCount': instance.questionCount,
  'matchingQuestionCount': instance.matchingQuestionCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities.toList(),
  'committedAt': instance.committedAt.toIso8601String(),
  'created': instance.created,
};

const _$CourseImportCommitResponseStatusEnumEnumMap = {
  CourseImportCommitResponseStatusEnum.COMMITTED: 'COMMITTED',
};
