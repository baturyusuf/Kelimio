// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_full_course_editor_draft_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SaveFullCourseEditorDraftRequest _$SaveFullCourseEditorDraftRequestFromJson(
  Map<String, dynamic> json,
) =>
    $checkedCreate('SaveFullCourseEditorDraftRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['baseReleaseId', 'name', 'visibility', 'levels'],
      );
      final val = SaveFullCourseEditorDraftRequest(
        baseReleaseId: $checkedConvert('baseReleaseId', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        description: $checkedConvert('description', (v) => v as String?),
        visibility: $checkedConvert(
          'visibility',
          (v) => $enumDecode(
            _$SaveFullCourseEditorDraftRequestVisibilityEnumEnumMap,
            v,
          ),
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

Map<String, dynamic> _$SaveFullCourseEditorDraftRequestToJson(
  SaveFullCourseEditorDraftRequest instance,
) => <String, dynamic>{
  'baseReleaseId': instance.baseReleaseId,
  'name': instance.name,
  if (instance.description case final value?) 'description': value,
  'visibility':
      _$SaveFullCourseEditorDraftRequestVisibilityEnumEnumMap[instance
          .visibility]!,
  'levels': instance.levels.map((e) => e.toJson()).toList(),
};

const _$SaveFullCourseEditorDraftRequestVisibilityEnumEnumMap = {
  SaveFullCourseEditorDraftRequestVisibilityEnum.PUBLIC: 'PUBLIC',
  SaveFullCourseEditorDraftRequestVisibilityEnum.PRIVATE: 'PRIVATE',
};
