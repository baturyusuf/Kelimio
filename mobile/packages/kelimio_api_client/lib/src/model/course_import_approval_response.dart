//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_approval_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportApprovalResponse {
  /// Returns a new [CourseImportApprovalResponse] instance.
  CourseImportApprovalResponse({
    required this.importId,

    required this.status,

    required this.approvalBindingSha256,

    required this.approvedAt,

    required this.created,
  });

  @JsonKey(name: r'importId', required: true, includeIfNull: false)
  final String importId;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final CourseImportApprovalResponseStatusEnum status;

  @JsonKey(name: r'approvalBindingSha256', required: true, includeIfNull: false)
  final String approvalBindingSha256;

  @JsonKey(name: r'approvedAt', required: true, includeIfNull: false)
  final DateTime approvedAt;

  @JsonKey(name: r'created', required: true, includeIfNull: false)
  final bool created;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportApprovalResponse &&
          other.importId == importId &&
          other.status == status &&
          other.approvalBindingSha256 == approvalBindingSha256 &&
          other.approvedAt == approvedAt &&
          other.created == created;

  @override
  int get hashCode =>
      importId.hashCode +
      status.hashCode +
      approvalBindingSha256.hashCode +
      approvedAt.hashCode +
      created.hashCode;

  factory CourseImportApprovalResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseImportApprovalResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportApprovalResponseToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'approvalBindingSha256')) {
      json[r'approvalBindingSha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportApprovalResponseStatusEnum {
  @JsonValue(r'APPROVED')
  APPROVED(r'APPROVED');

  const CourseImportApprovalResponseStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
