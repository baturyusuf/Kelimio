//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'subsequent_course_draft_result.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SubsequentCourseDraftResult {
  /// Returns a new [SubsequentCourseDraftResult] instance.
  SubsequentCourseDraftResult({
    required this.courseId,

    required this.baseReleaseId,

    required this.contentChangeSetId,

    required this.draftReleaseId,

    required this.releaseRevision,

    required this.changedQuestionId,

    required this.previousQuestionRevisionId,

    required this.questionRevisionId,

    required this.changedTestId,

    required this.previousTestRevisionId,

    required this.testRevisionId,

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

  @JsonKey(name: r'changedQuestionId', required: true, includeIfNull: false)
  final String changedQuestionId;

  @JsonKey(
    name: r'previousQuestionRevisionId',
    required: true,
    includeIfNull: false,
  )
  final String previousQuestionRevisionId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  @JsonKey(name: r'changedTestId', required: true, includeIfNull: false)
  final String changedTestId;

  @JsonKey(
    name: r'previousTestRevisionId',
    required: true,
    includeIfNull: false,
  )
  final String previousTestRevisionId;

  @JsonKey(name: r'testRevisionId', required: true, includeIfNull: false)
  final String testRevisionId;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubsequentCourseDraftResult &&
          other.courseId == courseId &&
          other.baseReleaseId == baseReleaseId &&
          other.contentChangeSetId == contentChangeSetId &&
          other.draftReleaseId == draftReleaseId &&
          other.releaseRevision == releaseRevision &&
          other.changedQuestionId == changedQuestionId &&
          other.previousQuestionRevisionId == previousQuestionRevisionId &&
          other.questionRevisionId == questionRevisionId &&
          other.changedTestId == changedTestId &&
          other.previousTestRevisionId == previousTestRevisionId &&
          other.testRevisionId == testRevisionId &&
          other.createdAt == createdAt &&
          other.created == created;

  @override
  int get hashCode =>
      courseId.hashCode +
      baseReleaseId.hashCode +
      contentChangeSetId.hashCode +
      draftReleaseId.hashCode +
      releaseRevision.hashCode +
      changedQuestionId.hashCode +
      previousQuestionRevisionId.hashCode +
      questionRevisionId.hashCode +
      changedTestId.hashCode +
      previousTestRevisionId.hashCode +
      testRevisionId.hashCode +
      createdAt.hashCode +
      created.hashCode;

  factory SubsequentCourseDraftResult.fromJson(Map<String, dynamic> json) =>
      _$SubsequentCourseDraftResultFromJson(json);

  Map<String, dynamic> toJson() => _$SubsequentCourseDraftResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
