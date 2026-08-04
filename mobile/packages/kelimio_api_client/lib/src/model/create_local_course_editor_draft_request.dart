//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'create_local_course_editor_draft_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateLocalCourseEditorDraftRequest {
  /// Returns a new [CreateLocalCourseEditorDraftRequest] instance.
  CreateLocalCourseEditorDraftRequest({
    required this.baseReleaseId,

    required this.questionRevisionId,

    required this.editedPrompt,
  });

  @JsonKey(name: r'baseReleaseId', required: true, includeIfNull: false)
  final String baseReleaseId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  /// Changed typed-cloze prompt containing exactly one literal --- marker.
  @JsonKey(name: r'editedPrompt', required: true, includeIfNull: false)
  final String editedPrompt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateLocalCourseEditorDraftRequest &&
          other.baseReleaseId == baseReleaseId &&
          other.questionRevisionId == questionRevisionId &&
          other.editedPrompt == editedPrompt;

  @override
  int get hashCode =>
      baseReleaseId.hashCode +
      questionRevisionId.hashCode +
      editedPrompt.hashCode;

  factory CreateLocalCourseEditorDraftRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$CreateLocalCourseEditorDraftRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CreateLocalCourseEditorDraftRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'editedPrompt')) {
      json[r'editedPrompt'] = '[REDACTED]';
    }
    return json.toString();
  }
}
