// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_local_course_editor_draft_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateLocalCourseEditorDraftRequest
_$CreateLocalCourseEditorDraftRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CreateLocalCourseEditorDraftRequest', json, (
      $checkedConvert,
    ) {
      $checkKeys(
        json,
        requiredKeys: const [
          'baseReleaseId',
          'questionRevisionId',
          'editedPrompt',
        ],
      );
      final val = CreateLocalCourseEditorDraftRequest(
        baseReleaseId: $checkedConvert('baseReleaseId', (v) => v as String),
        questionRevisionId: $checkedConvert(
          'questionRevisionId',
          (v) => v as String,
        ),
        editedPrompt: $checkedConvert('editedPrompt', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$CreateLocalCourseEditorDraftRequestToJson(
  CreateLocalCourseEditorDraftRequest instance,
) => <String, dynamic>{
  'baseReleaseId': instance.baseReleaseId,
  'questionRevisionId': instance.questionRevisionId,
  'editedPrompt': instance.editedPrompt,
};
