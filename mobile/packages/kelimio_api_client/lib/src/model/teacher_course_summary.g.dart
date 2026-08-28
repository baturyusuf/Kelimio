// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TeacherCourseSummary _$TeacherCourseSummaryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TeacherCourseSummary', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'name',
      'targetLanguage',
      'defaultSupportLanguage',
      'visibility',
      'publicationStatus',
      'activeReleaseId',
      'activeReleaseRevision',
      'hasOpenDraft',
      'createdAt',
    ],
  );
  final val = TeacherCourseSummary(
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
    targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
    defaultSupportLanguage: $checkedConvert(
      'defaultSupportLanguage',
      (v) => v as String,
    ),
    visibility: $checkedConvert(
      'visibility',
      (v) => $enumDecode(_$TeacherCourseSummaryVisibilityEnumEnumMap, v),
    ),
    publicationStatus: $checkedConvert(
      'publicationStatus',
      (v) => $enumDecode(_$TeacherCourseSummaryPublicationStatusEnumEnumMap, v),
    ),
    activeReleaseId: $checkedConvert('activeReleaseId', (v) => v as String),
    activeReleaseRevision: $checkedConvert(
      'activeReleaseRevision',
      (v) => (v as num).toInt(),
    ),
    hasOpenDraft: $checkedConvert('hasOpenDraft', (v) => v as bool),
    openDraftReleaseId: $checkedConvert(
      'openDraftReleaseId',
      (v) => v as String?,
    ),
    createdAt: $checkedConvert('createdAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$TeacherCourseSummaryToJson(
  TeacherCourseSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  if (instance.description case final value?) 'description': value,
  'targetLanguage': instance.targetLanguage,
  'defaultSupportLanguage': instance.defaultSupportLanguage,
  'visibility':
      _$TeacherCourseSummaryVisibilityEnumEnumMap[instance.visibility]!,
  'publicationStatus':
      _$TeacherCourseSummaryPublicationStatusEnumEnumMap[instance
          .publicationStatus]!,
  'activeReleaseId': instance.activeReleaseId,
  'activeReleaseRevision': instance.activeReleaseRevision,
  'hasOpenDraft': instance.hasOpenDraft,
  if (instance.openDraftReleaseId case final value?)
    'openDraftReleaseId': value,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$TeacherCourseSummaryVisibilityEnumEnumMap = {
  TeacherCourseSummaryVisibilityEnum.PUBLIC: 'PUBLIC',
  TeacherCourseSummaryVisibilityEnum.PRIVATE: 'PRIVATE',
};

const _$TeacherCourseSummaryPublicationStatusEnumEnumMap = {
  TeacherCourseSummaryPublicationStatusEnum.PUBLISHED: 'PUBLISHED',
  TeacherCourseSummaryPublicationStatusEnum.HIDDEN: 'HIDDEN',
};
