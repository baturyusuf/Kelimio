//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_validation_issue.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_issue_page.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportIssuePage {
  /// Returns a new [CourseImportIssuePage] instance.
  CourseImportIssuePage({required this.items, this.nextCursor});

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<CourseImportValidationIssue> items;

  @JsonKey(name: r'nextCursor', required: false, includeIfNull: false)
  final String? nextCursor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportIssuePage &&
          other.items == items &&
          other.nextCursor == nextCursor;

  @override
  int get hashCode =>
      items.hashCode + (nextCursor == null ? 0 : nextCursor.hashCode);

  factory CourseImportIssuePage.fromJson(Map<String, dynamic> json) =>
      _$CourseImportIssuePageFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportIssuePageToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'items')) {
      json[r'items'] = '[REDACTED]';
    }
    if (json.containsKey(r'nextCursor')) {
      json[r'nextCursor'] = '[REDACTED]';
    }
    return json.toString();
  }
}
