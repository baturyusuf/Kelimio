// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'full_course_editor_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FullCourseEditorDocument _$FullCourseEditorDocumentFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('FullCourseEditorDocument', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'courseId',
      'activeReleaseId',
      'releaseRevision',
      'name',
      'visibility',
      'targetLanguage',
      'defaultSupportLanguage',
      'supportLanguages',
      'levels',
    ],
  );
  final val = FullCourseEditorDocument(
    courseId: $checkedConvert('courseId', (v) => v as String),
    activeReleaseId: $checkedConvert('activeReleaseId', (v) => v as String),
    releaseRevision: $checkedConvert(
      'releaseRevision',
      (v) => (v as num).toInt(),
    ),
    name: $checkedConvert('name', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String?),
    visibility: $checkedConvert(
      'visibility',
      (v) => $enumDecode(_$FullCourseEditorDocumentVisibilityEnumEnumMap, v),
    ),
    targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
    defaultSupportLanguage: $checkedConvert(
      'defaultSupportLanguage',
      (v) => v as String,
    ),
    supportLanguages: $checkedConvert(
      'supportLanguages',
      (v) => (v as List<dynamic>).map((e) => e as String).toSet(),
    ),
    levels: $checkedConvert(
      'levels',
      (v) => (v as List<dynamic>)
          .map((e) => CourseEditorLevel.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$FullCourseEditorDocumentToJson(
  FullCourseEditorDocument instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'activeReleaseId': instance.activeReleaseId,
  'releaseRevision': instance.releaseRevision,
  'name': instance.name,
  if (instance.description case final value?) 'description': value,
  'visibility':
      _$FullCourseEditorDocumentVisibilityEnumEnumMap[instance.visibility]!,
  'targetLanguage': instance.targetLanguage,
  'defaultSupportLanguage': instance.defaultSupportLanguage,
  'supportLanguages': instance.supportLanguages.toList(),
  'levels': instance.levels.map((e) => e.toJson()).toList(),
};

const _$FullCourseEditorDocumentVisibilityEnumEnumMap = {
  FullCourseEditorDocumentVisibilityEnum.PUBLIC: 'PUBLIC',
  FullCourseEditorDocumentVisibilityEnum.PRIVATE: 'PRIVATE',
};
