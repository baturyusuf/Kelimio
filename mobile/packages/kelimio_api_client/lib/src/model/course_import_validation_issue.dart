//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_source.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_validation_issue.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportValidationIssue {
  /// Returns a new [CourseImportValidationIssue] instance.
  CourseImportValidationIssue({
    required this.ordinal,

    required this.severity,

    required this.code,

    required this.source_,

    required this.message,
  });

  // minimum: 1
  // maximum: 2000
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  @JsonKey(name: r'severity', required: true, includeIfNull: false)
  final CourseImportValidationIssueSeverityEnum severity;

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'source', required: true, includeIfNull: true)
  final CourseImportSource? source_;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportValidationIssue &&
          other.ordinal == ordinal &&
          other.severity == severity &&
          other.code == code &&
          other.source_ == source_ &&
          other.message == message;

  @override
  int get hashCode =>
      ordinal.hashCode +
      severity.hashCode +
      code.hashCode +
      (source_ == null ? 0 : source_.hashCode) +
      message.hashCode;

  factory CourseImportValidationIssue.fromJson(Map<String, dynamic> json) =>
      _$CourseImportValidationIssueFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportValidationIssueToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'source')) {
      json[r'source'] = '[REDACTED]';
    }
    if (json.containsKey(r'message')) {
      json[r'message'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportValidationIssueSeverityEnum {
  @JsonValue(r'WARNING')
  WARNING(r'WARNING'),
  @JsonValue(r'ERROR')
  ERROR(r'ERROR');

  const CourseImportValidationIssueSeverityEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
