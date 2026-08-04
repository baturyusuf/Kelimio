//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_commit_summary.dart';
import 'package:kelimio_api_client/src/model/course_import_status.dart';
import 'package:kelimio_api_client/src/model/course_import_activation_summary.dart';
import 'package:kelimio_api_client/src/model/course_import_preview_summary.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_status_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportStatusResponse {
  /// Returns a new [CourseImportStatusResponse] instance.
  CourseImportStatusResponse({
    required this.id,

    required this.status,

    required this.originalFileName,

    required this.declaredMediaType,

    required this.fileSizeBytes,

    required this.rulesVersion,

    required this.processingAttempts,

    required this.createdAt,

    required this.updatedAt,

    required this.uploadExpiresAt,

    required this.preview,

    required this.approvalBindingSha256,

    required this.approvedAt,

    required this.commit,

    required this.activation,

    required this.failureCode,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final CourseImportStatus status;

  @JsonKey(name: r'originalFileName', required: true, includeIfNull: false)
  final String originalFileName;

  @JsonKey(name: r'declaredMediaType', required: true, includeIfNull: false)
  final CourseImportStatusResponseDeclaredMediaTypeEnum declaredMediaType;

  // minimum: 1
  // maximum: 26214400
  @JsonKey(name: r'fileSizeBytes', required: true, includeIfNull: false)
  final int fileSizeBytes;

  @JsonKey(name: r'rulesVersion', required: true, includeIfNull: false)
  final CourseImportStatusResponseRulesVersionEnum rulesVersion;

  // minimum: 0
  // maximum: 5
  @JsonKey(name: r'processingAttempts', required: true, includeIfNull: false)
  final int processingAttempts;

  @JsonKey(name: r'createdAt', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'updatedAt', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @JsonKey(name: r'uploadExpiresAt', required: true, includeIfNull: false)
  final DateTime uploadExpiresAt;

  @JsonKey(name: r'preview', required: true, includeIfNull: true)
  final CourseImportPreviewSummary? preview;

  @JsonKey(name: r'approvalBindingSha256', required: true, includeIfNull: true)
  final String? approvalBindingSha256;

  @JsonKey(name: r'approvedAt', required: true, includeIfNull: true)
  final DateTime? approvedAt;

  @JsonKey(name: r'commit', required: true, includeIfNull: true)
  final CourseImportCommitSummary? commit;

  @JsonKey(name: r'activation', required: true, includeIfNull: true)
  final CourseImportActivationSummary? activation;

  @JsonKey(name: r'failureCode', required: true, includeIfNull: true)
  final String? failureCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportStatusResponse &&
          other.id == id &&
          other.status == status &&
          other.originalFileName == originalFileName &&
          other.declaredMediaType == declaredMediaType &&
          other.fileSizeBytes == fileSizeBytes &&
          other.rulesVersion == rulesVersion &&
          other.processingAttempts == processingAttempts &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.uploadExpiresAt == uploadExpiresAt &&
          other.preview == preview &&
          other.approvalBindingSha256 == approvalBindingSha256 &&
          other.approvedAt == approvedAt &&
          other.commit == commit &&
          other.activation == activation &&
          other.failureCode == failureCode;

  @override
  int get hashCode =>
      id.hashCode +
      status.hashCode +
      originalFileName.hashCode +
      declaredMediaType.hashCode +
      fileSizeBytes.hashCode +
      rulesVersion.hashCode +
      processingAttempts.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode +
      uploadExpiresAt.hashCode +
      (preview == null ? 0 : preview.hashCode) +
      (approvalBindingSha256 == null ? 0 : approvalBindingSha256.hashCode) +
      (approvedAt == null ? 0 : approvedAt.hashCode) +
      (commit == null ? 0 : commit.hashCode) +
      (activation == null ? 0 : activation.hashCode) +
      (failureCode == null ? 0 : failureCode.hashCode);

  factory CourseImportStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseImportStatusResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportStatusResponseToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'originalFileName')) {
      json[r'originalFileName'] = '[REDACTED]';
    }
    if (json.containsKey(r'preview')) {
      json[r'preview'] = '[REDACTED]';
    }
    if (json.containsKey(r'approvalBindingSha256')) {
      json[r'approvalBindingSha256'] = '[REDACTED]';
    }
    if (json.containsKey(r'activation')) {
      json[r'activation'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportStatusResponseDeclaredMediaTypeEnum {
  @JsonValue(
    r'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  )
  applicationSlashVndPeriodOpenxmlformatsOfficedocumentPeriodSpreadsheetmlPeriodSheet(
    r'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  const CourseImportStatusResponseDeclaredMediaTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportStatusResponseRulesVersionEnum {
  @JsonValue(r'xlsx-v1')
  xlsxV1(r'xlsx-v1'),
  @JsonValue(r'xlsx-v2')
  xlsxV2(r'xlsx-v2');

  const CourseImportStatusResponseRulesVersionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
