//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_release_operation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_release_activation_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseReleaseActivationResponse {
  /// Returns a new [CourseReleaseActivationResponse] instance.
  CourseReleaseActivationResponse({
    required this.activationId,

    required this.courseId,

    required this.releaseId,

    required this.previousReleaseId,

    required this.sourceChangeSetId,

    required this.operation,

    required this.releaseRevision,

    required this.questionCount,

    required this.requiredClientCapabilities,

    required this.coursePublicationStatus,

    required this.reprojectionStatus,

    required this.activatedAt,

    required this.created,
  });

  @JsonKey(name: r'activationId', required: true, includeIfNull: false)
  final String activationId;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'releaseId', required: true, includeIfNull: false)
  final String releaseId;

  @JsonKey(name: r'previousReleaseId', required: true, includeIfNull: true)
  final String? previousReleaseId;

  @JsonKey(name: r'sourceChangeSetId', required: true, includeIfNull: false)
  final String sourceChangeSetId;

  @JsonKey(name: r'operation', required: true, includeIfNull: false)
  final CourseReleaseOperation operation;

  // minimum: 1
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'questionCount', required: true, includeIfNull: false)
  final int questionCount;

  @JsonKey(
    name: r'requiredClientCapabilities',
    required: true,
    includeIfNull: false,
  )
  final Set<String> requiredClientCapabilities;

  @JsonKey(
    name: r'coursePublicationStatus',
    required: true,
    includeIfNull: false,
  )
  final CourseReleaseActivationResponseCoursePublicationStatusEnum
  coursePublicationStatus;

  @JsonKey(name: r'reprojectionStatus', required: true, includeIfNull: false)
  final CourseReleaseActivationResponseReprojectionStatusEnum
  reprojectionStatus;

  @JsonKey(name: r'activatedAt', required: true, includeIfNull: false)
  final DateTime activatedAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseReleaseActivationResponse &&
          other.activationId == activationId &&
          other.courseId == courseId &&
          other.releaseId == releaseId &&
          other.previousReleaseId == previousReleaseId &&
          other.sourceChangeSetId == sourceChangeSetId &&
          other.operation == operation &&
          other.releaseRevision == releaseRevision &&
          other.questionCount == questionCount &&
          other.requiredClientCapabilities == requiredClientCapabilities &&
          other.coursePublicationStatus == coursePublicationStatus &&
          other.reprojectionStatus == reprojectionStatus &&
          other.activatedAt == activatedAt &&
          other.created == created;

  @override
  int get hashCode =>
      activationId.hashCode +
      courseId.hashCode +
      releaseId.hashCode +
      (previousReleaseId == null ? 0 : previousReleaseId.hashCode) +
      sourceChangeSetId.hashCode +
      operation.hashCode +
      releaseRevision.hashCode +
      questionCount.hashCode +
      requiredClientCapabilities.hashCode +
      coursePublicationStatus.hashCode +
      reprojectionStatus.hashCode +
      activatedAt.hashCode +
      created.hashCode;

  factory CourseReleaseActivationResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseReleaseActivationResponseFromJson(json);

  Map<String, dynamic> toJson() =>
      _$CourseReleaseActivationResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CourseReleaseActivationResponseCoursePublicationStatusEnum {
  @JsonValue(r'PUBLISHED')
  PUBLISHED(r'PUBLISHED'),
  @JsonValue(r'HIDDEN')
  HIDDEN(r'HIDDEN');

  const CourseReleaseActivationResponseCoursePublicationStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseReleaseActivationResponseReprojectionStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'FAILED')
  FAILED(r'FAILED'),
  @JsonValue(r'COMPLETED')
  COMPLETED(r'COMPLETED'),
  @JsonValue(r'DEAD')
  DEAD(r'DEAD');

  const CourseReleaseActivationResponseReprojectionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
