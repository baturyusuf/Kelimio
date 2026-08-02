//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_import_preview_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPreviewSummary {
  /// Returns a new [CourseImportPreviewSummary] instance.
  CourseImportPreviewSummary({
    required this.isValid,

    required this.rowCount,

    required this.levelCount,

    required this.unitCount,

    required this.topicCount,

    required this.testCount,

    required this.warningCount,

    required this.errorCount,

    required this.validationReportSha256,

    required this.allocationSha256,

    required this.previewSha256,
  });

  @JsonKey(name: r'isValid', required: true, includeIfNull: false)
  final bool isValid;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'rowCount', required: true, includeIfNull: false)
  final int rowCount;

  // minimum: 0
  // maximum: 64
  @JsonKey(name: r'levelCount', required: true, includeIfNull: false)
  final int levelCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'unitCount', required: true, includeIfNull: false)
  final int unitCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'topicCount', required: true, includeIfNull: false)
  final int topicCount;

  // minimum: 0
  // maximum: 10000
  @JsonKey(name: r'testCount', required: true, includeIfNull: false)
  final int testCount;

  // minimum: 0
  // maximum: 2000
  @JsonKey(name: r'warningCount', required: true, includeIfNull: false)
  final int warningCount;

  // minimum: 0
  // maximum: 2000
  @JsonKey(name: r'errorCount', required: true, includeIfNull: false)
  final int errorCount;

  @JsonKey(
    name: r'validationReportSha256',
    required: true,
    includeIfNull: false,
  )
  final String validationReportSha256;

  @JsonKey(name: r'allocationSha256', required: true, includeIfNull: true)
  final String? allocationSha256;

  @JsonKey(name: r'previewSha256', required: true, includeIfNull: true)
  final String? previewSha256;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPreviewSummary &&
          other.isValid == isValid &&
          other.rowCount == rowCount &&
          other.levelCount == levelCount &&
          other.unitCount == unitCount &&
          other.topicCount == topicCount &&
          other.testCount == testCount &&
          other.warningCount == warningCount &&
          other.errorCount == errorCount &&
          other.validationReportSha256 == validationReportSha256 &&
          other.allocationSha256 == allocationSha256 &&
          other.previewSha256 == previewSha256;

  @override
  int get hashCode =>
      isValid.hashCode +
      rowCount.hashCode +
      levelCount.hashCode +
      unitCount.hashCode +
      topicCount.hashCode +
      testCount.hashCode +
      warningCount.hashCode +
      errorCount.hashCode +
      validationReportSha256.hashCode +
      (allocationSha256 == null ? 0 : allocationSha256.hashCode) +
      (previewSha256 == null ? 0 : previewSha256.hashCode);

  factory CourseImportPreviewSummary.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPreviewSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPreviewSummaryToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'validationReportSha256')) {
      json[r'validationReportSha256'] = '[REDACTED]';
    }
    if (json.containsKey(r'allocationSha256')) {
      json[r'allocationSha256'] = '[REDACTED]';
    }
    if (json.containsKey(r'previewSha256')) {
      json[r'previewSha256'] = '[REDACTED]';
    }
    return json.toString();
  }
}
