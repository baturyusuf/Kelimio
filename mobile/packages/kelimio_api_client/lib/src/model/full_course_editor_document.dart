//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_level.dart';
import 'package:json_annotation/json_annotation.dart';

part 'full_course_editor_document.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FullCourseEditorDocument {
  /// Returns a new [FullCourseEditorDocument] instance.
  FullCourseEditorDocument({
    required this.courseId,

    required this.activeReleaseId,

    required this.releaseRevision,

    required this.name,

    this.description,

    required this.visibility,

    required this.targetLanguage,

    required this.defaultSupportLanguage,

    required this.supportLanguages,

    required this.levels,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'activeReleaseId', required: true, includeIfNull: false)
  final String activeReleaseId;

  // minimum: 1
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'visibility', required: true, includeIfNull: false)
  final FullCourseEditorDocumentVisibilityEnum visibility;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'targetLanguage', required: true, includeIfNull: false)
  final String targetLanguage;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(
    name: r'defaultSupportLanguage',
    required: true,
    includeIfNull: false,
  )
  final String defaultSupportLanguage;

  @JsonKey(name: r'supportLanguages', required: true, includeIfNull: false)
  final Set<String> supportLanguages;

  @JsonKey(name: r'levels', required: true, includeIfNull: false)
  final List<CourseEditorLevel> levels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FullCourseEditorDocument &&
          other.courseId == courseId &&
          other.activeReleaseId == activeReleaseId &&
          other.releaseRevision == releaseRevision &&
          other.name == name &&
          other.description == description &&
          other.visibility == visibility &&
          other.targetLanguage == targetLanguage &&
          other.defaultSupportLanguage == defaultSupportLanguage &&
          other.supportLanguages == supportLanguages &&
          other.levels == levels;

  @override
  int get hashCode =>
      courseId.hashCode +
      activeReleaseId.hashCode +
      releaseRevision.hashCode +
      name.hashCode +
      (description == null ? 0 : description.hashCode) +
      visibility.hashCode +
      targetLanguage.hashCode +
      defaultSupportLanguage.hashCode +
      supportLanguages.hashCode +
      levels.hashCode;

  factory FullCourseEditorDocument.fromJson(Map<String, dynamic> json) =>
      _$FullCourseEditorDocumentFromJson(json);

  Map<String, dynamic> toJson() => _$FullCourseEditorDocumentToJson(this);

  @override
  String toString() {
    final json = toJson();
    return json.toString();
  }
}

enum FullCourseEditorDocumentVisibilityEnum {
  @JsonValue(r'PUBLIC')
  PUBLIC(r'PUBLIC'),
  @JsonValue(r'PRIVATE')
  PRIVATE(r'PRIVATE');

  const FullCourseEditorDocumentVisibilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
