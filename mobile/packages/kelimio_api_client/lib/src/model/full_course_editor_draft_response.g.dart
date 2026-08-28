// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'full_course_editor_draft_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FullCourseEditorDraftResponse _$FullCourseEditorDraftResponseFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FullCourseEditorDraftResponse', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'baseReleaseId',
      'contentChangeSetId',
      'draftReleaseId',
      'releaseRevision',
      'questionCount',
      'requiredClientCapabilities',
      'createdAt',
      'created',
    ],
  );
  final val = FullCourseEditorDraftResponse(
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
    questionCount: $checkedConvert('questionCount', (v) => (v as num).toInt()),
    requiredClientCapabilities: $checkedConvert(
      'requiredClientCapabilities',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$FullCourseEditorDraftResponseToJson(
  FullCourseEditorDraftResponse instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'baseReleaseId': instance.baseReleaseId,
  'contentChangeSetId': instance.contentChangeSetId,
  'draftReleaseId': instance.draftReleaseId,
  'releaseRevision': instance.releaseRevision,
  'questionCount': instance.questionCount,
  'requiredClientCapabilities': instance.requiredClientCapabilities.toList(),
  'createdAt': instance.createdAt.toIso8601String(),
  'created': instance.created,
};
