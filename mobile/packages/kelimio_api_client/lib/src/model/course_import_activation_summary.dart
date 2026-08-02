//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_release_operation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_activation_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportActivationSummary {
  /// Returns a new [CourseImportActivationSummary] instance.
  CourseImportActivationSummary({
    required this.releaseId,

    required this.operation,

    required this.activatedAt,

    required this.reprojectionStatus,
  });

  @JsonKey(name: r'releaseId', required: true, includeIfNull: false)
  final String releaseId;

  @JsonKey(name: r'operation', required: true, includeIfNull: false)
  final CourseReleaseOperation operation;

  @JsonKey(name: r'activatedAt', required: true, includeIfNull: false)
  final DateTime activatedAt;

  @JsonKey(name: r'reprojectionStatus', required: true, includeIfNull: false)
  final CourseImportActivationSummaryReprojectionStatusEnum reprojectionStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportActivationSummary &&
          other.releaseId == releaseId &&
          other.operation == operation &&
          other.activatedAt == activatedAt &&
          other.reprojectionStatus == reprojectionStatus;

  @override
  int get hashCode =>
      releaseId.hashCode +
      operation.hashCode +
      activatedAt.hashCode +
      reprojectionStatus.hashCode;

  factory CourseImportActivationSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseImportActivationSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportActivationSummaryToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'releaseId')) {
      json[r'releaseId'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportActivationSummaryReprojectionStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'FAILED')
  FAILED(r'FAILED'),
  @JsonValue(r'COMPLETED')
  COMPLETED(r'COMPLETED'),
  @JsonValue(r'DEAD')
  DEAD(r'DEAD');

  const CourseImportActivationSummaryReprojectionStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
