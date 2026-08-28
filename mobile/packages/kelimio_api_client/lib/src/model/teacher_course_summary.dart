//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'teacher_course_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherCourseSummary {
  /// Returns a new [TeacherCourseSummary] instance.
  TeacherCourseSummary({
    required this.id,

    required this.name,

    this.description,

    required this.targetLanguage,

    required this.defaultSupportLanguage,

    required this.visibility,

    required this.publicationStatus,

    required this.activeReleaseId,

    required this.activeReleaseRevision,

    required this.hasOpenDraft,

    this.openDraftReleaseId,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

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

  @JsonKey(name: r'visibility', required: true, includeIfNull: false)
  final TeacherCourseSummaryVisibilityEnum visibility;

  @JsonKey(name: r'publicationStatus', required: true, includeIfNull: false)
  final TeacherCourseSummaryPublicationStatusEnum publicationStatus;

  @JsonKey(name: r'activeReleaseId', required: true, includeIfNull: false)
  final String activeReleaseId;

  // minimum: 1
  @JsonKey(name: r'activeReleaseRevision', required: true, includeIfNull: false)
  final int activeReleaseRevision;

  @JsonKey(name: r'hasOpenDraft', required: true, includeIfNull: false)
  final bool hasOpenDraft;

  @JsonKey(name: r'openDraftReleaseId', required: false, includeIfNull: false)
  final String? openDraftReleaseId;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCourseSummary &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.targetLanguage == targetLanguage &&
          other.defaultSupportLanguage == defaultSupportLanguage &&
          other.visibility == visibility &&
          other.publicationStatus == publicationStatus &&
          other.activeReleaseId == activeReleaseId &&
          other.activeReleaseRevision == activeReleaseRevision &&
          other.hasOpenDraft == hasOpenDraft &&
          other.openDraftReleaseId == openDraftReleaseId &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      (description == null ? 0 : description.hashCode) +
      targetLanguage.hashCode +
      defaultSupportLanguage.hashCode +
      visibility.hashCode +
      publicationStatus.hashCode +
      activeReleaseId.hashCode +
      activeReleaseRevision.hashCode +
      hasOpenDraft.hashCode +
      (openDraftReleaseId == null ? 0 : openDraftReleaseId.hashCode) +
      createdAt.hashCode;

  factory TeacherCourseSummary.fromJson(Map<String, dynamic> json) =>
      _$TeacherCourseSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherCourseSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum TeacherCourseSummaryVisibilityEnum {
  @JsonValue(r'PUBLIC')
  PUBLIC(r'PUBLIC'),
  @JsonValue(r'PRIVATE')
  PRIVATE(r'PRIVATE');

  const TeacherCourseSummaryVisibilityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum TeacherCourseSummaryPublicationStatusEnum {
  @JsonValue(r'PUBLISHED')
  PUBLISHED(r'PUBLISHED'),
  @JsonValue(r'HIDDEN')
  HIDDEN(r'HIDDEN');

  const TeacherCourseSummaryPublicationStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
