//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_commit_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportCommitSummary {
  /// Returns a new [CourseImportCommitSummary] instance.
  CourseImportCommitSummary({
    required this.courseId,

    required this.contentChangeSetId,

    required this.draftReleaseId,

    required this.sourceRowCount,

    required this.questionCount,

    required this.matchingQuestionCount,

    required this.requiredClientCapabilities,

    required this.committedAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'contentChangeSetId', required: true, includeIfNull: false)
  final String contentChangeSetId;

  @JsonKey(name: r'draftReleaseId', required: true, includeIfNull: false)
  final String draftReleaseId;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'sourceRowCount', required: true, includeIfNull: false)
  final int sourceRowCount;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'questionCount', required: true, includeIfNull: false)
  final int questionCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'matchingQuestionCount', required: true, includeIfNull: false)
  final int matchingQuestionCount;

  @JsonKey(
    name: r'requiredClientCapabilities',
    required: true,
    includeIfNull: false,
  )
  final Set<String> requiredClientCapabilities;

  @JsonKey(name: r'committedAt', required: true, includeIfNull: false)
  final DateTime committedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportCommitSummary &&
          other.courseId == courseId &&
          other.contentChangeSetId == contentChangeSetId &&
          other.draftReleaseId == draftReleaseId &&
          other.sourceRowCount == sourceRowCount &&
          other.questionCount == questionCount &&
          other.matchingQuestionCount == matchingQuestionCount &&
          other.requiredClientCapabilities == requiredClientCapabilities &&
          other.committedAt == committedAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      contentChangeSetId.hashCode +
      draftReleaseId.hashCode +
      sourceRowCount.hashCode +
      questionCount.hashCode +
      matchingQuestionCount.hashCode +
      requiredClientCapabilities.hashCode +
      committedAt.hashCode;

  factory CourseImportCommitSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseImportCommitSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportCommitSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
