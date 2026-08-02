// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_course_editor_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalCourseEditorSnapshot _$LocalCourseEditorSnapshotFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LocalCourseEditorSnapshot', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'courseName',
      'activeReleaseId',
      'releaseRevision',
      'levelTitle',
      'unitTitle',
      'topicTitle',
      'testId',
      'testTitle',
      'questionId',
      'questionRevisionId',
      'questionRevision',
      'prompt',
    ],
  );
  final val = LocalCourseEditorSnapshot(
    courseId: $checkedConvert('courseId', (v) => v as String),
    courseName: $checkedConvert('courseName', (v) => v as String),
    activeReleaseId: $checkedConvert('activeReleaseId', (v) => v as String),
    releaseRevision: $checkedConvert(
      'releaseRevision',
      (v) => (v as num).toInt(),
    ),
    levelTitle: $checkedConvert('levelTitle', (v) => v as String),
    unitTitle: $checkedConvert('unitTitle', (v) => v as String),
    topicTitle: $checkedConvert('topicTitle', (v) => v as String),
    testId: $checkedConvert('testId', (v) => v as String),
    testTitle: $checkedConvert('testTitle', (v) => v as String),
    questionId: $checkedConvert('questionId', (v) => v as String),
    questionRevisionId: $checkedConvert(
      'questionRevisionId',
      (v) => v as String,
    ),
    questionRevision: $checkedConvert(
      'questionRevision',
      (v) => (v as num).toInt(),
    ),
    prompt: $checkedConvert('prompt', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$LocalCourseEditorSnapshotToJson(
  LocalCourseEditorSnapshot instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'courseName': instance.courseName,
  'activeReleaseId': instance.activeReleaseId,
  'releaseRevision': instance.releaseRevision,
  'levelTitle': instance.levelTitle,
  'unitTitle': instance.unitTitle,
  'topicTitle': instance.topicTitle,
  'testId': instance.testId,
  'testTitle': instance.testTitle,
  'questionId': instance.questionId,
  'questionRevisionId': instance.questionRevisionId,
  'questionRevision': instance.questionRevision,
  'prompt': instance.prompt,
};
