//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_release_operation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_release_impact_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseReleaseImpactResponse {
  /// Returns a new [CourseReleaseImpactResponse] instance.
  CourseReleaseImpactResponse({
    required this.courseId,

    required this.targetReleaseId,

    required this.expectedActiveReleaseId,

    required this.sourceChangeSetId,

    required this.operation,

    required this.releaseRevision,

    required this.targetQuestionCount,

    required this.unchangedQuestionCount,

    required this.changedQuestionCount,

    required this.addedQuestionCount,

    required this.removedQuestionCount,

    required this.affectedEnrollmentCount,

    required this.requiredClientCapabilities,

    required this.impactBindingSha256,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'targetReleaseId', required: true, includeIfNull: false)
  final String targetReleaseId;

  @JsonKey(
    name: r'expectedActiveReleaseId',
    required: true,
    includeIfNull: true,
  )
  final String? expectedActiveReleaseId;

  @JsonKey(name: r'sourceChangeSetId', required: true, includeIfNull: false)
  final String sourceChangeSetId;

  @JsonKey(name: r'operation', required: true, includeIfNull: false)
  final CourseReleaseOperation operation;

  // minimum: 1
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'targetQuestionCount', required: true, includeIfNull: false)
  final int targetQuestionCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(
    name: r'unchangedQuestionCount',
    required: true,
    includeIfNull: false,
  )
  final int unchangedQuestionCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'changedQuestionCount', required: true, includeIfNull: false)
  final int changedQuestionCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'addedQuestionCount', required: true, includeIfNull: false)
  final int addedQuestionCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'removedQuestionCount', required: true, includeIfNull: false)
  final int removedQuestionCount;

  // minimum: 0
  @JsonKey(
    name: r'affectedEnrollmentCount',
    required: true,
    includeIfNull: false,
  )
  final int affectedEnrollmentCount;

  @JsonKey(
    name: r'requiredClientCapabilities',
    required: true,
    includeIfNull: false,
  )
  final Set<String> requiredClientCapabilities;

  @JsonKey(name: r'impactBindingSha256', required: true, includeIfNull: false)
  final String impactBindingSha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseReleaseImpactResponse &&
          other.courseId == courseId &&
          other.targetReleaseId == targetReleaseId &&
          other.expectedActiveReleaseId == expectedActiveReleaseId &&
          other.sourceChangeSetId == sourceChangeSetId &&
          other.operation == operation &&
          other.releaseRevision == releaseRevision &&
          other.targetQuestionCount == targetQuestionCount &&
          other.unchangedQuestionCount == unchangedQuestionCount &&
          other.changedQuestionCount == changedQuestionCount &&
          other.addedQuestionCount == addedQuestionCount &&
          other.removedQuestionCount == removedQuestionCount &&
          other.affectedEnrollmentCount == affectedEnrollmentCount &&
          other.requiredClientCapabilities == requiredClientCapabilities &&
          other.impactBindingSha256 == impactBindingSha256;

  @override
  int get hashCode =>
      courseId.hashCode +
      targetReleaseId.hashCode +
      (expectedActiveReleaseId == null ? 0 : expectedActiveReleaseId.hashCode) +
      sourceChangeSetId.hashCode +
      operation.hashCode +
      releaseRevision.hashCode +
      targetQuestionCount.hashCode +
      unchangedQuestionCount.hashCode +
      changedQuestionCount.hashCode +
      addedQuestionCount.hashCode +
      removedQuestionCount.hashCode +
      affectedEnrollmentCount.hashCode +
      requiredClientCapabilities.hashCode +
      impactBindingSha256.hashCode;

  factory CourseReleaseImpactResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseReleaseImpactResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseReleaseImpactResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
