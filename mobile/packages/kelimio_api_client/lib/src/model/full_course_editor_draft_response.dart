//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'full_course_editor_draft_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FullCourseEditorDraftResponse {
  /// Returns a new [FullCourseEditorDraftResponse] instance.
  FullCourseEditorDraftResponse({
    required this.courseId,

    required this.baseReleaseId,

    required this.contentChangeSetId,

    required this.draftReleaseId,

    required this.releaseRevision,

    required this.questionCount,

    required this.requiredClientCapabilities,

    required this.createdAt,

    required this.created,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'baseReleaseId', required: true, includeIfNull: false)
  final String baseReleaseId;

  @JsonKey(name: r'contentChangeSetId', required: true, includeIfNull: false)
  final String contentChangeSetId;

  @JsonKey(name: r'draftReleaseId', required: true, includeIfNull: false)
  final String draftReleaseId;

  // minimum: 2
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  // minimum: 1
  @JsonKey(name: r'questionCount', required: true, includeIfNull: false)
  final int questionCount;

  @JsonKey(
    name: r'requiredClientCapabilities',
    required: true,
    includeIfNull: false,
  )
  final Set<String> requiredClientCapabilities;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FullCourseEditorDraftResponse &&
          other.courseId == courseId &&
          other.baseReleaseId == baseReleaseId &&
          other.contentChangeSetId == contentChangeSetId &&
          other.draftReleaseId == draftReleaseId &&
          other.releaseRevision == releaseRevision &&
          other.questionCount == questionCount &&
          other.requiredClientCapabilities == requiredClientCapabilities &&
          other.createdAt == createdAt &&
          other.created == created;

  @override
  int get hashCode =>
      courseId.hashCode +
      baseReleaseId.hashCode +
      contentChangeSetId.hashCode +
      draftReleaseId.hashCode +
      releaseRevision.hashCode +
      questionCount.hashCode +
      requiredClientCapabilities.hashCode +
      createdAt.hashCode +
      created.hashCode;

  factory FullCourseEditorDraftResponse.fromJson(Map<String, dynamic> json) =>
      _$FullCourseEditorDraftResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FullCourseEditorDraftResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
