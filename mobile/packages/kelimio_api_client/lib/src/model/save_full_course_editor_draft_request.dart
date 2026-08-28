//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_level.dart';
import 'package:json_annotation/json_annotation.dart';

part 'save_full_course_editor_draft_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SaveFullCourseEditorDraftRequest {
  /// Returns a new [SaveFullCourseEditorDraftRequest] instance.
  SaveFullCourseEditorDraftRequest({
    required this.baseReleaseId,

    required this.name,

    this.description,

    required this.visibility,

    required this.levels,
  });

  @JsonKey(name: r'baseReleaseId', required: true, includeIfNull: false)
  final String baseReleaseId;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'visibility', required: true, includeIfNull: false)
  final SaveFullCourseEditorDraftRequestVisibilityEnum visibility;

  @JsonKey(name: r'levels', required: true, includeIfNull: false)
  final List<CourseEditorLevel> levels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaveFullCourseEditorDraftRequest &&
          other.baseReleaseId == baseReleaseId &&
          other.name == name &&
          other.description == description &&
          other.visibility == visibility &&
          other.levels == levels;

  @override
  int get hashCode =>
      baseReleaseId.hashCode +
      name.hashCode +
      (description == null ? 0 : description.hashCode) +
      visibility.hashCode +
      levels.hashCode;

  factory SaveFullCourseEditorDraftRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$SaveFullCourseEditorDraftRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$SaveFullCourseEditorDraftRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    return json.toString();
  }
}

enum SaveFullCourseEditorDraftRequestVisibilityEnum {
  @JsonValue(r'PUBLIC')
  PUBLIC(r'PUBLIC'),
  @JsonValue(r'PRIVATE')
  PRIVATE(r'PRIVATE');

  const SaveFullCourseEditorDraftRequestVisibilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
