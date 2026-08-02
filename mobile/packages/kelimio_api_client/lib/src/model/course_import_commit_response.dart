//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_commit_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportCommitResponse {
  /// Returns a new [CourseImportCommitResponse] instance.
  CourseImportCommitResponse({
    required this.importId,

    required this.status,

    required this.courseId,

    required this.contentChangeSetId,

    required this.draftReleaseId,

    required this.committedAt,

    required this.created,
  });

  @JsonKey(name: r'importId', required: true, includeIfNull: false)
  final String importId;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final CourseImportCommitResponseStatusEnum status;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'contentChangeSetId', required: true, includeIfNull: false)
  final String contentChangeSetId;

  @JsonKey(name: r'draftReleaseId', required: true, includeIfNull: false)
  final String draftReleaseId;

  @JsonKey(name: r'committedAt', required: true, includeIfNull: false)
  final DateTime committedAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportCommitResponse &&
          other.importId == importId &&
          other.status == status &&
          other.courseId == courseId &&
          other.contentChangeSetId == contentChangeSetId &&
          other.draftReleaseId == draftReleaseId &&
          other.committedAt == committedAt &&
          other.created == created;

  @override
  int get hashCode =>
      importId.hashCode +
      status.hashCode +
      courseId.hashCode +
      contentChangeSetId.hashCode +
      draftReleaseId.hashCode +
      committedAt.hashCode +
      created.hashCode;

  factory CourseImportCommitResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseImportCommitResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportCommitResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum CourseImportCommitResponseStatusEnum {
  @JsonValue(r'COMMITTED')
  COMMITTED(r'COMMITTED');

  const CourseImportCommitResponseStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
