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

    required this.committedAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'contentChangeSetId', required: true, includeIfNull: false)
  final String contentChangeSetId;

  @JsonKey(name: r'draftReleaseId', required: true, includeIfNull: false)
  final String draftReleaseId;

  @JsonKey(name: r'committedAt', required: true, includeIfNull: false)
  final DateTime committedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportCommitSummary &&
          other.courseId == courseId &&
          other.contentChangeSetId == contentChangeSetId &&
          other.draftReleaseId == draftReleaseId &&
          other.committedAt == committedAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      contentChangeSetId.hashCode +
      draftReleaseId.hashCode +
      committedAt.hashCode;

  factory CourseImportCommitSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseImportCommitSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportCommitSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
