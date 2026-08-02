// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subsequent_course_draft_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubsequentCourseDraftResult _$SubsequentCourseDraftResultFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('SubsequentCourseDraftResult', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'baseReleaseId',
      'contentChangeSetId',
      'draftReleaseId',
      'releaseRevision',
      'changedQuestionId',
      'previousQuestionRevisionId',
      'questionRevisionId',
      'changedTestId',
      'previousTestRevisionId',
      'testRevisionId',
      'createdAt',
      'created',
    ],
  );
  final val = SubsequentCourseDraftResult(
    courseId: $checkedConvert('courseId', (v) => v as String),
    baseReleaseId: $checkedConvert('baseReleaseId', (v) => v as String),
    contentChangeSetId: $checkedConvert(
      'contentChangeSetId',
      (v) => v as String,
    ),
    draftReleaseId: $checkedConvert('draftReleaseId', (v) => v as String),
    releaseRevision: $checkedConvert(
      'releaseRevision',
      (v) => (v as num).toInt(),
    ),
    changedQuestionId: $checkedConvert('changedQuestionId', (v) => v as String),
    previousQuestionRevisionId: $checkedConvert(
      'previousQuestionRevisionId',
      (v) => v as String,
    ),
    questionRevisionId: $checkedConvert(
      'questionRevisionId',
      (v) => v as String,
    ),
    changedTestId: $checkedConvert('changedTestId', (v) => v as String),
    previousTestRevisionId: $checkedConvert(
      'previousTestRevisionId',
      (v) => v as String,
    ),
    testRevisionId: $checkedConvert('testRevisionId', (v) => v as String),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$SubsequentCourseDraftResultToJson(
  SubsequentCourseDraftResult instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'baseReleaseId': instance.baseReleaseId,
  'contentChangeSetId': instance.contentChangeSetId,
  'draftReleaseId': instance.draftReleaseId,
  'releaseRevision': instance.releaseRevision,
  'changedQuestionId': instance.changedQuestionId,
  'previousQuestionRevisionId': instance.previousQuestionRevisionId,
  'questionRevisionId': instance.questionRevisionId,
  'changedTestId': instance.changedTestId,
  'previousTestRevisionId': instance.previousTestRevisionId,
  'testRevisionId': instance.testRevisionId,
  'createdAt': instance.createdAt.toIso8601String(),
  'created': instance.created,
};
